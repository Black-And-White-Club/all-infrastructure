variable "tenancy_ocid" {
  description = "OCI tenancy OCID where identity resources will be created"
  type        = string
}

variable "service_account_id" {
  description = "Logical name to use for the application user in OCI"
  type        = string
  default     = "frolf-bot"
}

variable "aiu_service_account_id" {
  description = "Logical name for the AIU user in OCI"
  type        = string
  default     = "frolf-bot-aiu"
}

variable "user_email_domain" {
  description = "Email domain for service account users (e.g., gmail.com, example.com)"
  type        = string
  default     = "gmail.com"
}

variable "email_prefix" {
  description = "Email prefix/username for service account users (before the + and domain)"
  type        = string
}
