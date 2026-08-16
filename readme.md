# DevSecOps GKE Pipeline

A healthcare-themed microservices application deployed to GKE on GCP, built to demonstrate a full DevSecOps setup: infrastructure as code (Terraform), a single unified CI/CD pipeline (GitHub Actions), and defense-in-depth security controls across the network, identity, supply chain, and runtime layers.

**Repo**: `sharnsimon-devops/HCLAssessment` (private)
**GCP Project**: `hcl-assessment` (project number `745978164055`), region `europe-west2`. The project has no parent Organization, which constrains a few things later on (see the Known Limitations section).

## Services

| Service | Stack | Port | Purpose |
|---|---|---|---|
| `order-service` | Java 17 / Spring Boot / Maven | 8080 | Orders |
| `application-service` | Node.js / Express | 3001 | Appointments (the "Appointment Service") |
| `patient-service` | Node.js / Express | 3000 | Patients |

All three live at the repo root, not under a `services/` folder. Each has its own Dockerfile, its own Kubernetes manifests under `k8s/<service>/`, and its own job in the unified CI pipeline.

---

## Architecture: the full request path

```
Internet
  -> Cloud Armor (Standard tier WAF: SQLi/XSS/LFI/RFI/RCE/Log4Shell rules + rate limiting)
  -> LB1 (Global External HTTPS Load Balancer, static IP, self-signed cert)
  -> Serverless NEG -> Cloud API Gateway (schema validation via OpenAPI spec)
  -> nip.io hostname -> GKE Ingress (LB2, auto-created, container-native load balancing)
  -> Private VPC-native GKE cluster (Binary Authorization enforced)
  -> order-service / application-service / patient-service pods
```

Cloud Armor is attached at two separate points: LB1's backend service, and the GKE Ingress's `BackendConfig`. A request that reaches the Ingress gets inspected twice, once at each hop.

**Known gap**: hitting API Gateway's raw default hostname directly bypasses LB1's Cloud Armor. A SQLi probe through LB1 gets a `403`; the same probe against the API Gateway hostname directly gets a `405`, meaning Cloud Armor never saw it. The Ingress's own Cloud Armor attachment still inspects anything that reaches that far, so it's a partial bypass, not a total one. Documented, not fixed.

### Networking

- VPC-native GKE cluster with private nodes. The public control-plane endpoint is restricted via `master_authorized_networks_config`.
- Private subnet `10.0.0.0/20` (secondary ranges: pods `10.4.0.0/14`, services `10.8.0.0/20`), plus a public subnet (`10.100.0.0/24`) left over from an earlier design iteration that's no longer wired to anything.
- Cloud NAT for private-node egress.
- Firewall rules scoped by network tag (`gke-node`).
- VPC Flow Logs enabled on both subnets.

---

## Terraform module layout

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

---

## Security controls, layer by layer

### Network
- Private GKE nodes, no public IPs.
- `master_authorized_networks_config` restricts the control plane's public API to a single admin CIDR.
- `NetworkPolicy`: default-deny-all, then explicit allows for GCP LB health-check ranges (`130.211.0.0/22`, `35.191.0.0/16`), DNS scoped to `kube-system`, and HTTPS egress (`0.0.0.0/0:443`, deliberately broad since Google's API IP ranges aren't practically enumerable).
- Cloud Armor WAF: SQLi, XSS, LFI, RFI, RCE, and Log4Shell/CVE-2021-44228 (via the `cve-canary` preconfigured rule set), plus rate limiting at 100 req/min per IP.

### Identity
- **Workload Identity** for pods, so there are no long-lived service account keys on nodes.
- **Workload Identity Federation (WIF)** for GitHub Actions CI, so there are no long-lived keys in GitHub either. Attribute-condition-restricted to this exact repo.
- `github-deployer`'s IAM: broad predefined roles for each GCP area it manages (`compute.admin`, `container.admin`, `artifactregistry.admin`, `apigateway.admin`, `cloudkms.admin`, `iam.serviceAccountAdmin`, `resourcemanager.projectIamAdmin`), plus narrower grants added as gaps surfaced (`containeranalysis.notes.editor`, `containeranalysis.notes.attacher`, `containeranalysis.occurrences.editor`, `binaryauthorization.attestorsEditor`, `binaryauthorization.policyEditor`, `gkehub.gatewayAdmin`, `gkehub.viewer`).
- Kubernetes RBAC: a `deployer` Role, scoped to the `dev` namespace, covering only Deployments/ReplicaSets/Pods, bound to `github-deployer`'s IAM identity as a `User` subject. This is what lets CI's `kubectl apply` work through Connect Gateway.

### Supply chain
- **Binary Authorization enforced** (`PROJECT_SINGLETON_POLICY_ENFORCE`). Only images signed by both attestors (`dev-build-attestor`, `dev-vulnerability-scan-attestor`) can run. Unsigned images are blocked with zero disruption to already-running pods; tag references are rejected even when signed, since GCP enforces digest-only references.
- Images are pushed by immutable digest and tagged with the git commit SHA for traceability.
- Trivy image scan on every build (currently soft-fail, see Known Limitations).
- SonarQube SAST and secrets detection gates every deploy (hard-fail: a failed Quality Gate blocks deployment).
- A KMS asymmetric signing key handles the attestations. The Artifact Registry CMEK key rotates every 90 days; the signing key itself is `ASYMMETRIC_SIGN`, which doesn't support rotation the same way.
- Artifact Registry is encrypted with a dedicated CMEK key rather than Google-default encryption.

### Runtime (Kubernetes)
- Pod Security Admission at the `restricted` level on the `dev` namespace.
- All 3 Deployments run non-root (`runAsUser: 10001`), with `readOnlyRootFilesystem: true` (and a `tmp` emptyDir mount for scratch space), `allowPrivilegeEscalation: false`, all capabilities dropped, `seccompProfile: RuntimeDefault`, and `automountServiceAccountToken: false`.
- The Dockerfiles strip npm/yarn/corepack from the final image stage, since none of it is needed at runtime, only during `npm install` in the build stage. This removes a whole class of vulnerability findings that come from npm's own bundled dependencies, not application code. They also run `apk update && apk upgrade` on every build to pick up already-patched OS packages.
- `LimitRange` and `ResourceQuota` on the namespace.
- RBAC also includes a `developer-readonly` Role, read-only and illustrative (not bound to a real identity), alongside the `deployer` Role bound to the real CI identity.

### Infra-as-code gates
- **Checkov** (Terraform + Kubernetes), `soft_fail: false`, hard-blocks the pipeline.
- **Trivy config scan**, `exit-code: 1`, also hard-blocks the pipeline.
- Both run before `terraform plan`/`apply` can even start, via a `needs:` dependency.

---

## CI/CD: the unified pipeline

Everything lives in one file: `.github/workflows/pipeline.yml` ("DevSecOps Pipeline"). It's structured as a single push/PR trigger, with a `detect-changes` job driving every other job's `if:` condition so Terraform-only changes and app-only changes each run just the relevant jobs.

**Single trigger**: push or PR to `master`, path filter is the union of everything (`terraform/**`, `k8s/**`, `.checkov.yaml`, `.trivyignore`, all 3 service directories, and the workflow file itself).

**Structure**:
1. `detect-changes`. `dorny/paths-filter` determines which of {terraform, order-service, application-service, patient-service} actually changed.
2. `checkov` / `trivy-config`. Only run if Terraform-related paths changed.
3. `plan` (PR only) and `apply` (push to `master` only, gated behind a GitHub Environment called `production` that requires manual reviewer approval). Both depend on `checkov` and `trivy-config` passing first.
4. `order-service` / `application-service` / `patient-service`. Each only runs if its own path changed. Per service: build (tagged by commit SHA), Trivy image scan (soft-fail), push, capture the real digest via `docker inspect`, sign against both attestors, patch the Deployment manifest's `image:` field, get cluster credentials through Connect Gateway, `kubectl apply`, then `kubectl rollout status`.
5. `sonar-scan`. Runs if any service changed. Spins up an ephemeral SonarQube Community Build container, generates its own token via the REST API, runs a single unified scan across all 3 services (Java and JS) including built-in secrets detection, and checks the Quality Gate.
6. Every service deploy job depends on `sonar-scan` as well as `detect-changes`, so a failed Quality Gate blocks deployment entirely.

### Connect Gateway: how CI reaches the cluster

CI's `kubectl` calls go through GKE Connect Gateway rather than a direct connection to the control plane's public endpoint. This keeps the control plane's IP allowlist tight (one admin IP) instead of needing to accommodate GitHub-hosted runners' unpredictable source IPs.

Setup: three APIs enabled (`gkeconnect`, `gkehub`, `connectgateway`), a `google_gke_hub_membership` fleet registration, two IAM grants for `github-deployer` (`gkehub.gatewayAdmin`, `gkehub.viewer`), and the Kubernetes-side `deployer` RBAC Role/RoleBinding described above. The workflow uses `google-github-actions/get-gke-credentials@v3` with `use_connect_gateway: true` and the fully-qualified fleet membership resource path (`projects/hcl-assessment/locations/global/memberships/dev-gke-membership`).

---

## Monitoring and alerting

- **Logging**: `SYSTEM_COMPONENTS` and `WORKLOADS`, so application pod logs (stdout/stderr) are collected. GKE's own default.
- **Monitoring**: a comprehensive component list (`POD`, `DEPLOYMENT`, `STATEFULSET`, `DAEMONSET`, `CADVISOR`, `KUBELET`, `STORAGE`, `HPA`, `JOBSET`), plus Google Cloud Managed Service for Prometheus. Also GKE's own default.
- **Alerting**: one email notification channel plus two log-based alert policies (Cloud Armor `DENY` events, and project-level `SetIamPolicy` calls), using `condition_matched_log` with a 5-minute notification rate limit.

---

## Known limitations and accepted risks

Every item here was a deliberate decision, documented so it isn't mistaken for an oversight.

| Limitation | Why | Status |
|---|---|---|
| Cloud Armor SQLi false positives on JSON POST bodies | `owasp-crs-v030301-id942260-sqli` flags a quoted key followed by a colon (e.g. `"description":`) as SQLi. Cloud Armor's exclusion mechanism can only scope to header, cookie, query-param, or URI, not POST body content, so this is structurally unfixable via exclusion. | Accepted. Real SQLi attempts still get blocked; legitimate JSON occasionally 403s. |
| API Gateway direct-invoke bypasses LB1's Cloud Armor | No ingress restriction exists on API Gateway's own hostname. | Documented, not fixed. The Ingress's own Cloud Armor attachment still catches anything that gets that far. |
| No Security Command Center, any tier | Even project-level SCC Standard requires the project to belong to a GCP Organization, and this project has no org. Not a Terraform gap; genuinely impossible without standing up an entire Cloud Identity/Workspace org first. | Accepted, structurally impossible as configured. |
| Trivy image scan is soft-fail (`exit-code: 0`) | A real vulnerability finding blocked a build at one point; the decision was made to unblock rather than fix it immediately. | Open item. |
| `master_authorized_networks_config` restricted to one IP, not `0.0.0.0/0` | Opening the network would let CI in without Connect Gateway, but an open network means a leaked `github-deployer` credential becomes usable from anywhere instead of one IP. Connect Gateway avoids that tradeoff entirely. | Resolved via Connect Gateway, not left as risk. |
| `github-deployer` holds several broad `*.admin` predefined roles | `compute.admin`, `container.admin`, and similar predate this build as prerequisite setup, and were audited once against actual usage but never narrowed further. | Not fixed, flagged. |
| No Google Group exists for GKE RBAC (`CKV_GCP_65`) | No real Cloud Identity/Workspace group exists in this project, same root cause as the no-SCC issue. | Accepted, Checkov-skipped with a documented reason. |
| A few Checkov/Trivy findings are false positives, skipped with documented reasons | `CKV_GCP_69` (GKE Metadata Server, checks the wrong resource for a separately-managed node pool architecture), and `CKV_GCP_42` / `GCP-0007` (both flag any role containing "Editor" or ending in "Admin" as if it were the broad legacy `roles/editor`/`roles/owner`, catching narrowly-scoped predefined roles that happen to share the naming pattern). | Each verified against the actual check source before skipping. |
| Orphaned public subnet in the VPC | Created early on; nothing was ever wired to use it once the API-Gateway/Serverless-NEG design replaced whatever originally needed it. | Flagged, not yet removed. |
| No persistent SonarQube dashboard | Ephemeral, job-scoped SonarQube container by design; no persistent instance is maintained. | Deliberate scope decision. |
| No DAST, no Cloud Armor Adaptive Protection | DAST needs SCC Web Security Scanner, which needs SCC Premium, which needs an org. Adaptive Protection is an Enterprise-tier paid feature. | Both blocked by the same no-org constraint as SCC. |
| Secret Manager CSI never built | None of the 3 services hold a real secret worth protecting. `order-service` uses in-memory H2; the Node services are stateless. | Deliberate scope decision. |

---

## Operational notes

- **If `kubectl` from a local machine can't reach the cluster**, check the current public IP against `master_authorized_cidr` in `terraform/environments/dev/variables.tf` and update it if it's changed.
- **CI's `kubectl` access doesn't depend on any local IP.** It goes through Connect Gateway.
- **Local `terraform apply` and CI's `terraform apply` share the same remote state**, but pull code from different places (local filesystem vs. `master`). Applying locally without pushing right away risks CI's next run seeing a resource in state that its own stale code doesn't declare, and planning to destroy it. Push immediately after any local apply.
- **Image digests change on every rebuild, even with identical source**, due to Docker BuildKit's provenance attestations. Always re-verify the live digest before signing or deploying against it, rather than trusting one from an earlier build log.
