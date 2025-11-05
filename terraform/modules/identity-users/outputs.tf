output "service_account_ocid" {
  description = "OCID of the app user (compatibility for OCI)"
  value       = oci_identity_user.app_user.id
}

output "service_account_name" {
  description = "Name of the app user"
  value       = oci_identity_user.app_user.name
}

output "aiu_service_account_ocid" {
  description = "OCID of the AIU user"
  value       = oci_identity_user.aiu_user.id
}

output "aiu_service_account_name" {
  description = "Name of the AIU user"
  value       = oci_identity_user.aiu_user.name
}
