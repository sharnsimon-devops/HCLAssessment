resource "google_kms_key_ring" "artifact_registry" {
  project  = var.project_id
  name     = "${var.environment}-artifact-registry-keyring"
  location = var.region
}

resource "google_kms_crypto_key" "artifact_registry_key" {
  name            = "${var.environment}-artifact-registry-key"
  key_ring        = google_kms_key_ring.artifact_registry.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_project_service_identity" "artifact_registry" {
  provider = google-beta
  project  = var.project_id
  service  = "artifactregistry.googleapis.com"
}

resource "google_kms_crypto_key_iam_member" "artifact_registry_encrypter" {
  crypto_key_id = google_kms_crypto_key.artifact_registry_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_project_service_identity.artifact_registry.email}"
}

resource "time_sleep" "artifact_registry_kms_iam_propagation" {
  depends_on      = [google_kms_crypto_key_iam_member.artifact_registry_encrypter]
  create_duration = "60s"
}
