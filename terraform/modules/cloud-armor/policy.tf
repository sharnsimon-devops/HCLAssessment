resource "google_compute_security_policy" "waf" {
  project     = var.project_id
  name        = "${var.environment}-cloud-armor-policy"
  description = "Standard tier WAF: preconfigured OWASP rule sets + rate limiting. Not attached to a backend yet - see Phase 8."
  type        = "CLOUD_ARMOR"

  advanced_options_config {
    log_level = "VERBOSE"
  }

  rule {
    action      = "deny(403)"
    priority    = 1000
    description = "Block SQL injection"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
      }
    }
  }

  rule {
    action      = "deny(403)"
    priority    = 1001
    description = "Block cross-site scripting"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }
  }

  rule {
    action      = "deny(403)"
    priority    = 1002
    description = "Block local file inclusion"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-v33-stable')"
      }
    }
  }

  rule {
    action      = "deny(403)"
    priority    = 1003
    description = "Block remote file inclusion"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rfi-v33-stable')"
      }
    }
  }

  rule {
    action      = "deny(403)"
    priority    = 1004
    description = "Block remote code execution"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-v33-stable')"
      }
    }
  }

  rule {
    action      = "throttle"
    priority    = 2000
    description = "Rate limit: 100 requests/min per client IP"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
    }
  }

  rule {
    action      = "allow"
    priority    = 2147483647
    description = "Default rule: allow anything not matched above"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}
