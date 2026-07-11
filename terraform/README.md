# Terraform

Single root configuration provisioning the OCI resources behind the self-managed
Kubernetes cluster: VCN + two ARM A1.Flex instances (`modules/compute`), bastion,
optional block storage, object-storage buckets (mimir/loki/tempo/backups),
OCIR container repositories, the resume ingress load balancer, IAM service
users, and CSI instance principals.

Structure

- `main.tf` / `frolf_pwa_registry.tf` — root config (remote S3-compatible OCI Object Storage backend with lockfile locking)
- `modules/` — reusable OCI modules: compute, bastion, block-storage, object-storage, container-registry, load-balancer, identity-users, csi-instance-principals
- `terraform.tfvars` — gitignored; holds real OCIDs/CIDRs (never commit)

Notes

- Run `terraform fmt && terraform validate && tflint` before commit; `terraform plan` before any apply.
- Renaming the identity-users account names recreates the OCI users and invalidates their auth tokens (OCIR pull secrets, image updater) — only do so in a planned rotation window.

## Control-plane public IP note

This Terraform configuration contains a toggle `assign_reserved_ips` that controls which VMs get a reserved public IP assigned. To keep the Kubernetes API endpoint stable across `terraform apply`, set the control-plane slot to `true` so the control-plane VM receives a reserved IP and does not change unexpectedly:

    `assign_reserved_ips = [true, true]`  # reserve public IP for both control-plane and worker (or choose [true,false] to reserve only control-plane)

Also ensure `allowed_k8s_api_cidrs` includes your current public CIDR so you can reach the API endpoint from your workstation.

After changing the value, run `terraform init` if required, `terraform plan` and `terraform apply`.
