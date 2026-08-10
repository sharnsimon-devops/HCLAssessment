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
}
