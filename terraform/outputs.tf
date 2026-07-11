output "frolf_repo_ocid" {
  description = "OCID of the frolf-bot container repository"
  value       = module.container_registry_frolf.repository_ocid
}

output "resume_repo_ocid" {
  description = "OCID of the resume container repository"
  value       = module.container_registry_resume.repository_ocid
}

output "frolf_repo_url" {
  description = "OCIR repo URL for frolf-bot"
  value       = "${data.oci_objectstorage_namespace.namespace.namespace}.ocir.io/frolf-bot"
}

output "resume_repo_url" {
  description = "OCIR repo URL for resume"
  value       = "${data.oci_objectstorage_namespace.namespace.namespace}.ocir.io/resume"
}

output "resume_load_balancer_id" {
  description = "OCID of the resume nginx load balancer"
  value       = module.resume_load_balancer.load_balancer_id
}

output "resume_load_balancer_ip_addresses" {
  description = "Public IP addresses for the OCI load balancer"
  value       = module.resume_load_balancer.load_balancer_ip_addresses
}

output "object_storage_buckets" {
  description = "Created object storage buckets for observability"
  value       = module.object_storage.bucket_names
}

output "instance_public_ips" {
  description = "Public IPs of the compute instances"
  value       = module.compute.public_ips
}

output "csi_dynamic_group_name" {
  description = "Name of the dynamic group for CSI driver"
  value       = module.csi_instance_principals.dynamic_group_name
}
