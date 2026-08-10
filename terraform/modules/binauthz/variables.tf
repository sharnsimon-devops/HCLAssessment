variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Deployment environment name (dev, staging, prod)"
  type        = string
}

variable "attestor_signing_key_id" {
  description = "ID of the Binary Authorization asymmetric signing key (from the iam-kms module)"
  type        = string
}
