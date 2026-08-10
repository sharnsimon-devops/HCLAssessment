resource "google_compute_global_forwarding_rule" "lb1" {
  project               = var.project_id
  name                  = "${var.environment}-lb1-forwarding-rule"
  target                = google_compute_target_https_proxy.lb1.id
  ip_address             = google_compute_global_address.lb1.id
  port_range            = "443"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
