output "gke_node_sa_email" {
  description = "Email of the least-privilege GKE node service account"
  value       = google_service_account.gke_node.email
}

output "kms_key_ring_id" {
  description = "ID of the KMS keyring holding the Binary Authorization attestation signing key"
  value       = google_kms_key_ring.binauthz.id
}

output "attestor_signing_key_id" {
  description = "ID of the asymmetric signing key used for Binary Authorization attestations"
  value       = google_kms_crypto_key.attestor_signing_key.id
}

output "attestor_signing_key_version" {
  description = "Resource name of the signing key's first version, used when creating attestation"
  value       = "${google_kms_crypto_key.attestor_signing_key.id}/cryptoKeyVersions/1"
}
