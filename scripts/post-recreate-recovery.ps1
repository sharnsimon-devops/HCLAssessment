<#
Post-recreate recovery for the DevSecOps GKE pipeline (hcl-assessment).

Run this AFTER `terraform apply` has successfully recreated infra from scratch
(empty Artifact Registry repo, new Binary Authorization attestors, new GKE
cluster, new LB1 static IP). It does NOT run terraform for you.

What it does, in order:
  1. Reads the new LB1 static IP and rewrites it into openapi.yaml (all 3
     x-google-backend.address values + the description text).
  2. For each service: docker build -> Trivy scan -> push -> capture real
     digest -> sign against both Binary Authorization attestors -> update
     the k8s deployment.yaml image field to the new digest.
  3. Gets GKE credentials via Connect Gateway and applies+rolls out all 3
     deployments.
  4. Prints a checklist of things this script deliberately does NOT touch
     (terraform apply for the api-config, WIF/GitHub variables, master
     authorized CIDR) so nothing gets silently skipped.

Mirrors .github/workflows/pipeline.yml exactly (same env values, same
gcloud/docker commands) so this script and CI never drift apart.
#>

param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..").Path,
  [switch]$SkipDeploy
)

$ErrorActionPreference = "Stop"

# --- Config: kept identical to .github/workflows/pipeline.yml `env:` block ---
$PROJECT_ID       = "hcl-assessment"
$REGION           = "europe-west2"
$REPO             = "dev-docker-repo"
$KEYRING          = "dev-binauthz-keyring"
$SIGNING_KEY      = "dev-attestor-signing-key"
$CLUSTER          = "dev-gke-cluster"
$FLEET_MEMBERSHIP = "projects/hcl-assessment/locations/global/memberships/dev-gke-membership"
$NAMESPACE        = "dev"
$SERVICES         = @("order-service", "application-service", "patient-service")
$ATTESTORS        = @("dev-build-attestor", "dev-vulnerability-scan-attestor")

function Invoke-Checked {
  param([string]$Description, [scriptblock]$Command)
  Write-Host "`n==> $Description" -ForegroundColor Cyan
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "FAILED: $Description (exit code $LASTEXITCODE)"
  }
}

Write-Host "Repo root: $RepoRoot" -ForegroundColor DarkGray
Set-Location $RepoRoot

# ---------------------------------------------------------------------------
# Step 1: Fix the LB1 IP everywhere it's hardcoded
# ---------------------------------------------------------------------------
Write-Host "`n=== Step 1: Resolve new LB1 static IP and update openapi.yaml ===" -ForegroundColor Yellow

$newIp = (gcloud compute addresses describe dev-lb1-ip --global --format="value(address)").Trim()
if ([string]::IsNullOrWhiteSpace($newIp)) {
  throw "Could not resolve dev-lb1-ip. Has the load-balancer module actually been applied yet?"
}
Write-Host "Current LB1 static IP: $newIp"

$openapiPath = Join-Path $RepoRoot "terraform\modules\api-gateway\openapi.yaml"
$openapi = Get-Content $openapiPath -Raw

# Replace any previous <ip>.nip.io occurrence (and the bare IP in the description) with the current one.
$openapiUpdated = [regex]::Replace($openapi, '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(\.nip\.io)?', {
  param($m) if ($m.Groups[1].Success) { "$newIp.nip.io" } else { $newIp }
})

if ($openapiUpdated -ne $openapi) {
  Set-Content -Path $openapiPath -Value $openapiUpdated -NoNewline
  Write-Host "openapi.yaml updated to point at $newIp.nip.io" -ForegroundColor Green
} else {
  Write-Host "openapi.yaml already up to date." -ForegroundColor Green
}

Write-Host "NOTE: this only edits the file. You still need to 'terraform apply' from" -ForegroundColor Magenta
Write-Host "terraform/environments/dev for the new api-config to actually deploy" -ForegroundColor Magenta
Write-Host "(the module hashes openapi.yaml's content into the config ID, so a real" -ForegroundColor Magenta
Write-Host "content change is what forces the replacement)." -ForegroundColor Magenta

# ---------------------------------------------------------------------------
# Step 2: Rebuild, scan, push, sign each service
# ---------------------------------------------------------------------------
Write-Host "`n=== Step 2: Rebuild, push, and sign all 3 images ===" -ForegroundColor Yellow

Invoke-Checked "Configure docker auth for Artifact Registry" {
  gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet
}

$digests = @{}

foreach ($svc in $SERVICES) {
  $tag = "$REGION-docker.pkg.dev/$PROJECT_ID/$REPO/${svc}:recovery-$(Get-Date -Format yyyyMMddHHmmss)"

  Invoke-Checked "Build $svc" {
    docker build -t $tag (Join-Path $RepoRoot $svc)
  }

  Write-Host "`n-- Trivy scan for $svc (report only, matches CI's soft-fail) --" -ForegroundColor DarkCyan
  trivy image --severity CRITICAL,HIGH $tag
  # Deliberately not checked against $LASTEXITCODE: pipeline.yml runs this as
  # exit-code: 0 (soft-fail), see project memory on that decision. Skipping
  # the check here keeps this script consistent with CI, not stricter.

  Invoke-Checked "Push $svc" {
    docker push $tag
  }

  $digest = (docker inspect --format='{{index .RepoDigests 0}}' $tag).Trim()
  if ([string]::IsNullOrWhiteSpace($digest)) {
    throw "Could not resolve a real digest for $svc after push."
  }
  $digests[$svc] = $digest
  Write-Host "$svc digest: $digest" -ForegroundColor Green

  foreach ($attestor in $ATTESTORS) {
    Invoke-Checked "Sign $svc against $attestor" {
      gcloud beta container binauthz attestations sign-and-create `
        --project=$PROJECT_ID `
        --artifact-url=$digest `
        --attestor=$attestor `
        --attestor-project=$PROJECT_ID `
        --keyversion-project=$PROJECT_ID `
        --keyversion-location=$REGION `
        --keyversion-keyring=$KEYRING `
        --keyversion-key=$SIGNING_KEY `
        --keyversion=1
    }
  }

  $deploymentPath = Join-Path $RepoRoot "k8s\$svc\deployment.yaml"
  $deployment = Get-Content $deploymentPath -Raw
  $deploymentUpdated = [regex]::Replace($deployment, 'image:\s*\S+', "image: $digest")
  Set-Content -Path $deploymentPath -Value $deploymentUpdated -NoNewline
  Write-Host "$deploymentPath updated to $digest" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Step 3: Deploy
# ---------------------------------------------------------------------------
if ($SkipDeploy) {
  Write-Host "`n=== Step 3 skipped (-SkipDeploy) ===" -ForegroundColor Yellow
} else {
  Write-Host "`n=== Step 3: Get GKE credentials and roll out all 3 deployments ===" -ForegroundColor Yellow

  Invoke-Checked "Get GKE credentials via Connect Gateway" {
    gcloud container fleet memberships get-credentials $CLUSTER --project=$PROJECT_ID
  }

  foreach ($svc in $SERVICES) {
    $deploymentPath = "k8s\$svc\deployment.yaml"
    Invoke-Checked "Apply $svc deployment" {
      kubectl apply -f $deploymentPath
    }
    Invoke-Checked "Wait for $svc rollout" {
      kubectl rollout status "deployment/$svc" -n $NAMESPACE --timeout=180s
    }
  }
}

# ---------------------------------------------------------------------------
# Step 4: What this script did NOT do
# ---------------------------------------------------------------------------
Write-Host "`n=== Done. Still needs manual attention: ===" -ForegroundColor Yellow
Write-Host "  1. terraform apply (terraform/environments/dev) -- to push the updated"
Write-Host "     openapi.yaml as a new api-config, since this script only edited the file."
Write-Host "  2. Check master_authorized_cidr in variables.tf still matches your current"
Write-Host "     public IP (curl https://api.ipify.org) -- kubectl access breaks silently"
Write-Host "     if your IP drifted since it was last set."
Write-Host "  3. If the Workload Identity Federation provider was recreated (not just the"
Write-Host "     GKE cluster), confirm GitHub Actions repo Variables GCP_WORKLOAD_IDENTITY_PROVIDER"
Write-Host "     and GCP_SERVICE_ACCOUNT still point at valid resource IDs."
Write-Host "  4. Digests above are tagged 'recovery-<timestamp>', not a git SHA -- commit the"
Write-Host "     updated k8s/*/deployment.yaml files so CI's own state matches what's actually"
Write-Host "     running (otherwise the next normal CI push will look like it's reverting things)."

Write-Host "`nDigests signed and deployed this run:" -ForegroundColor Cyan
$digests.GetEnumerator() | ForEach-Object { Write-Host "  $($_.Key): $($_.Value)" }
