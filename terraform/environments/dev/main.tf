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
}
