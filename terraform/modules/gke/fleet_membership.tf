resource "google_gke_hub_membership" "primary" {
  project       = var.project_id
  membership_id = "${var.environment}-gke-membership"

  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.primary.id}"
    }
  }

  authority {
    issuer = "https://container.googleapis.com/v1/${google_container_cluster.primary.id}"
  }
}
