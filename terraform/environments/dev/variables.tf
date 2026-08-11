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

variable "gke_master_cidr" {
  description = "CIDR block for the GKE control plane. Shared by the vpc module (firewall rule source range) and the gke module (master_ipv4_cidr_block) so both always match."
  type        = string
  default     = "172.16.0.16/28"
}

variable "master_authorized_cidr" {
  description = "Source CIDR allowed to reach the GKE master's public API endpoint (kubectl access). Update this if your public IP changes."
  type        = string
  default     = "148.252.140.117/32"
}
