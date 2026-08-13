# DevSecOps GKE Pipeline: Master Reference

This is my personal reference for the project. It covers the architecture, every security control, the full CI/CD pipeline, the known limitations, and the real incidents I hit along the way. It's a working reference, not the polished repo README.

---

## 1. What this is

A healthcare-themed microservices application deployed to GKE on GCP. It was built as a DevSecOps showcase: infrastructure as code (Terraform), a single unified CI/CD pipeline (GitHub Actions), and defense-in-depth security controls across the network, identity, supply chain, and runtime layers.

**Repo**: `sharnsimon-devops/HCLAssessment` (private)
**GCP Project**: `hcl-assessment` (project number `745978164055`), region `europe-west2`. There's no parent Organization here, it's a standalone project. That constrains what's possible later on (see section 7).

### Services

| Service | Stack | Port | Purpose |
|---|---|---|---|
| `order-service` | Java 17 / Spring Boot / Maven | 8080 | Orders |
| `application-service` | Node.js / Express | 3001 | Appointments (the "Appointment Service") |
| `patient-service` | Node.js / Express | 3000 | Patients |

All three live at the repo root, not under a `services/` folder. Each has its own Dockerfile, its own Kubernetes manifests under `k8s/<service>/`, and its own job in the unified CI pipeline.

---

## 2. Architecture: the full request path

```
Internet
  -> Cloud Armor (Standard tier WAF: SQLi/XSS/LFI/RFI/RCE/Log4Shell rules + rate limiting)
  -> LB1 (Global External HTTPS Load Balancer, static IP, self-signed cert)
  -> Serverless NEG -> Cloud API Gateway (schema validation via OpenAPI spec)
  -> nip.io hostname -> GKE Ingress (LB2, auto-created, container-native load balancing)
  -> Private VPC-native GKE cluster (Binary Authorization enforced)
  -> order-service / application-service / patient-service pods
```

**Important nuance**: Cloud Armor is attached at two separate points, LB1's backend service and the GKE Ingress's `BackendConfig`. So a request that reaches the Ingress gets inspected twice, once at each hop.

**Known gap**: hitting API Gateway's raw default hostname directly bypasses LB1's Cloud Armor. I confirmed this empirically: a SQLi probe through LB1 gets a `403`, the same probe against the API Gateway hostname directly gets a `405`, meaning Cloud Armor never saw it. The Ingress's own Cloud Armor attachment still inspects anything that reaches that far, so it's a partial bypass, not a total one. Not fixed, just documented.

### Networking

- VPC-native GKE cluster, private nodes. The public control-plane endpoint is restricted via `master_authorized_networks_config`.
- Private subnet `10.0.0.0/20` (secondary ranges: pods `10.4.0.0/14`, services `10.8.0.0/20`), plus a now-orphaned public subnet (`10.100.0.0/24`). That one was created early on and nothing ever ended up wired to use it. It's a leftover from an earlier design iteration, flagged but not yet removed.
- Cloud NAT for private-node egress.
- Firewall rules scoped by network tag (`gke-node`).
- VPC Flow Logs enabled on both subnets.

---

## 3. Terraform module layout

```
terraform/
├── environments/dev/     - root module: backend, providers, variables, wires all modules together
└── modules/
    ├── vpc/               - network, subnets, NAT/router, firewall
    ├── iam-kms/           - GKE node SA, Binary Authorization signing key, Artifact Registry CMEK key,
    │                        all github-deployer IAM grants
    ├── gke/                - cluster, node pool, Artifact Registry, fleet membership (Connect Gateway)
    ├── cloud-armor/        - WAF policy + 7 rules (sqli/xss/lfi/rfi/rce/java-cve-canary/rate_limit)
    ├── api-gateway/        - schema-validating gateway in front of the 3 services
    ├── binauthz/           - Container Analysis notes, 2 attestors, enforcement policy
    ├── load-balancer/      - LB1: static IP, self-signed cert, Serverless NEG, backend service, URL map,
    │                        proxy, forwarding rule
    └── monitoring/         - email notification channel + 2 log-based alert policies
```

State backend is a GCS bucket, `terraform-state-bucket-gke-assessment`, prefix `dev/terraform/state`, versioned (10 max versions per object, 30-day noncurrent expiry).

**Standing rule for this project**: I write and edit the `.tf` code, the user runs `terraform init/plan/apply` themselves. I can run read-only `gcloud`/`kubectl` verification, but even that got narrowed mid-project to "hand over the command, don't run it" after a rejected tool call.

---

## 4. Security controls, layer by layer

### Network
- Private GKE nodes, no public IPs.
- `master_authorized_networks_config` restricts the control plane's public API to a single admin CIDR (currently the user's home IP). It has to be updated whenever that IP changes, which has already happened twice on this project.
- `NetworkPolicy`: default-deny-all, then explicit allows for GCP LB health-check ranges (`130.211.0.0/22`, `35.191.0.0/16`), DNS scoped to `kube-system`, and HTTPS egress (`0.0.0.0/0:443`, deliberately broad since Google's API IP ranges aren't practically enumerable).
- Cloud Armor WAF: SQLi, XSS, LFI, RFI, RCE, and Log4Shell/CVE-2021-44228 (via the `cve-canary` preconfigured rule set), plus rate limiting at 100 req/min per IP.

### Identity
- **Workload Identity** for pods, so there are no long-lived service account keys sitting on nodes.
- **Workload Identity Federation (WIF)** for GitHub Actions CI, so there are no long-lived keys in GitHub either. It's attribute-condition-restricted to this exact repo.
- `github-deployer`'s IAM: broad predefined roles for each GCP area it manages (`compute.admin`, `container.admin`, `artifactregistry.admin`, `apigateway.admin`, `cloudkms.admin`, `iam.serviceAccountAdmin`, `resourcemanager.projectIamAdmin`), plus narrower grants added incrementally as gaps surfaced (`containeranalysis.notes.editor`, `containeranalysis.notes.attacher`, `containeranalysis.occurrences.editor`, `binaryauthorization.attestorsEditor`, `binaryauthorization.policyEditor`, `gkehub.gatewayAdmin`, `gkehub.viewer`).
- Kubernetes RBAC: a `deployer` Role, scoped to the `dev` namespace, covering only Deployments/ReplicaSets/Pods, bound to `github-deployer`'s IAM identity as a `User` subject. This is what actually lets CI's `kubectl apply` work through Connect Gateway.

### Supply chain
- **Binary Authorization enforced** (`PROJECT_SINGLETON_POLICY_ENFORCE`). Only images signed by both attestors (`dev-build-attestor`, `dev-vulnerability-scan-attestor`) can run. I proved this works, not just that it's configured: unsigned images get blocked with zero disruption to already-running pods, and tag references get rejected even when signed, since GCP itself enforces digest-only.
- Images are pushed by immutable digest and tagged with the git commit SHA for traceability.
- Trivy image scan on every build. Currently soft-fail, see section 7 for why.
- SonarQube SAST and secrets detection gates every deploy. This one is hard-fail: a failed Quality Gate blocks deployment.
- A KMS asymmetric signing key handles the attestations. The Artifact Registry CMEK key rotates every 90 days; the signing key itself is `ASYMMETRIC_SIGN`, which doesn't support rotation the same way.
- Artifact Registry is encrypted with a dedicated CMEK key rather than Google-default encryption.

### Runtime (Kubernetes)
- Pod Security Admission at the `restricted` level on the `dev` namespace.
- All 3 Deployments run non-root (`runAsUser: 10001`), with `readOnlyRootFilesystem: true` (and a `tmp` emptyDir mount for the app's scratch space), `allowPrivilegeEscalation: false`, all capabilities dropped, `seccompProfile: RuntimeDefault`, and `automountServiceAccountToken: false`.
- The Dockerfiles strip npm/yarn/corepack from the final image stage, since none of it is needed at runtime, only during `npm install` in the build stage. That removes a whole class of Trivy findings that come from npm's own bundled dependencies, not application code. They also run `apk update && apk upgrade` on every build to pick up already-patched OS packages.
- `LimitRange` and `ResourceQuota` on the namespace.
- RBAC also includes a `developer-readonly` Role, read-only and deliberately unbound to a real identity (it's illustrative), alongside the `deployer` Role that's bound to the real CI identity.

### Infra-as-code gates
- **Checkov** (Terraform + Kubernetes), `soft_fail: false`, hard-blocks the pipeline.
- **Trivy config scan**, `exit-code: 1`, also hard-blocks the pipeline.
- Both run before `terraform plan`/`apply` can even start, via a `needs:` dependency.

---

## 5. CI/CD: the unified pipeline

Everything lives in one file now: `.github/workflows/pipeline.yml` ("DevSecOps Pipeline"). It used to be three or four separate workflow files (`terraform.yml`, `build-and-push.yml`, `deploy.yml`, `sonarqube.yml`) and got consolidated on request, partly to simplify the trigger and partly to eliminate a real race condition: a separately-triggered `deploy.yml` could have tried to deploy an image before the build job had finished pushing it.

**Single trigger**: push or PR to `master`, path filter is the union of everything (`terraform/**`, `k8s/**`, `.checkov.yaml`, `.trivyignore`, all 3 service directories, and the workflow file itself).

**Structure**:
1. `detect-changes`. `dorny/paths-filter` determines which of {terraform, order-service, application-service, patient-service} actually changed. Every other job's `if:` condition is driven off this, so the selective behavior of the old separate files is fully preserved in one file.
2. `checkov` / `trivy-config`. Only run if Terraform-related paths changed.
3. `plan` (PR only) and `apply` (push to `master` only, gated behind a GitHub Environment called `production` that requires manual reviewer approval). Both depend on `checkov` and `trivy-config` passing first.
4. `order-service` / `application-service` / `patient-service`. Each only runs if its own path changed. Per service: build (tagged by commit SHA), Trivy image scan (soft-fail), push, capture the real digest via `docker inspect`, sign against both attestors, patch the Deployment manifest's `image:` field via `sed`, get cluster credentials through Connect Gateway, `kubectl apply`, then `kubectl rollout status`.
5. `sonar-scan`. Runs if any service changed. It spins up an ephemeral SonarQube Community Build container, generates its own token via the default `admin:admin` credentials and the REST API, then runs a single unified scan across all 3 services (Java and JS) including built-in secrets detection, and checks the Quality Gate.
6. Every service deploy job now depends on `sonar-scan` as well as `detect-changes`. A failed Quality Gate blocks deployment entirely. This dependency was actually missing at first. I caught and fixed it after being asked, reasonably, "only after sonarqube it can be deployed right, how come that not happen."

I proved this works end to end via the GitHub Actions API, not just the green checkmark. A real run showed `detect-changes` succeeding, `sonar-scan` succeeding, the Terraform jobs correctly skipped (no infra changes in that push), two service deploys succeeding only after Sonar passed, and the untouched service correctly skipped.

### Connect Gateway: why CI can reach the cluster at all

CI's `kubectl` calls go through GKE Connect Gateway, not a direct connection to the control plane's public endpoint. This was a deliberate choice over the simpler alternative of just opening `master_authorized_networks_config` to `0.0.0.0/0`. See section 7 for the actual reasoning behind that decision.

Setup: three APIs enabled (`gkeconnect`, `gkehub`, `connectgateway`), a `google_gke_hub_membership` fleet registration, two IAM grants for `github-deployer` (`gkehub.gatewayAdmin`, `gkehub.viewer`), and the Kubernetes-side `deployer` RBAC Role/RoleBinding described above. The workflow uses `google-github-actions/get-gke-credentials@v3` with `use_connect_gateway: true` and the fully-qualified fleet membership resource path. Using just the bare ID (`dev-gke-membership` instead of the full `projects/hcl-assessment/locations/global/memberships/dev-gke-membership`) causes a raw Google 404.

---

## 6. Monitoring and alerting

- **Logging**: `SYSTEM_COMPONENTS` and `WORKLOADS`, so application pod logs (stdout/stderr) are collected. This is GKE's own default. I never had to configure it explicitly.
- **Monitoring**: a comprehensive component list (`POD`, `DEPLOYMENT`, `STATEFULSET`, `DAEMONSET`, `CADVISOR`, `KUBELET`, `STORAGE`, `HPA`, `JOBSET`), plus Google Cloud Managed Service for Prometheus enabled. Also GKE's own default.
- **Alerting** is real, Terraform-managed infrastructure I actually built, not a default. One email notification channel (`sharnspectre2002@gmail.com`) plus two log-based alert policies:
  - Cloud Armor `DENY` events, i.e. real attack attempts being blocked.
  - Project-level `SetIamPolicy` calls, i.e. IAM policy changes.
  - Both use `condition_matched_log`, so no separate log-based metric resource is needed, with a 5-minute notification rate limit.
  - Verification status is genuinely ambiguous through the API (the field is just absent either way). The Console's Notification Channels page showed no "Verify" option, which is itself a signal it's already verified, but I never got 100% definitive confirmation. It would take a real alert firing to be fully sure.
- **Not built yet**: alerts for Binary Authorization denials or GKE control-plane auth failures. The log filters for those need verification against real docs before building, same discipline as the two that did get built. This is flagged as a next step, not done.

---

## 7. Known limitations and accepted risks (read this section honestly)

Every one of these was a deliberate decision, not an oversight. I'm documenting the why so it doesn't get mistaken for negligence later.

| Limitation | Why | Status |
|---|---|---|
| Cloud Armor SQLi false positives on JSON POST bodies | `owasp-crs-v030301-id942260-sqli` flags a quoted key followed by a colon (e.g. `"description":`) as SQLi. Cloud Armor's exclusion mechanism can only scope to header, cookie, query-param, or URI, not POST body content, so this is structurally unfixable via exclusion. | Accepted. Real SQLi attempts still get blocked; legitimate JSON occasionally 403s. |
| API Gateway direct-invoke bypasses LB1's Cloud Armor | No ingress restriction exists on API Gateway's own hostname. | Documented, not fixed. The Ingress's own Cloud Armor attachment still catches anything that gets that far. |
| No Security Command Center, any tier | Hard platform requirement: even project-level SCC Standard needs the project to belong to a GCP Organization, and this project has no org. It's not a Terraform gap, it's genuinely impossible without standing up an entire Cloud Identity/Workspace org first, which is out of scope. | Accepted, structurally impossible as configured. |
| Trivy image scan is soft-fail (`exit-code: 0`) | A real vulnerability finding blocked a build at one point; I made an explicit decision to unblock rather than fix it immediately. | Open item. Should revisit which finding it was and whether it's since resolved. |
| `master_authorized_networks_config` restricted to one IP, not `0.0.0.0/0` | I seriously considered opening it, since it's simpler than Connect Gateway, but rejected that after thinking through the real tradeoff: an open network doesn't let anyone in without valid IAM credentials, but it does mean a leaked `github-deployer` credential becomes usable from anywhere instead of just one IP, and this project had no alerting layer at the time that would catch that. Chose Connect Gateway instead. More setup, no tradeoff. | Resolved via Connect Gateway, not left as risk. |
| `github-deployer` holds several broad `*.admin` predefined roles | `compute.admin`, `container.admin`, and similar predate this session as prerequisite setup, and were never narrowed, only audited once against what's actually used. | Not fixed, flagged. |
| No Google Group exists for GKE RBAC (`CKV_GCP_65`) | No real Cloud Identity/Workspace group exists in this project, same root cause as the no-SCC issue. | Accepted, Checkov-skipped with a documented reason. |
| A few Checkov/Trivy findings are false positives, skipped with documented reasons | `CKV_GCP_69` (GKE Metadata Server, checks the wrong resource for a separately-managed node pool architecture), and `CKV_GCP_42` / `GCP-0007` (both flag any role containing "Editor" or ending in "Admin" as if it were the broad legacy `roles/editor`/`roles/owner`, catching narrowly-scoped predefined roles that happen to share the naming pattern). | Each verified against the actual check source code before skipping, not guessed. |
| Orphaned public subnet in the VPC | Created early on; nothing was ever wired to use it once the API-Gateway/Serverless-NEG design replaced whatever originally needed it. | Flagged in a code audit, not yet removed. |
| No persistent SonarQube dashboard | Ephemeral, job-scoped SonarQube container by design. There's no budget or infra for a persistent instance. | Deliberate scope decision, not a gap. |
| No DAST, no Cloud Armor Adaptive Protection | DAST needs SCC Web Security Scanner, which needs SCC Premium, which needs an org. Adaptive Protection is an Enterprise-tier paid feature. | Both blocked by the same no-org, no-budget constraint as SCC. |
| Secret Manager CSI never built | None of the 3 services hold a real secret worth protecting. `order-service` uses in-memory H2, the Node services are stateless. I investigated the real mechanism and decided the implementation cost wasn't worth it for nothing real to protect. | Deliberate scope decision. |

**Bottom line, honestly**: for a demo or portfolio DevSecOps pipeline, this is genuinely comprehensive defense-in-depth, arguably more thorough than plenty of real early-stage production setups. For an actual production system handling real patient data, PHI or PII, it would still need SCC or an equivalent (needs an org), a formal risk assessment, a BAA with Google, and real incident-response processes. Several of those are legal or business or org-structure requirements. No amount of Terraform produces them on its own.

---

## 8. Real incidents worth remembering (the war stories)

These cost real time. They're exactly the kind of thing worth not re-discovering the hard way twice.

- **The Optional+Computed Terraform trap**, hit twice. Removing a field from config doesn't reset it in real infrastructure, it just stops Terraform tracking it. Hit this on Cloud Armor `rule` blocks and on `google_binary_authorization_attestor.public_keys.id`. The fix is always to set an explicit different value, never just delete the line.
- **Binary Authorization requires the fully-qualified KMS key ID** (`//cloudkms.googleapis.com/v1/...`) to match what `gcloud ... sign-and-create` generates. The relative form (`projects/.../cryptoKeyVersions/1`) is a different string to its exact-match lookup, even though it's the same key.
- **Binary Authorization rejects tag references outright**, even when signed. Digest-only, enforced by GCP itself, not just a best practice.
- **Docker BuildKit attaches non-deterministic provenance and SBOM attestations by default.** Rebuilding identical source produces a different digest every time. This caused real confusion when an image got rebuilt mid-workflow and the digest I'd already signed was suddenly stale. Lesson: always re-verify the live digest via `gcloud artifacts docker images describe` before trusting one from a build log.
- **KMS IAM grants are eventually consistent.** A resource that needs a just-granted permission can race ahead of propagation and fail with a permission error, even though the binding already exists. Fixed with a `time_sleep` resource plus an explicit `depends_on` chain, not just by adding the IAM binding and hoping.
- **CI's `terraform apply` has a real bootstrapping deadlock.** It refreshes every resource's state before applying anything, including resources unrelated to what's actually changing. That means the very commit that grants a missing permission to the CI service account will itself fail during refresh, using the not-yet-granted permission. The only way out is a successful apply under different, already-sufficient credentials first.
- **Checkov's inline `#checkov:skip` comments silently fail for graph-based checks.** Confirmed via multiple upstream issues, not a placement mistake on my part. The fix is to skip at the CLI or action level (`skip_check` input or `.checkov.yaml`) instead.
- **`trivyignores`, the trivy-action GitHub Action's own input, has multiple open upstream bugs where it silently doesn't apply.** The fix is to set `TRIVY_IGNOREFILE` directly as a step-level `env:` var, bypassing the action's buggy input-processing layer and hitting the underlying `trivy` CLI's own env var directly.
- **A shell command containing literal `key: ` text breaks GitHub's workflow YAML parser** if it's inside a plain, non-block `run:` scalar. The colon and space get misread as a nested YAML mapping key. Fix: always use a block scalar (`run: |`) for any shell command containing that pattern. I hit this twice, in two different jobs, both times with a `sed "s|image: ...|"` command.
- **`fleet_membership_name` for Connect Gateway needs the fully-qualified resource path**, not the bare membership ID. The bare ID causes a raw, unhelpful Google 404 HTML page instead of a clean API error.
- **PowerShell plus curl.exe JSON body quoting is its own trap.** Backslash-escaped double quotes inside a double-quoted PowerShell string don't survive the way you'd expect. The reliable pattern is to single-quote the whole JSON payload with no internal escaping at all: `-d '{"key":"value"}'`.
- **Distinguishing "which CI run am I actually looking at" was the single biggest source of wasted time** across this entire project. Pasted error text was stale or ambiguous, local versus CI, more than half a dozen times. The GitHub Actions REST API (`api.github.com/repos/<owner>/<repo>/actions/runs`, which works unauthenticated for this public repo) resolved the ambiguity definitively every time I actually used it, faster than just asking "are you sure you're looking at the latest run."

---

## 9. Operational notes

- **If `kubectl` from your laptop suddenly can't reach the cluster**, check your public IP (`curl https://api.ipify.org`) against `master_authorized_cidr` in `terraform/environments/dev/variables.tf`. This has already changed twice during this project. Update the default, then `terraform plan`/`apply`.
- **CI's `kubectl` access doesn't depend on your IP at all.** It goes through Connect Gateway, unaffected by the above.
- **Local `terraform apply` and CI's `terraform apply` share the same remote state**, but pull code from different places: your filesystem versus whatever's on `master`. Applying locally without pushing right away creates a real risk. CI's next run could see a resource in state that its own, stale, checked-out code doesn't declare, and plan to destroy it. Push immediately after any local apply.
- **Digests change on every rebuild, even with identical source**, because of BuildKit provenance. Never trust a digest from memory or an old log. Always re-verify it live before signing or deploying against it.
