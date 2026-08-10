resource "google_compute_url_map" "lb1" {
  project         = var.project_id
  name            = "${var.environment}-lb1-url-map"
  default_service = google_compute_backend_service.lb1.id
}
