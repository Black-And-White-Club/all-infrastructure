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

variable "backend_ip_addresses" {
  description = "List of backend private IP addresses representing the nodes"
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

variable "backend_https_port" {
  type        = number
  description = "Port on backend instances to receive HTTPS (NodePort) from LB"
  default     = 443
}

variable "http_health_path" {
  type        = string
  description = "HTTP health check path for the HTTP backend set"
  default     = "/healthz"
}

variable "http_health_protocol" {
  type        = string
  description = "Protocol used for the HTTP backend health check (HTTP or TCP)"
  default     = "TCP"
}

variable "enable_https_listener" {
  type        = bool
  description = "Whether to create an HTTPS listener with TLS termination"
  default     = true
}

variable "certificate_ocid" {
  type        = string
  description = "OCID of the OCI certificate to use for HTTPS listener (from Certificates service)"
  default     = ""
}
