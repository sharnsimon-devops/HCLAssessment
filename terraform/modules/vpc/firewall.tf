resource "google_compute_firewall" "allow_internal" {
  project   = var.project_id
  name      = "${var.environment}-allow-internal"
  network   = google_compute_network.main.self_link
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    var.private_subnet_cidr,
    var.private_pods_cidr,
    var.private_services_cidr,
    var.public_subnet_cidr,
  ]
}

resource "google_compute_firewall" "allow_gke_control_plane" {
  project   = var.project_id
  name      = "${var.environment}-allow-gke-control-plane"
  network   = google_compute_network.main.self_link
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["443", "10250"]
  }

  source_ranges = [var.gke_master_cidr]
  target_tags   = ["gke-node"]
}
