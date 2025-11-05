terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 7.22.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "oci" {
  # Terraform's OCI provider will use environment variables or the default
  # SDK config at ~/.oci/config. Make sure the shell running terraform has
  # OCI_CONFIG_FILE and OCI_PROFILE set to the profile that matches the
  # API key uploaded to the Console (you've already confirmed these in your shell).
  tenancy_ocid = var.tenancy_ocid
  user_ocid    = var.user_ocid
  region       = var.region
}

# The object storage namespace is used as the tenancy namespace for OCIR repository paths
data "oci_objectstorage_namespace" "namespace" {}

# Reference the existing terraform-admins group instead of creating it
data "oci_identity_groups" "terraform_admins" {
  compartment_id = var.tenancy_ocid

  filter {
    name   = "name"
    values = ["terraform-admins"]
  }
}

# Extract the group ID for easier reference
locals {
  # Use try() to handle case where terraform-admins group doesn't exist
  terraform_admin_group_id = try(
    data.oci_identity_groups.terraform_admins.groups[0].id,
    null
  )
}

# Validation: ensure terraform-admins group exists
resource "null_resource" "validate_terraform_group" {
  count = local.terraform_admin_group_id == null ? 1 : 0

  provisioner "local-exec" {
    command = "echo 'ERROR: terraform-admins group not found in tenancy' && exit 1"
  }
}

# Terraform management policies
resource "oci_identity_policy" "terraform_policy" {
  compartment_id = var.tenancy_ocid
  name           = "TerraformManagementPolicy"
  description    = "Policies for Terraform to manage infrastructure"

  statements = [
    # Compute permissions
    "Allow group terraform-admins to manage instance-family in compartment id ${var.compartment_ocid}",
    "Allow group terraform-admins to manage volume-family in compartment id ${var.compartment_ocid}",

    # Networking permissions
    "Allow group terraform-admins to manage virtual-network-family in compartment id ${var.compartment_ocid}",

    # Load balancer (for future use)
    "Allow group terraform-admins to manage load-balancers in compartment id ${var.compartment_ocid}",

    # Container registry
    "Allow group terraform-admins to manage repos in compartment id ${var.compartment_ocid}",

    # Object storage (for your buckets)
    "Allow group terraform-admins to manage buckets in compartment id ${var.compartment_ocid}",
    "Allow group terraform-admins to manage objects in compartment id ${var.compartment_ocid}",
  ]
}

resource "oci_identity_policy" "administrators_policy" {
  compartment_id = var.tenancy_ocid
  name           = "AdministratorsPolicy"
  description    = "Default policy for Administrators group"
  statements = [
    "Allow group Administrators to manage all-resources in tenancy"
  ]
}

/* The Administrators group membership: we add a resource so it can be imported
  into Terraform state. If you want to manage membership outside Terraform,
  remove this resource block again. */


module "identity_users" {
  source = "./modules/identity-users"

  tenancy_ocid           = var.tenancy_ocid
  service_account_id     = "test-service-account"
  aiu_service_account_id = "test-aiu-account"
}

module "compute" {
  source = "./modules/compute"

  compartment_ocid      = var.compartment_ocid
  availability_domain   = var.availability_domain
  image_id              = var.image_id
  ssh_public_key        = var.ssh_public_key
  vm_count              = 2
  allowed_k8s_api_cidrs = var.allowed_k8s_api_cidrs

  depends_on = [
    oci_identity_policy.terraform_policy,
    oci_identity_policy.administrators_policy
  ]
}

# Create OCIR container repositories for projects (frolf & resume)
module "container_registry_frolf" {
  source = "./modules/container-registry"

  compartment_ocid  = var.compartment_ocid
  tenancy_namespace = data.oci_objectstorage_namespace.namespace.namespace
  repo_name         = "frolf-bot"

  depends_on = [oci_identity_policy.terraform_policy]
}

module "container_registry_resume" {
  source = "./modules/container-registry"

  compartment_ocid  = var.compartment_ocid
  tenancy_namespace = data.oci_objectstorage_namespace.namespace.namespace
  repo_name         = "resume"

  depends_on = [oci_identity_policy.terraform_policy]
}

output "instance_public_ips" {
  description = "Public IPs of the compute instances"
  value       = module.compute.public_ips
}
