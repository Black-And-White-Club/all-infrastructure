variable "tenancy_ocid" {
  description = "The tenancy OCID (used as fallback for policy/dynamic-group creation)."
  type        = string
  default     = ""
}

variable "policy_compartment_id" {
  description = "Compartment OCID where policies/dynamic-groups should be created. If empty, falls back to tenancy_ocid."
  type        = string
  default     = ""
}

variable "create_group" {
  description = "Create an OCI Identity Group for GitHub/OIDC (opt-in)."
  type        = bool
  default     = false
}

variable "group_name" {
  description = "Name for the optional OCI Group"
  type        = string
  default     = "github-oidc-group"
}

variable "group_description" {
  description = "Description for the optional OCI Group"
  type        = string
  default     = "Group for GitHub Actions OIDC principals"
}

variable "create_dynamic_group" {
  description = "Create an OCI Dynamic Group. Provide a matching rule when enabling."
  type        = bool
  # default to true so module can be planned/applied out-of-the-box
  default = true
}

variable "dynamic_group_name" {
  description = "Name for the dynamic group"
  type        = string
  default     = "github-oidc-dg"
}

variable "dynamic_group_description" {
  description = "Description for the dynamic group"
  type        = string
  default     = "Dynamic group for GitHub Actions OIDC principals"
}

variable "dynamic_group_matching_rule" {
  description = "Matching rule for the dynamic group. Required when create_dynamic_group is true."
  type        = string
  default     = ""
}

variable "create_policy" {
  description = "Create OCI policy resources (opt-in). Provide statements when enabling."
  type        = bool
  # default to true so module is plan/apply ready
  default = true
}

variable "policy_name" {
  description = "Name for the optional policy to create"
  type        = string
  default     = "github-oidc-policy"
}

variable "policy_statements" {
  description = "Policy statements (OCI policy language) to grant to the group/dynamic group. When empty and create_policy is true, Terraform will error; prefer explicit statements."
  type        = list(string)
  default     = []
}

variable "github_owner" {
  description = "Optional GitHub owner/org used to build a safe default matching rule (e.g. 'my-org')"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "Optional GitHub repository name used to build a safe default matching rule (e.g. 'my-repo')"
  type        = string
  default     = ""
}

variable "create_provider" {
  description = "Create an OCI identity provider (OIDC) for GitHub Actions (opt-in)."
  type        = bool
  # default to true so provider gets created by default (plan/apply-ready)
  default = true
}

variable "provider_name" {
  description = "Name to give the OCI identity provider"
  type        = string
  default     = "github-actions-oidc"
}

variable "provider_description" {
  description = "Description for the OCI identity provider"
  type        = string
  default     = "GitHub Actions OIDC identity provider"
}

variable "provider_issuer" {
  description = "OIDC issuer URL (GitHub Actions uses https://token.actions.githubusercontent.com)"
  type        = string
  default     = "https://token.actions.githubusercontent.com"
}

variable "provider_client_ids" {
  description = "Optional list of client IDs to register with the provider"
  type        = list(string)
  default     = []
}

