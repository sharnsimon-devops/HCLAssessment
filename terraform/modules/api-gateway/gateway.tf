resource "google_api_gateway_api" "api" {
  provider = google-beta
  project  = var.project_id
  api_id   = "${var.environment}-services-api"
}

resource "google_api_gateway_api_config" "api_config" {
  provider      = google-beta
  project       = var.project_id
  api           = google_api_gateway_api.api.api_id
  api_config_id = "${var.environment}-services-api-config-${substr(filesha256("${path.module}/openapi.yaml"), 0, 8)}"

  openapi_documents {
    document {
      path     = "openapi.yaml"
      contents = filebase64("${path.module}/openapi.yaml")
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_api_gateway_gateway" "gateway" {
  provider   = google-beta
  project    = var.project_id
  region     = var.region
  api_config = google_api_gateway_api_config.api_config.id
  gateway_id = "${var.environment}-services-gateway"
}
