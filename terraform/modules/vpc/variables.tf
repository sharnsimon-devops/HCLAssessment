variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment name "
  type        = string
}

variable "private_subnet_cidr" {
  description = "Primary CIDR range for the private subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "private_pods_cidr" {
  description = "Secondary CIDR range for pods"
  type        = string
  default     = "10.4.0.0/14"
}

variable "private_services_cidr" {
  description = "Secondary CIDR range for service"
  type        = string
  default     = "10.8.0.0/20"
}

variable "public_subnet_cidr" {
  description = "CIDR range for the public subnet"
  type        = string
  default     = "10.100.0.0/24"
}

variable "gke_master_cidr" {
  description = "CIDR block for the GKE control plane."
  type        = string
}
