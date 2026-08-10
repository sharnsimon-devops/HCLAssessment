output "lb1_ip_address" {
  description = "Public IP address of LB1 - the Cloud Armor-protected entry point"
  value       = google_compute_global_address.lb1.address
}
