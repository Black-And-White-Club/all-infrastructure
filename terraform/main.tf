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
  email_prefix           = var.user_email_prefix
  user_email_domain      = var.user_email_domain
}

/* resume_db_block_storage module and computed locals removed here; retained later in the file to avoid duplicates. */

module "resume_db_block_storage" {
  count  = var.create_resume_db_block_storage ? 1 : 0
  source = "./modules/block-storage"

  # Define a single disk for the resume database which will be attached to the compute instance
  disks = {
    resume-db = {
      name = "resume-db-volume"
      size = var.resume_db_disk_size
      # Use availability_domain from the root terraform variables so the volume and instance are in the same AD
      availability_domain = var.availability_domain
    }
  }

  compartment_ocid            = var.compartment_ocid
  default_availability_domain = var.availability_domain
}

locals {
  computed_disk_ocids      = var.create_resume_db_block_storage ? module.resume_db_block_storage[0].disk_ocids : {}
  computed_disk_attach_map = { for k, v in local.computed_disk_ocids : k => 1 }
}

module "compute" {
  source = "./modules/compute"

  compartment_ocid        = var.compartment_ocid
  availability_domain     = var.availability_domain
  shape                   = var.shape
  image_id                = var.image_id
  shape_config            = var.shape_config
  shape_configs           = var.shape_configs
  ssh_public_key          = var.ssh_public_key
  vm_count                = var.vm_count
  vm_names                = var.vm_names
  assign_reserved_ips     = var.assign_reserved_ips
  allowed_k8s_api_cidrs   = var.allowed_k8s_api_cidrs
  allowed_ssh_cidrs       = var.allowed_ssh_cidrs
  boot_volume_size_in_gbs = var.boot_volume_size_in_gbs

  depends_on = [
    oci_identity_policy.terraform_policy,
    oci_identity_policy.administrators_policy
  ]

  # Attach any created block-storage volumes to compute instances.
  # module.block_storage.disk_ocids is provided below; we pass it into compute so attachments are created.
  disk_ocids                  = local.computed_disk_ocids
  disk_attach_to              = local.computed_disk_attach_map
  enable_resume_db_auto_mount = false
  resume_db_mount_point       = "/mnt/data/resume-db"
  backend_https_port          = 30443
}

# Optional remote setup: ensure /mnt/data/resume-db directory exists and is owned appropriately
resource "null_resource" "resume_db_directory_setup" {
  count = var.enable_resume_db_remote_setup ? 1 : 0

  # Make sure the compute module is ready
  depends_on = [module.compute]

  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash -eux",
      "sudo mkdir -p /mnt/data/resume-db",
      "sudo chown 1001:1001 /mnt/data/resume-db",
      "sudo chmod 700 /mnt/data/resume-db",
    ]
    connection {
      type        = "ssh"
      user        = "opc"
      host        = var.resume_db_mount_host != "" ? var.resume_db_mount_host : module.compute.public_ips[0]
      private_key = file(var.ssh_private_key_path)
    }
  }
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

module "object_storage" {
  source = "./modules/object-storage"

  compartment_ocid = var.compartment_ocid
  namespace        = data.oci_objectstorage_namespace.namespace.namespace
  buckets = {
    mimir = { name = var.mimir_bucket_name }
    loki  = { name = var.loki_bucket_name }
    tempo = { name = var.tempo_bucket_name }
  }

  depends_on = [oci_identity_policy.terraform_policy]
}

module "resume_load_balancer" {
  source = "./modules/load-balancer"

  compartment_ocid = var.compartment_ocid
  subnet_ids       = [module.compute.subnet_id]
  # Only route traffic to worker node(s), not control plane
  # vm_names = ["k8s-control-plane", "k8s-worker"] → index 1 is worker
  backend_ip_addresses  = [module.compute.private_ips[1]]
  name_prefix           = "resume-ingress"
  backend_http_port     = 30080
  backend_https_port    = 30443
  http_health_path      = "/healthz"
  enable_https_listener = true
  certificate_ocid      = var.resume_certificate_ocid
}

/* resume_db_block_storage and locals moved up above compute to avoid forward reference and duplication */

/* Pass generated disk OCIDs into compute module instance via provably-existing variable reference
   The compute module attaches disks by index (disk_attach_to). Here we attach resume-db to instance at index 1. */
/* compute_extra_disk_bindings removed; disk attachment wiring now occurs via variables passed to the compute module above. */

output "object_storage_buckets" {
  description = "Created object storage buckets for observability"
  value       = module.object_storage.bucket_names
}

output "instance_public_ips" {
  description = "Public IPs of the compute instances"
  value       = module.compute.public_ips
}

# Instance Principals for OCI CSI Driver
# This creates a dynamic group and policies so the CSI driver can
# provision block volumes without needing API keys in secrets.
module "csi_instance_principals" {
  source = "./modules/csi-instance-principals"

  tenancy_ocid     = var.tenancy_ocid
  compartment_ocid = var.compartment_ocid

  # You can make the matching rule more specific if needed, e.g.:
  # matching_rule = "Any {instance.id = 'ocid1.instance...', instance.id = 'ocid1.instance...'}"
}

output "csi_dynamic_group_name" {
  description = "Name of the dynamic group for CSI driver"
  value       = module.csi_instance_principals.dynamic_group_name
}
