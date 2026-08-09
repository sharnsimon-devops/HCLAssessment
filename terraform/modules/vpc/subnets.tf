resource "google_compute_subnetwork" "private" {
  project       = var.project_id
  name          = "${var.environment}-private-subnet"
  region        = var.region
  network       = google_compute_network.main.self_link
  ip_cidr_range = var.private_subnet_cidr

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "gke-pods-range"
    ip_cidr_range = var.private_pods_cidr
  }

  secondary_ip_range {
    range_name    = "gke-services-range"
    ip_cidr_range = var.private_services_cidr
  }
}

resource "google_compute_subnetwork" "public" {
  project       = var.project_id
  name          = "${var.environment}-public-subnet"
  region        = var.region
  network       = google_compute_network.main.self_link
  ip_cidr_range = var.public_subnet_cidr
}
