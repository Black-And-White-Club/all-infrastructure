# github-oidc

## Purpose

This module centralizes OCI-side identity resources that are required to accept
GitHub Actions OIDC tokens: optional OCI Identity Group, optional OCI Dynamic
Group, and optional OCI Policy resources. All resources are opt-in (disabled
by default) so you can enable them as part of a controlled migration.

## How it works

- `create_group` creates a normal OCI `Group` that you can use for manual
  assignments or policies.
- `create_dynamic_group` creates an OCI `Dynamic Group`. You must supply a
  valid `dynamic_group_matching_rule` when enabling this feature. The module
  does not invent matching rules — dynamic group rules are sensitive and must
  be tailored to your security posture and GitHub repository patterns.
- `create_policy` writes an OCI `Policy` resource with the statements you
  supply in `policy_statements`. The module does not set default statements
  to avoid accidental over‑permissioning.

## Recommended steps (provider-side)

1. Decide where policies will live: pass `policy_compartment_id` (or
   `tenancy_ocid`) to the module.
2. If you want OCI to trust GitHub OIDC, create a dynamic group and supply a
   matching rule that targets tokens issued by `https://token.actions.githubusercontent.com` and
   scoped to your repository/org. Example (illustrative only — confirm syntax):

   ```text
   // Example matching rule (illustrative):
   request.principal.issuer = "https://token.actions.githubusercontent.com" AND
   request.principal.claims['repository'] = "my-org/my-repo"
   ```

3. Provide `policy_statements` that grant least-privilege access to the
   dynamic group (for example, allow pushing/pulling from OCIR or using
   object storage). Example statements (illustrative):

   - `Allow dynamic-group github-oidc-dg to manage artifacts-repository in compartment <compartment>`
   - `Allow dynamic-group github-oidc-dg to read object-family in compartment <compartment>`

4. After enabling provider-side resources, create the corresponding GitHub
   OIDC trust (on GitHub side) and test issuing tokens to verify the dynamic
   group matches.

## Provider creation (opt-in)

The module supports creation of the OCI identity provider itself (OIDC
issuer) via `create_provider = true`. Example usage:

```hcl
module "github_oidc" {
  source = "git::ssh://git@github.com/YOUR_ORG/all-infrastructure.git//terraform/modules/github-oidc"

  tenancy_ocid            = var.tenancy_ocid
  policy_compartment_id   = var.policy_compartment_id
  create_provider         = true
  provider_name           = "github-actions-oidc"
  provider_issuer         = "https://token.actions.githubusercontent.com"
  create_dynamic_group    = true
  dynamic_group_matching_rule = "<your matching rule>"
  create_policy           = true
  policy_statements       = ["<your policy statements>"]
}
```

When `create_provider` is enabled the module will create the OCI-side
identity provider resource. You still need to configure the GitHub side to
trust that provider (organization or repo settings); the README contains a
sample matching rule to help you craft the dynamic group rule.

## Next steps (outside the provider)

- Register the OCI OIDC provider settings in GitHub and configure repository
  workflows or organization trust.
- Add the OCI policy statements permanently (or let this module create them).
- Create and verify any secrets (tokens) needed by your CI system; consider
  storing tokens via sealed secrets or a secure secret manager.

## Notes

- The module is intentionally conservative: resources are created only when
  explicitly enabled. This lets you keep the module in your mono repo and
  enable parts incrementally during migration.
