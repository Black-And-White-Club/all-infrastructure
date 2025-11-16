resource "oci_objectstorage_bucket" "buckets" {
  for_each = var.buckets

  compartment_id = var.compartment_ocid
  namespace      = var.namespace
  name           = each.value.name
  # Additional optional value could be added here (like public_access_type or storage_tier) if needed later
}

