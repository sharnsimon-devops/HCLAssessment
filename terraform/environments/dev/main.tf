module "vpc" {
  source = "../../modules/vpc"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
}

module "iam_kms" {
  source = "../../modules/iam-kms"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
}
