# Terraform

This folder holds shared Terraform modules and environment configs used to provision cloud resources that the clusters and platform components need (compute, networks, IAM/service-accounts, load-balancers, etc.).

Structure

- `modules/` — reusable modules (cloud-engine, service-account, load-balancer)
- `environments/` — example tfvars per environment (dev/stage/prod)

Notes

- The modules are intentionally generic placeholders — implement them for OCI (or your cloud provider) and add provider and backend configs in the environment folders.

## Control-plane public IP note

This Terraform configuration contains a toggle `assign_reserved_ips` that controls which VMs get a reserved public IP assigned. To keep the Kubernetes API endpoint stable across `terraform apply`, set the control-plane slot to `true` so the control-plane VM receives a reserved IP and does not change unexpectedly:

    `assign_reserved_ips = [true, true]`  # reserve public IP for both control-plane and worker (or choose [true,false] to reserve only control-plane)

Also ensure `allowed_k8s_api_cidrs` includes your current public CIDR so you can reach the API endpoint from your workstation.

After changing the value, run `terraform init` if required, `terraform plan` and `terraform apply`.
