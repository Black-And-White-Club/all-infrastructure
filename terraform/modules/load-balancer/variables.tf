variable "compartment_ocid" {
  description = "OCI compartment OCID for the load balancer"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet OCIDs where the Load Balancer will be placed (public subnets)"
  type        = list(string)
}

variable "load_balancer_shape" {
  description = "OCI load balancer shape to create (use 'flexible' for the current generation)"
  type        = string
  default     = "flexible"
}

variable "load_balancer_min_bandwidth" {
  description = "Minimum bandwidth for a flexible load balancer (Mbps)"
  type        = number
  default     = 10
}

variable "load_balancer_max_bandwidth" {
  description = "Maximum bandwidth for a flexible load balancer (Mbps)"
  type        = number
  default     = 100
}

variable "ssl_certificate_ids" {
  description = "List of OCI certificate OCIDs to attach to the HTTPS listener"
  type        = list(string)
  default     = []
}

variable "backend_ip_addresses" {
  description = "List of backend compute instance private IP addresses for the load balancer"
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

variable "backend_https_port" {
  type        = number
  description = "Port on backend instances to receive HTTPS (NodePort) from LB - used for TLS passthrough mode"
  default     = 443
}

variable "http_health_path" {
  type        = string
  description = "HTTP health check path (used only when health_check_protocol is HTTP)"
  default     = "/healthz"
}

variable "health_check_protocol" {
  type        = string
  description = "Backend health check protocol (TCP is safer for ingress listener checks)"
  default     = "TCP"

  validation {
    condition     = contains(["TCP", "HTTP"], upper(var.health_check_protocol))
    error_message = "health_check_protocol must be either TCP or HTTP."
  }
}

variable "enable_https_listener" {
  type        = bool
  description = "Whether to create an HTTPS listener (port 443)"
  default     = true
}

variable "certificate_ocid" {
  type        = string
  description = "OCID of the OCI certificate for TLS termination at LB. If empty, uses TLS passthrough (nginx handles TLS)"
  default     = ""
}
