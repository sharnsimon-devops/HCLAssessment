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

variable "gateway_id" {
  description = "ID of the API Gateway gateway (from the api-gateway module), used as the Serverless NEG target"
  type        = string
}

variable "security_policy_id" {
  description = "ID of the Cloud Armor security policy (from the cloud-armor module), attached to LB1's backend service"
  type        = string
}
