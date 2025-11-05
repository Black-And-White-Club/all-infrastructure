variable "disks" {
  description = "Map of disk definitions keyed by an identifier. Each entry is an object with name, size and optional labels/availability_domain."
  type = map(object({
    name                = string
    size                = number
    type                = optional(string, "")
    availability_domain = optional(string, "")
    labels              = optional(map(string), {})
  }))
  default = {}
}

variable "compartment_ocid" {
  description = "OCI compartment OCID where volumes will be created"
  type        = string
  default     = ""
}

variable "default_availability_domain" {
  description = "Default availability domain to use when a disk definition does not set one"
  type        = string
  default     = ""
}
