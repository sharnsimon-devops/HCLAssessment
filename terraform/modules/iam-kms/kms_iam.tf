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
