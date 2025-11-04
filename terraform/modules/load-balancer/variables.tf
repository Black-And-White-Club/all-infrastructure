variable "compartment_ocid" {
  description = "OCI compartment OCID for the load balancer"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet OCIDs where the Load Balancer will be placed (public subnets)"
  type        = list(string)
}

variable "backend_instance_ocids" {
  description = "List of compute instance OCIDs to add as backends"
  type        = list(string)
  default     = []
}

variable "ssl_certificate_ids" {
  description = "List of OCI certificate OCIDs to attach to the HTTPS listener"
  type        = list(string)
  default     = []
}

variable "name_prefix" {
  type        = string
  description = "Prefix for LB resource names"
  default     = "resume-app"
}

variable "backend_http_port" {
  type        = number
  description = "Port on backend instances to receive HTTP from LB (NodePort or service port)"
  default     = 80
}
