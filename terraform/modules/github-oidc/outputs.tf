output "matching_rule_example" {
  description = "Suggested dynamic group matching rule (example only); review and adapt before enabling `create_dynamic_group`."
  value       = var.dynamic_group_matching_rule != "" ? var.dynamic_group_matching_rule : "// Example (illustrative): request.principal.issuer = 'https://token.actions.githubusercontent.com' AND request.principal.claims['repository'] = 'owner/repo'"
}

output "sample_policy_statements" {
  description = "Sample policy statements to use when enabling `create_policy` (adjust for least privilege)."
  value = [
    "// Allow GitHub actions dynamic group to push/pull images (OCIR) in compartment",
    "Allow dynamic-group ${var.dynamic_group_name} to manage artifacts-repository in compartment ${local.policy_compartment}",
    "// Allow GitHub actions dynamic group to read from Object Storage (if needed)",
    "Allow dynamic-group ${var.dynamic_group_name} to read object-family in compartment ${local.policy_compartment}"
  ]
}
