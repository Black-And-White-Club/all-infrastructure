# Terraform

This folder holds shared Terraform modules and environment configs used to provision cloud resources that the clusters and platform components need (compute, networks, IAM/service-accounts, load-balancers, etc.).

Structure

- `modules/` — reusable modules (cloud-engine, service-account, load-balancer)
- `environments/` — example tfvars per environment (dev/stage/prod)

Notes

- The modules are intentionally generic placeholders — implement them for OCI (or your cloud provider) and add provider and backend configs in the environment folders.
