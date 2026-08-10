resource "google_kms_key_ring" "binauthz" {
  project  = var.project_id
  name     = "${var.environment}-binauthz-keyring"
  location = var.region
}

resource "google_kms_crypto_key" "attestor_signing_key" {
  name     = "${var.environment}-attestor-signing-key"
  key_ring = google_kms_key_ring.binauthz.id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm        = "EC_SIGN_P256_SHA256"
    protection_level = "SOFTWARE"
  }
}

