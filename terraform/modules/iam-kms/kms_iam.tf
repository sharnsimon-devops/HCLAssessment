resource "google_kms_crypto_key_iam_member" "github_deployer_signer" {
  crypto_key_id = google_kms_crypto_key.attestor_signing_key.id
  role          = "roles/cloudkms.signerVerifier"
  member        = "serviceAccount:${var.github_deployer_sa_email}"
}
