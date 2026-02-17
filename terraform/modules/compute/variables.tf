variable "compartment_ocid" {
  description = "OCI compartment OCID where all cloud-engine resources will be created"
  type        = string
}

variable "availability_domain" {
  description = "OCI availability domain to place compute instances in"
  type        = string
}

variable "vcn_cidr" {
  description = "CIDR for the VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "image_id" {
  description = "OCI image OCID to use for compute instances"
  type        = string
}

variable "shape" {
  description = "OCI instance shape"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "shape_config" {
  description = "Default shape configuration for flexible shapes (used if shape_configs not specified)"
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

variable "ssh_public_key" {
  description = "SSH public key content to insert into instances"
  type        = string
}


variable "boot_volume_size_in_gbs" {
  description = "Size of the boot volume attached to each instance"
  type        = number
  default     = 50
}
variable "disk_ocids" {
  description = "Map of disk identifiers -> OCI volume OCIDs to attach to instances"
  type        = map(string)
  default     = {}
}

variable "disk_attach_to" {
  description = "Optional map of disk identifier -> instance index (which VM to attach the disk to). Defaults to 0 (first instance)."
  type        = map(number)
  default     = {}
}

variable "enable_resume_db_auto_mount" {
  description = "If true, add cloud-init user_data to instances that will format and mount an attached block volume at /mnt/data/resume-db"
  type        = bool
  default     = false
}

variable "resume_db_mount_point" {
  description = "Mount point path for the resume DB volume"
  type        = string
  default     = "/mnt/data/resume-db"
}

variable "backend_http_port" {
  type        = number
  description = "Port used by the ingress controller HTTP listener that the external LB will target"
  default     = 80
}

variable "backend_https_port" {
  type        = number
  description = "Port used by the ingress controller HTTPS listener that the external LB will target"
  default     = 443
}

variable "vm_count" {
  description = "Number of VMs to create"
  type        = number
  default     = 1
}

variable "vm_names" {
  description = "List of names for the VMs"
  type        = list(string)
  default     = ["k8s-control-plane", "k8s-worker"]
}

variable "assign_reserved_ips" {
  description = "List of booleans indicating if each VM should get a reserved public IP (default disabled for all nodes)"
  type        = list(bool)
  default     = [false, false]
}

variable "allowed_k8s_api_cidrs" {
  description = "List of CIDR blocks allowed to access Kubernetes API server (port 6443)"
  type        = list(string)
  default     = []
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed SSH access (port 22). Empty list = deny all external SSH."
  type        = list(string)
  default     = []
}
