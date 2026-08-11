resource "google_container_cluster" "primary" {
  #checkov:skip=CKV_GCP_65:No Cloud Identity/Workspace security group exists in this project to bind GKE RBAC to; requires a real org-level group, documented as a Phase 12 limitation
  #checkov:skip=CKV_GCP_69:workload_metadata_config is set to GKE_METADATA on the separately-managed node pool (node_pool.tf) - this check only inspects node config inline on this resource, a false positive for our remove_default_node_pool architecture
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

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.master_authorized_cidr
      display_name = "admin-workstation"
    }
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

  enable_intranode_visibility = true

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  resource_labels = {
    environment = var.environment
    managed-by  = "terraform"
  }

  # Node pool managed separately - see node_pool.tf
  remove_default_node_pool = true
  initial_node_count       = 1

  # Phase 10: enforcement enabled now that a normal deploy has been proven
  # to work (Phase 8) and both attestors have a valid signed attestation
  # for order-service:v1 ready to prove the enforce/block behavior.
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  deletion_protection = false
}
