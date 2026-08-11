resource "google_kms_crypto_key_iam_member" "github_deployer_signer" {
  crypto_key_id = google_kms_crypto_key.attestor_signing_key.id
  role          = "roles/cloudkms.signerVerifier"
  member        = "serviceAccount:${var.github_deployer_sa_email}"
}

# CI's terraform apply manages the binauthz module's Container Analysis
# Notes (build_note, vulnerability_scan_note) - github-deployer needs
# project-level Container Analysis permissions to read/create/update them.
# This was never caught locally because local applies run under the user's
# own broader credentials, not this scoped CI service account.
resource "google_project_iam_member" "github_deployer_container_analysis" {
  project = var.project_id
  role    = "roles/containeranalysis.notes.editor"
  member  = "serviceAccount:${var.github_deployer_sa_email}"
}

# Confirmed via a full audit (2026-08-11) of github-deployer's granted roles
# against every resource type this Terraform config manages - Binary
# Authorization was the one genuine gap, no roles/binaryauthorization.* was
# granted at all. Everything else (compute.admin, container.admin,
# artifactregistry.admin, apigateway.admin, cloudkms.admin, etc.) already
# covers its respective module.
resource "google_project_iam_member" "github_deployer_binauthz_attestors" {
  project = var.project_id
  role    = "roles/binaryauthorization.attestorsEditor"
  member  = "serviceAccount:${var.github_deployer_sa_email}"
}

resource "google_project_iam_member" "github_deployer_binauthz_policy" {
  project = var.project_id
  role    = "roles/binaryauthorization.policyEditor"
  member  = "serviceAccount:${var.github_deployer_sa_email}"
}
