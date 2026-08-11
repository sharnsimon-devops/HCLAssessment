variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment name (dev, staging, prod)"
  type        = string
}

variable "github_deployer_sa_email" {
  description = "Email of the existing github-deployer service account (created as a prerequisite, used by GitHub Actions via WIF). Not created here."
  type        = string
  default     = "github-deployer@hcl-assessment.iam.gserviceaccount.com"
}

