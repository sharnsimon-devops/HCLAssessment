resource "google_compute_global_address" "lb1" {
  project = var.project_id
  name    = "${var.environment}-lb1-ip"
}
