resource "google_service_account" "gke_node" {
  project      = var.project_id
  account_id   = "${var.environment}-gke-node-sa"
  display_name = "GKE Node Service Account (${var.environment})"
}

locals {
  gke_node_sa_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader",
  ]
}

resource "google_project_iam_member" "gke_node_sa_roles" {
  for_each = toset(local.gke_node_sa_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.gke_node.email}"
}
