terraform {
  backend "gcs" {
    bucket = "terraform-state-bucket-gke-assessment"
    prefix = "dev/terraform/state"
  }
}
