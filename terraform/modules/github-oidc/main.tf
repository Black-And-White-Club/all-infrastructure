// GitHub Actions OIDC helper module (OCI-side, opt-in)
//
// This module is intentionally conservative: all resources are created only
// when the corresponding `create_*` flag is set. That lets you store the
// module in the mono repo and enable parts of it when you're ready to
// complete the migration.

locals {
  // determine where tenancy/policies should be created: explicit override
  // (policy_compartment_id) or fall back to tenancy_ocid
  policy_compartment = var.policy_compartment_id != "" ? var.policy_compartment_id : var.tenancy_ocid
}

// Provide an automatic matching rule if none is supplied. When owner/repo
// are provided, restrict to that repository; otherwise match by issuer only.
locals {
  effective_matching_rule = var.dynamic_group_matching_rule != "" ? var.dynamic_group_matching_rule : (
    length(var.github_owner) > 0 && length(var.github_repo) > 0 ?
    "ALL { request.principal.issuer = 'https://token.actions.githubusercontent.com' AND request.principal.claims['repository'] = '${var.github_owner}/${var.github_repo}' }" :
    "ALL { request.principal.issuer = 'https://token.actions.githubusercontent.com' }"
  )

  default_policy_statements = [
    "Allow dynamic-group ${var.dynamic_group_name} to manage artifacts-repository in compartment ${local.policy_compartment}",
    "Allow dynamic-group ${var.dynamic_group_name} to read object-family in compartment ${local.policy_compartment}"
  ]

  effective_policy_statements = length(var.policy_statements) > 0 ? var.policy_statements : local.default_policy_statements
}

// Optional: create a normal OCI Identity Group which can be used for manual
// assignments or to serve as a parent for policies.
resource "oci_identity_group" "group" {
  count          = var.create_group ? 1 : 0
  compartment_id = local.policy_compartment
  name           = var.group_name
  description    = var.group_description
}

// Optional: create a dynamic group. Provide a matching rule when enabling.
resource "oci_identity_dynamic_group" "dynamic_group" {
  count          = var.create_dynamic_group ? 1 : 0
  compartment_id = local.policy_compartment
  name           = var.dynamic_group_name
  description    = var.dynamic_group_description
  matching_rule  = local.effective_matching_rule
}

// Optional: create tenancy/compartment policy statements. The module does
// not invent default statements — supply `policy_statements` when enabling
// policy creation so you can control exactly what privileges are granted.
resource "oci_identity_policy" "policy" {
  count          = var.create_policy ? 1 : 0
  compartment_id = local.policy_compartment
  name           = var.policy_name
  description    = "Policy for GitHub Actions OIDC access"
  statements     = local.effective_policy_statements
}

// Optional: create an OCI OIDC identity provider for GitHub Actions.
// This creates the provider on the OCI side; you must still configure
// the GitHub side to trust the provider and issue tokens.
resource "oci_identity_identity_provider" "oidc" {
  count          = var.create_provider ? 1 : 0
  compartment_id = local.policy_compartment
  name           = var.provider_name
  description    = var.provider_description
  product_type   = "IDCS"

  # OIDC-specific settings
  protocol     = "SAML2"
  metadata_url = var.provider_issuer
  metadata     = ""
}

// Helpful outputs to wire into other modules / documentation
output "group_id" {
  value       = length(oci_identity_group.group) > 0 ? oci_identity_group.group[0].id : ""
  description = "OCID of created OCI Group (if created)"
}

output "dynamic_group_id" {
  value       = length(oci_identity_dynamic_group.dynamic_group) > 0 ? oci_identity_dynamic_group.dynamic_group[0].id : ""
  description = "OCID of created OCI Dynamic Group (if created)"
}

output "policy_id" {
  value       = length(oci_identity_policy.policy) > 0 ? oci_identity_policy.policy[0].id : ""
  description = "OCID of created OCI Policy (if created)"
}

output "policy_compartment" {
  value       = local.policy_compartment
  description = "Compartment OCID where policies/dynamic groups were created (or should be created)"
}

output "identity_provider_id" {
  value       = length(oci_identity_identity_provider.oidc) > 0 ? oci_identity_identity_provider.oidc[0].id : ""
  description = "OCID of the created OCI identity provider (if created)"
}

output "identity_provider_name" {
  value       = length(oci_identity_identity_provider.oidc) > 0 ? oci_identity_identity_provider.oidc[0].name : ""
  description = "Name of the created OCI identity provider (if created)"
}

