resource "google_binary_authorization_policy" "policy" {
  project = var.project_id

  global_policy_evaluation_mode = "ENABLE"

  default_admission_rule {
    evaluation_mode  = "REQUIRE_ATTESTATION"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"

    require_attestations_by = [
      google_binary_authorization_attestor.build_attestor.name,
      google_binary_authorization_attestor.vulnerability_scan_attestor.name,
    ]
  }
}
