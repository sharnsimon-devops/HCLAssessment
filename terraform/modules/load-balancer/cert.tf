resource "tls_private_key" "lb1" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "lb1" {
  private_key_pem = tls_private_key.lb1.private_key_pem

  subject {
    common_name  = google_compute_global_address.lb1.address
    organization = "hcl-assessment"
  }

  ip_addresses = [google_compute_global_address.lb1.address]

  validity_period_hours = 8760 # 1 year - no domain to auto-renew against, self-signed only

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "google_compute_ssl_certificate" "lb1" {
  project     = var.project_id
  name        = "${var.environment}-lb1-self-signed-cert"
  private_key = tls_private_key.lb1.private_key_pem
  certificate = tls_self_signed_cert.lb1.cert_pem

  lifecycle {
    create_before_destroy = true
  }
}
