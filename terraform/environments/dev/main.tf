module "vpc" {
  source = "../../modules/vpc"

  project_id      = var.project_id
  region          = var.region
  environment     = var.environment
  gke_master_cidr = var.gke_master_cidr
}

module "iam_kms" {
  source = "../../modules/iam-kms"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
}

module "gke" {
  source = "../../modules/gke"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment

  network_self_link        = module.vpc.network_self_link
  private_subnet_self_link = module.vpc.private_subnet_self_link
  pods_range_name           = module.vpc.pods_range_name
  services_range_name       = module.vpc.services_range_name
  gke_master_cidr           = var.gke_master_cidr
  gke_node_sa_email         = module.iam_kms.gke_node_sa_email
  master_authorized_cidr    = var.master_authorized_cidr
  artifact_registry_kms_key_id = module.iam_kms.artifact_registry_kms_key_id
}

module "cloud_armor" {
  source = "../../modules/cloud-armor"

  project_id  = var.project_id
  environment = var.environment
}

module "api_gateway" {
  source = "../../modules/api-gateway"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
}

module "binauthz" {
  source = "../../modules/binauthz"

  project_id                = var.project_id
  environment                = var.environment
  attestor_signing_key_id    = module.iam_kms.attestor_signing_key_id
}

module "load_balancer" {
  source = "../../modules/load-balancer"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment

  gateway_id          = module.api_gateway.gateway_id
  security_policy_id  = module.cloud_armor.security_policy_id
}
