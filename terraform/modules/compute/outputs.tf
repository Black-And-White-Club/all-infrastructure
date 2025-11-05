output "instance_ocids" {
  description = "List of OCIDs of the compute instances"
  value       = [for vm in oci_core_instance.vm : vm.id]
}

output "public_ips" {
  description = "List of reserved public IPs assigned to the instances"
  value       = [for ip in oci_core_public_ip.reserved_ip : ip.ip_address]
}

output "vcn_id" {
  description = "OCID of the VCN created"
  value       = oci_core_vcn.vcn.id
}

output "subnet_id" {
  description = "OCID of the subnet created"
  value       = oci_core_subnet.public.id
}
