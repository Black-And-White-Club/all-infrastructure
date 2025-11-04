output "load_balancer_id" {
  description = "OCID of the created load balancer"
  value       = oci_load_balancer_load_balancer.lb.id
}

output "load_balancer_ip_addresses" {
  description = "Map of VIP addresses (IP) for the load balancer listeners"
  value       = oci_load_balancer_load_balancer.lb.ip_addresses
}
