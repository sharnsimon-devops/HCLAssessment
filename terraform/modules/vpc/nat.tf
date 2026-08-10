resource "google_compute_router" "router" {
  project = var.project_id
  name    = "${var.environment}-router"
  region  = var.region
  network = google_compute_network.main.self_link
}

resource "google_compute_router_nat" "nat" {
  project = var.project_id
  name    = "${var.environment}-nat"
  router  = google_compute_router.router.name
  region  = var.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.private.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
