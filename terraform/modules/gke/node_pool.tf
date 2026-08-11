resource "google_container_node_pool" "primary" {
  project  = var.project_id
  name     = "${var.environment}-primary-node-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name

  initial_node_count = 1

  autoscaling {
    total_min_node_count = 1
    total_max_node_count = 3
    location_policy      = "BALANCED"
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = "e2-standard-4"
    service_account = var.gke_node_sa_email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    tags            = ["gke-node"]

    metadata = {
      disable-legacy-endpoints = "true"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}
