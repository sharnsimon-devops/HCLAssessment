resource "google_compute_security_policy" "waf" {
  project     = var.project_id
  name        = "${var.environment}-cloud-armor-policy"
  description = "Standard tier WAF: preconfigured OWASP rule sets + rate limiting. Rules managed as separate google_compute_security_policy_rule resources (see rules.tf) - required for the preconfigured_waf_config exclusion below."
  type        = "CLOUD_ARMOR"

  advanced_options_config {
    log_level = "VERBOSE"
  }
}
