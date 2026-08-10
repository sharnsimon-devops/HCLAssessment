resource "google_compute_target_https_proxy" "lb1" {
  project          = var.project_id
  name             = "${var.environment}-lb1-https-proxy"
  url_map          = google_compute_url_map.lb1.id
  ssl_certificates = [google_compute_ssl_certificate.lb1.id]
}
