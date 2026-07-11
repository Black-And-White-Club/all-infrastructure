resource "oci_objectstorage_bucket" "buckets" {
  for_each = var.buckets

  compartment_id = var.compartment_ocid
  namespace      = var.namespace
  name           = each.value.name
  # Explicit (matches the OCI default): these backup/observability buckets
  # must never be publicly readable.
  access_type = "NoPublicAccess"
}

locals {
  buckets_with_lifecycle = {
    for k, v in var.buckets : k => v
    if v.lifecycle_days != null
  }
}

resource "oci_objectstorage_object_lifecycle_policy" "retention" {
  for_each  = local.buckets_with_lifecycle
  namespace = var.namespace
  bucket    = oci_objectstorage_bucket.buckets[each.key].name

  rules {
    name        = "expire-after-${each.value.lifecycle_days}-days"
    action      = "DELETE"
    is_enabled  = true
    time_amount = each.value.lifecycle_days
    time_unit   = "DAYS"
    target      = "objects"
  }
}
