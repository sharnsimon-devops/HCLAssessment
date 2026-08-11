variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
}

variable "network_self_link" {
  description = "Self-link of the VPC network"
  type        = string
}

variable "private_subnet_self_link" {
  description = "Self-link of the private subnet the cluster's nodes"
  type        = string
}

variable "pods_range_name" {
  description = "Name of the secondary IP range reserved for pods"
  type        = string
}

variable "services_range_name" {
  description = "Name of the secondary IP range reserved for services"
  type        = string
}

variable "gke_master_cidr" {
  description = "CIDR block for the GKE control plane"
  type        = string
}

variable "master_authorized_cidr" {
  description = "Source CIDR allowed to reach the GKE master's public API endpoint"
  type        = string
}

variable "gke_node_sa_email" {
  description = "Email of the least-privilege GKE node service account"
  type        = string
}

variable "artifact_registry_kms_key_id" {
  description = "KMS key ID used to encrypt the Artifact Registry repository (CMEK)"
  type        = string
}
