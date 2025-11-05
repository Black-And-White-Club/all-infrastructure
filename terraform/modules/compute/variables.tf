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
  default     = "VM.Standard.E2.1"
}

variable "ssh_public_key" {
  description = "SSH public key content to insert into instances"
  type        = string
}

variable "disk_ocids" {
  description = "Map of disk identifiers -> OCI volume OCIDs to attach to instances"
  type        = map(string)
  default     = {}
}

variable "backend_http_port" {
  type        = number
  description = "Port used by the ingress/nodeport that the external LB will target"
  default     = 30645
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
  description = "List of booleans indicating if each VM should get a reserved public IP"
  type        = list(bool)
  default     = [false, true]
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
