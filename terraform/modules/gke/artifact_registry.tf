resource "google_artifact_registry_repository" "docker" {
  project       = var.project_id
  location      = var.region
  repository_id = "${var.environment}-docker-repo"
  format        = "DOCKER"
  description   = "Repository for the container images for order-service, application-service, patient-service"
  kms_key_name  = var.artifact_registry_kms_key_id
}
