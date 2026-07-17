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

variable "frolf_postgres_backup_bucket_name" {
  description = "OCI Object Storage bucket for frolf-bot postgres backups"
  type        = string
  default     = "frolf-postgres-backup"
}

variable "sealed_secrets_backup_bucket_name" {
  description = "OCI Object Storage bucket for sealed-secrets controller key backups"
  type        = string
  default     = "sealed-secrets-backup"
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

variable "cloudflare_ipv4_cidrs" {
  description = "Cloudflare's published IPv4 ranges (https://www.cloudflare.com/ips-v4/) allowed to reach the LB on 80/443. Unlike allowed_ssh_cidrs/allowed_k8s_api_cidrs, this is public, non-sensitive data, so the real values live in the committed default below (not gitignored terraform.tfvars) — the CI plan/apply workflows never source a tfvars file, so a default here is required for the origin lockdown to actually apply. See the comment above the dynamic ingress_security_rules blocks in modules/compute/network.tf if this list ever needs revisiting."
  type        = list(string)
  default = [
    "173.245.48.0/20",
    "103.21.244.0/22",
    "103.22.200.0/22",
    "103.31.4.0/22",
    "141.101.64.0/18",
    "108.162.192.0/18",
    "190.93.240.0/20",
    "188.114.96.0/20",
    "197.234.240.0/22",
    "198.41.128.0/17",
    "162.158.0.0/15",
    "104.16.0.0/13",
    "104.24.0.0/14",
    "172.64.0.0/13",
    "131.0.72.0/22",
  ]
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

variable "service_account_name" {
  description = "OCI user name for the application service account. WARNING: renaming recreates the user and invalidates its auth tokens/API keys — rotate credentials deliberately."
  type        = string
  default     = "test-service-account"
}

variable "image_updater_account_name" {
  description = "OCI user name for the ArgoCD Image Updater service account. WARNING: renaming recreates the user and invalidates its auth tokens/API keys — rotate credentials deliberately."
  type        = string
  default     = "test-aiu-account"
}
