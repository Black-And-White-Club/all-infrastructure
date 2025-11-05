resource "oci_core_volume" "volume" {
  for_each = var.disks

  compartment_id      = var.compartment_ocid
  availability_domain = length(each.value.availability_domain) > 0 ? each.value.availability_domain : var.default_availability_domain
  display_name        = each.value.name
  size_in_gbs         = each.value.size
  # You can add more OCI-specific attributes here (e.g. vpus_per_gbs, backup_policy_id)
}
