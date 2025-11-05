output "disk_ocids" {
  description = "Map of disk identifier -> OCI volume OCID"
  value       = { for k, d in oci_core_volume.volume : k => d.id }
}

output "disk_names" {
  description = "Map of disk identifier -> disk name"
  value       = { for k, d in oci_core_volume.volume : k => d.display_name }
}

# Backwards-compatible alias (previously 'disk_self_links') — now maps to OCIDs
output "disk_self_links" {
  description = "Compatibility: previously GCP self_link, now returns OCI volume OCID"
  value       = { for k, d in oci_core_volume.volume : k => d.id }
}
