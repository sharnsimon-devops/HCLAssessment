output "network_name" {
  description = "network"
  value       = google_compute_network.main.name
}

output "network_self_link" {
  description = "The self-link of the VPC network"
  value       = google_compute_network.main.self_link
}

output "private_subnet_name" {
  description = "private subnet"
  value       = google_compute_subnetwork.private.name
}

output "private_subnet_self_link" {
  description = "The self-link of the private subnet"
  value       = google_compute_subnetwork.private.self_link
}

output "pods_range_name" {
  description = "Name of the secondary IP range for pods"
  value       = "gke-pods-range"
}

output "services_range_name" {
  description = "Name of the secondary IP range  for  services"
  value       = "gke-services-range"
}

output "public_subnet_name" {
  description = "public subnet"
  value       = google_compute_subnetwork.public.name
}

output "public_subnet_self_link" {
  description = "The self-link of the public subnet"
  value       = google_compute_subnetwork.public.self_link
}
