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
