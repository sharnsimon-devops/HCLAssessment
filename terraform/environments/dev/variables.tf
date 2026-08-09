variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "hcl-assessment"
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "europe-west2"
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "dev"
}
