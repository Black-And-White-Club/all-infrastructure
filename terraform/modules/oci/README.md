# OCI modules (skeleton)

This folder contains OCI-targeted Terraform module skeletons. The goal is to implement provider-specific modules here rather than importing GCP-specific modules that were used in the project repos.

Guidance

- Do not copy GCP modules directly into this repo — design OCI equivalents because resource types and APIs differ.
- Suggested modules:
  - `cloud-engine/` — VCN, subnets, internet/nat gateways, route tables, compute instances (control plane/workers/bastion)
  - `service-account/` — OCI service users / dynamic groups / policies used by platform services
  - `load-balancer/` — OCI Load Balancer resources and healthchecks

Provider notes

- Using the OCI provider requires API credentials (tenancy OCID, user OCID, fingerprint, private key file). Keep secrets out of repository and prefer environment variables or CI secret stores.

Conversion tips from GCP

- Think in terms of compartments + dynamic groups instead of IAM projects/service accounts.
- OCI block storage and NVMe shapes are different from GCP PD types — design StorageClass mappings carefully.
- DNS, VCN, and routing differ — review any existing GCP networking assumptions before porting.
