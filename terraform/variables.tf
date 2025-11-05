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

variable "image_id" {
  description = "OCID of the OCI image to use for instances"
  type        = string
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
