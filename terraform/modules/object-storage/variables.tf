variable "buckets" {
  description = "Map of bucket definitions keyed by id with attributes like name and optional public_access_type"
  type = map(object({
    name               = string
    public_access_type = optional(string)
  }))
  default = {}
}

variable "compartment_ocid" {
  description = "The compartment OCID where the buckets will be created"
  type        = string
}

variable "namespace" {
  description = "Object storage namespace for the tenancy"
  type        = string
}
