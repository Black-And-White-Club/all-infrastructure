module "container_registry_frolf_pwa" {
  source = "./modules/container-registry"

  compartment_ocid  = var.compartment_ocid
  tenancy_namespace = data.oci_objectstorage_namespace.namespace.namespace
  repo_name         = "frolf-bot-pwa"

  depends_on = [oci_identity_policy.terraform_policy]
}
