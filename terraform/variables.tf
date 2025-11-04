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
