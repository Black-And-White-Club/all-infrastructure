# CI Prerequisites — Manual Setup

This file documents the one-time manual steps required before the Terraform CI workflows (`.github/workflows/terraform-plan.yml` and `terraform-apply.yml`) can function.

---

## Step 1 — Migrate Terraform State to Remote Backend

OCI Object Storage supports an S3-compatible backend. Perform this locally.

### 1a. Add backend block to `terraform/main.tf`

```hcl
terraform {
  backend "s3" {
    bucket   = "terraform-state"          # OCI bucket name
    key      = "all-infrastructure/terraform.tfstate"
    region   = "us-ashburn-1"             # your OCI region
    endpoint = "https://<NAMESPACE>.compat.objectstorage.<REGION>.oraclecloud.com"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    use_path_style              = true
  }
}
```

### 1b. Create a Customer Secret Key (S3 credentials) in the OCI Console

OCI Console → Identity → Users → your user → Customer Secret Keys → Generate Secret Key.
Save the **Access Key** and **Secret Key** — you will use them in Step 2 and for local `terraform init`.

### 1c. Migrate state

```bash
cd terraform
terraform init \
  -migrate-state \
  -backend-config="access_key=<ACCESS_KEY>" \
  -backend-config="secret_key=<SECRET_KEY>"
```

> **Note:** OCI Object Storage does not support state locking. Do not run concurrent applies.

---

## Step 2 — GitHub Repository Secrets

Go to repo **Settings → Secrets and variables → Actions → New repository secret** for each:

### OCI Auth (required for all Terraform operations)
| Secret Name | Value |
|-------------|-------|
| `OCI_TENANCY_OCID` | Tenancy OCID from OCI Console |
| `OCI_USER_OCID` | User OCID from OCI Console |
| `OCI_FINGERPRINT` | API key fingerprint |
| `OCI_PRIVATE_KEY` | Full contents of your OCI API private key PEM file |
| `OCI_REGION` | e.g. `us-ashburn-1` |
| `OCI_S3_ACCESS_KEY` | Customer Secret Key access key (from Step 1b) |
| `OCI_S3_SECRET_KEY` | Customer Secret Key secret (from Step 1b) |

### Non-Auth Terraform Variables (from terraform.tfvars)
| Secret Name | Terraform Variable |
|-------------|-------------------|
| `TF_VAR_COMPARTMENT_OCID` | `compartment_ocid` |
| `TF_VAR_RESUME_COMPARTMENT_OCID` | `resume_compartment_ocid` |
| `TF_VAR_FROLF_BOT_COMPARTMENT_OCID` | `frolf_bot_compartment_ocid` |
| `TF_VAR_RESUME_BUCKET_OCID` | `resume_bucket_ocid` |
| `TF_VAR_FROLF_BOT_BUCKET_OCID` | `frolf_bot_bucket_ocid` |
| `TF_VAR_RESUME_REPO_OCID` | `resume_repo_ocid` |
| `TF_VAR_FROLF_BOT_REPO_OCID` | `frolf_bot_repo_ocid` |
| `TF_VAR_NAMESPACE` | `namespace` |
| `TF_VAR_AVAILABILITY_DOMAIN` | `availability_domain` |
| `TF_VAR_IMAGE_ID` | `image_id` |
| `TF_VAR_SSH_PUBLIC_KEY` | `ssh_public_key` |
| `TF_VAR_ADMIN_GROUP_OCID` | `admin_group_ocid` |
| `TF_VAR_USER_EMAIL_PREFIX` | `user_email_prefix` |

---

## Step 3 — GitHub Environment (Apply Gate)

1. Go to repo **Settings → Environments → New environment**
2. Name it `production`
3. Under **Required reviewers**, add yourself (and any other approvers)
4. Enable **Prevent self-review** if desired

This ensures that `terraform apply` cannot run until a human clicks "Approve" in the GitHub Actions UI after a PR is merged to `main`.

---

## Step 4 — Enable Renovate

1. Install the [Renovate GitHub App](https://github.com/apps/renovate) on the `Black-And-White-Club` org or the `all-infrastructure` repo specifically.
2. Renovate will open an onboarding PR. Merge it.
3. Before enabling `automerge: true` for patches, **validate on a test branch** that Renovate correctly identifies `targetRevision: 9.1.4` as the chart version and ignores `targetRevision: main` in multi-source ArgoCD app YAML files.

---

## Step 5 — Audit Bitnami Registry

Verify the legacy Bitnami chart URL still resolves (force a fresh fetch):

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami \
  && helm repo update \
  && helm search repo bitnami/postgresql --versions | head -5
```

If it returns an error or no results, update `argocd/apps/frolf-postgres.yaml` and `argocd/apps/resume-postgres.yaml`:
```yaml
# Change:
repoURL: https://charts.bitnami.com/bitnami
# To:
repoURL: oci://registry-1.docker.io/bitnamicharts
```
