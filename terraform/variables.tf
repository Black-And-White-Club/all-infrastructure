variable "tenancy_ocid" {
  description = "OCID of the tenancy"
  type        = string
}

variable "user_ocid" {
  description = "OCID of the user"
  type        = string
}

variable "region" {
  description = "OCI region"
  type        = string
}

variable "compartment_ocid" {
  description = "OCID of the compartment"
  type        = string
}

variable "resume_compartment_ocid" {
  description = "OCID of the resume compartment"
  type        = string
}

variable "frolf_bot_compartment_ocid" {
  description = "OCID of the frolf bot compartment"
  type        = string
}

variable "resume_bucket_ocid" {
  description = "OCID of the resume bucket"
  type        = string
}

variable "frolf_bot_bucket_ocid" {
  description = "OCID of the frolf bot bucket"
  type        = string
}

variable "resume_repo_ocid" {
  description = "OCID of the resume repository"
  type        = string
}

variable "frolf_bot_repo_ocid" {
  description = "OCID of the frolf bot repository"
  type        = string
}

variable "namespace" {
  description = "Namespace for the resources"
  type        = string
}

variable "availability_domain" {
  description = "OCI availability domain for compute resources"
  type        = string
}

variable "shape" {
  description = "OCI instance shape"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "shape_config" {
  description = "Shape configuration for flexible ARM shapes"
  type = object({
    ocpus         = number
    memory_in_gbs = number
  })
  default = {
    ocpus         = 2
    memory_in_gbs = 12
  }
}

variable "shape_configs" {
  description = "Per-VM shape configurations. Map of VM index to shape config. Falls back to shape_config if not specified."
  type = map(object({
    ocpus         = number
    memory_in_gbs = number
  }))
  default = {}
}

variable "boot_volume_size_in_gbs" {
  description = "Boot volume size for compute instances (minimum 50GB)"
  type        = number
  default     = 50
}

variable "image_id" {
  description = "OCI image OCID - Use Oracle Linux 8 ARM64"
  type        = string
  # You'll need to get the ARM64 image OCID for your region
  # See instructions below
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
}

variable "admin_group_ocid" {
  description = "OCID of the Administrators group"
  type        = string
}

variable "allowed_k8s_api_cidrs" {
  description = "List of CIDR blocks allowed to access Kubernetes API server (port 6443). Keep this in terraform.tfvars (gitignored)."
  type        = list(string)
  default     = []
}

variable "mimir_bucket_name" {
  description = "Name of the OCI object bucket for Mimir"
  type        = string
  default     = "mimir-shared-bucket"
}

variable "loki_bucket_name" {
  description = "Name of the OCI object bucket for Loki"
  type        = string
  default     = "loki-shared-bucket"
}

variable "tempo_bucket_name" {
  description = "Name of the OCI object bucket for Tempo"
  type        = string
  default     = "tempo-shared-bucket"
}

variable "disks" {
  description = "Optional map of block storage disks definitions for provisioning via block-storage module"
  type = map(object({
    name                = string
    size                = number
    type                = optional(string, "")
    availability_domain = optional(string, "")
    labels              = optional(map(string), {})
  }))
  default = {}
}

variable "resume_db_disk_size" {
  description = "Size in GiB for the resume db block volume (default 20)"
  type        = number
  default     = 20
}

variable "create_resume_db_block_storage" {
  description = "If true, create an OCI block volume for resume DB and attach it to a compute instance. Default false to avoid accidental Always Free usage."
  type        = bool
  default     = false
}

variable "enable_resume_db_remote_setup" {
  description = "If true, Terraform will SSH into the worker and ensure /mnt/data/resume-db exists and has correct ownership. Requires ssh_private_key_path and SSH reachability to the worker."
  type        = bool
  default     = false
}

variable "resume_db_mount_host" {
  description = "Optional explicit host (public IP) to use for remote-exec to set up the mount path. If empty, will default to module.compute.public_ips[0] if assign_reserved_ips is set appropriately."
  type        = string
  default     = ""
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for connection when enable_resume_db_remote_setup is true. Ensure this path is accessible to the Terraform runtime and secured (not committed)."
  type        = string
  default     = ""
}

variable "vm_count" {
  description = "Number of compute instances to create in the compute module"
  type        = number
  default     = 2
}

variable "vm_names" {
  description = "List of VM names to create"
  type        = list(string)
  default     = ["k8s-control-plane", "k8s-worker"]
}

variable "assign_reserved_ips" {
  description = "List of booleans indicating if each VM should receive a reserved public ip (default disabled for all nodes)"
  type        = list(bool)
  default     = [false, false]
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed SSH access (port 22). Keep this in terraform.tfvars (gitignored). Empty list = deny all external SSH."
  type        = list(string)
  default     = []
}

variable "user_email_prefix" {
  description = "Email prefix/username for service account users (before the + and domain). Keep in terraform.tfvars (gitignored)."
  type        = string
}

variable "user_email_domain" {
  description = "Email domain for service account users (e.g., gmail.com, example.com)"
  type        = string
  default     = "gmail.com"
}

variable "resume_certificate_ocid" {
  description = "OCID of the OCI certificate (from Certificates service) to use for HTTPS termination on the load balancer"
  type        = string
  default     = ""
}

variable "resume_certificate_file_path" {
  description = "Path to the certificate PEM file (for importing cert-manager cert to OCI). e.g., /tmp/cert.pem"
  type        = string
  default     = ""
}

variable "resume_certificate_key_path" {
  description = "Path to the private key PEM file (for importing cert-manager cert to OCI). e.g., /tmp/key.pem"
  type        = string
  default     = ""
}
