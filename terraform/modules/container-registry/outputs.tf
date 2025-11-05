output "repository_ocid" {
  description = "OCID of the created repository"
  value       = oci_artifacts_container_repository.repo.id
}

output "repository_url" {
  description = "A best-effort repository URL placeholder. Replace with exact OCIR URL format for your tenancy/region."
  value       = "${var.tenancy_namespace}.ocir.io/${var.repo_name}"
}




