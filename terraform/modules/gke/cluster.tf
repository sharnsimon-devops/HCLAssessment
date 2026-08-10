resource "google_container_cluster" "primary" {
  project  = var.project_id
  name     = "${var.environment}-gke-cluster"
  location = var.region

  network    = var.network_self_link
  subnetwork = var.private_subnet_self_link

  networking_mode = "VPC_NATIVE"
  
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.gke_master_cidr
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  release_channel {
    channel = "REGULAR"
  }

  # Node pool managed separately - see node_pool.tf
  remove_default_node_pool = true
  initial_node_count       = 1

  # Binary Authorization intentionally left unset here - enabled in Phase 10,
  # after a normal deploy has been proven to work.

  deletion_protection = false
}
