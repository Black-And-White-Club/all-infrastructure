# OCI object storage setup (Terraform)

This document describes how to provision object storage buckets in OCI via Terraform and what to do next to provide credentials to your K8s workloads (Mimir/Loki/Tempo)

## Provisioning buckets

1. The Terraform module `terraform/modules/object-storage` will create buckets for you. By default we wire:

   - mimir-shared-bucket
   - loki-shared-bucket
   - tempo-shared-bucket

2. Run Terraform (plan/apply) from `terraform/` to create the buckets. Example:
   ```bash
   cd all-infrastructure/terraform
   terraform init
   terraform plan -var-file=terraform.tfvars
   terraform apply -var-file=terraform.tfvars
   ```

## Credentials for K8s workloads

OCI workloads (pods) need object storage credentials (API keys or pre-auth tokens) to use bucket endpoints. Creating an IAM user & API key is the standard approach:

1. Create a dedicated service user in the OCI console (or via CLI): `observability-service`.
2. Create an API key for that user (the private key is created at your side). You only upload the public key to OCI. Keep the private key safe.
3. Use the API key's access credentials to generate S3 compatible credentials (OCI doesn't provide direct access/secret keys like AWS; instead you use accessKey/secretKey patterns with pre-auth or via IAM).

## Sealing the credentials

1. Create a Kubernetes secret with the credentials in the `observability` namespace (or `argocd` if you prefer). e.g:
   ```bash
   kubectl create secret generic objectstore-creds -n observability --from-literal=access_key="<ACCESS>" --from-literal=secret_key="<SECRET>" --dry-run=client -o yaml > objectstore-creds.yaml
   ```
2. Seal the secret using `kubeseal` (controller running in `kube-system`) and commit the sealed YAML to `all-infrastructure/cluster-resources/sealed-secrets`.
   ```bash
   kubeseal --controller-namespace kube-system --controller-name sealed-secrets -o yaml < objectstore-creds.yaml > sealed-secrets/objectstore-creds-sealed.yaml
   ```

## Values in Helm charts

Update chart values for Mimir/Loki/Tempo to use the S3-compatible backend with endpoint: `objectstorage.us-ashburn-1.oraclecloud.com` and bucket names matching the created buckets. Mount the sealed secret at the chart's expected secret key location.

Notes:

- Terraform will only create the buckets. Creating a service user + API keys is a separate, deliberate step to maintain security (private keys should not be uploaded into Git).
- If you prefer automation for credentials, we can create a new `observability-service` user and provision a key pair via Terraform, but the private key will be generated in the agent that runs Terraform — storing that key securely (or using a vault) is recommended.
