resource "oci_identity_user" "app_user" {
  compartment_id = var.tenancy_ocid
  name           = var.service_account_id
  description    = "Service account user for application: ${var.service_account_id}"
  email          = "romero.jace+${var.service_account_id}@gmail.com"
}

resource "oci_identity_user" "aiu_user" {
  compartment_id = var.tenancy_ocid
  name           = var.aiu_service_account_id
  description    = "AIU user for image updates: ${var.aiu_service_account_id}"
  email          = "romero.jace+${var.aiu_service_account_id}@gmail.com"
}
