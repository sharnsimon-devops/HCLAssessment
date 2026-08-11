resource "google_kms_crypto_key_iam_member" "github_deployer_signer" {
  crypto_key_id = google_kms_crypto_key.attestor_signing_key.id
  role          = "roles/cloudkms.signerVerifier"
  member        = "serviceAccount:${var.github_deployer_sa_email}"
}

resource "google_project_iam_member" "github_deployer_container_analysis" {
  project = var.project_id
  role    = "roles/containeranalysis.notes.editor"
  member  = "serviceAccount:${var.github_deployer_sa_email}"
}

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

resource "google_project_iam_member" "github_deployer_notes_attacher" {
  project = var.project_id
  role    = "roles/containeranalysis.notes.attacher"
  member  = "serviceAccount:${var.github_deployer_sa_email}"
}

resource "google_project_iam_member" "github_deployer_occurrences_editor" {
  project = var.project_id
  role    = "roles/containeranalysis.occurrences.editor"
  member  = "serviceAccount:${var.github_deployer_sa_email}"
}
