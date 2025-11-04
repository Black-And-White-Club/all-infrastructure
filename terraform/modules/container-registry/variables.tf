variable "compartment_ocid" {
  description = "OCI compartment OCID where the repository will be created"
  type        = string
}

variable "tenancy_namespace" {
  description = "OCI tenancy namespace used for OCIR (the namespace part of repository URL)"
  type        = string
}

variable "repo_name" {
  description = "The name of the repository"
  type        = string
}


