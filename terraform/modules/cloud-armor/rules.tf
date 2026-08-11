resource "google_compute_security_policy_rule" "sqli" {
  project         = var.project_id
  security_policy = google_compute_security_policy.waf.name
  action          = "deny(403)"
  priority        = 1000
  description     = "Block SQL injection"

  match {
    expr {
      expression = "evaluatePreconfiguredWaf('sqli-v33-stable')"
    }
  }

}

resource "google_compute_security_policy_rule" "xss" {
  project         = var.project_id
  security_policy = google_compute_security_policy.waf.name
  action          = "deny(403)"
  priority        = 1001
  description     = "Block cross-site scripting"

  match {
    expr {
      expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
    }
  }
}

resource "google_compute_security_policy_rule" "lfi" {
  project         = var.project_id
  security_policy = google_compute_security_policy.waf.name
  action          = "deny(403)"
  priority        = 1002
  description     = "Block local file inclusion"

  match {
    expr {
      expression = "evaluatePreconfiguredExpr('lfi-v33-stable')"
    }
  }
}

resource "google_compute_security_policy_rule" "rfi" {
  project         = var.project_id
  security_policy = google_compute_security_policy.waf.name
  action          = "deny(403)"
  priority        = 1003
  description     = "Block remote file inclusion"

  match {
    expr {
      expression = "evaluatePreconfiguredExpr('rfi-v33-stable')"
    }
  }
}

resource "google_compute_security_policy_rule" "rce" {
  project         = var.project_id
  security_policy = google_compute_security_policy.waf.name
  action          = "deny(403)"
  priority        = 1004
  description     = "Block remote code execution"

  match {
    expr {
      expression = "evaluatePreconfiguredExpr('rce-v33-stable')"
    }
  }
}

resource "google_compute_security_policy_rule" "java_attacks" {
  project         = var.project_id
  security_policy = google_compute_security_policy.waf.name
  action          = "deny(403)"
  priority        = 1005
  description     = "Block known-CVE exploit attempts, including Log4Shell (CVE-2021-44228)"

  match {
    expr {
      expression = "evaluatePreconfiguredExpr('cve-canary')"
    }
  }
}

resource "google_compute_security_policy_rule" "rate_limit" {
  project         = var.project_id
  security_policy = google_compute_security_policy.waf.name
  action          = "throttle"
  priority        = 2000
  description     = "Rate limit: 100 requests/min per client IP"

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
