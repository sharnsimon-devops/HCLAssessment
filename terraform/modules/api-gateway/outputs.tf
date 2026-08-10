output "gateway_default_hostname" {
  description = "Default hostname of the API Gateway, e.g. for curl verification"
  value       = google_api_gateway_gateway.gateway.default_hostname
}

output "gateway_id" {
  description = "ID of the API Gateway gateway, used as the Serverless NEG target in the load-balancer module"
  value       = google_api_gateway_gateway.gateway.gateway_id
}
