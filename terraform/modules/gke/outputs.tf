output "artifact_registry_repository_id" {
  description = "ID of the Artifact Registry Docker repository"
  value       = google_artifact_registry_repository.docker.repository_id
}

output "artifact_registry_url" {
  description = "Full URL prefix used to push/pull images, e.g. <url>/order-service:<tag>"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
}

output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "Public endpoint of the GKE control plane"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}
