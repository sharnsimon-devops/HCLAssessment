output "build_attestor_name" {
  description = "Name of the build attestor"
  value       = google_binary_authorization_attestor.build_attestor.name
}

output "vulnerability_scan_attestor_name" {
  description = "Name of the vulnerability scan attestor"
  value       = google_binary_authorization_attestor.vulnerability_scan_attestor.name
}
