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
