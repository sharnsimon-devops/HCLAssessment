resource "google_compute_backend_service" "lb1" {
  project               = var.project_id
  name                  = "${var.environment}-lb1-backend-service"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"
  security_policy       = var.security_policy_id

  backend {
    group = google_compute_region_network_endpoint_group.api_gateway.id
  }
}
