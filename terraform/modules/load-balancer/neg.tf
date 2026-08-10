resource "google_compute_region_network_endpoint_group" "api_gateway" {
  provider              = google-beta
  project               = var.project_id
  name                  = "${var.environment}-api-gateway-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  serverless_deployment {
    platform = "apigateway.googleapis.com"
    resource = var.gateway_id
  }
}
