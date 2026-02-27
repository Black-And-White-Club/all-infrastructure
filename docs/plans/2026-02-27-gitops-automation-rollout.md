# GitOps Automation Safe Rollout Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Safely push all GitOps automation changes (CI, Renovate, Argo Rollouts) to a live production cluster without disrupting running applications.

**Architecture:** Three sequential PRs gate the rollout. Each PR is independently safe to merge. Manual infrastructure steps gate PR 2. Renovate is not installed until CI is verified working.

**Tech Stack:** ArgoCD, GitHub Actions, Terraform (OCI), Renovate, Argo Rollouts, Helm, Kustomize

---

## Overview: Three PRs + Manual Steps Between Them

```
PR 1 (ArgoCD changes)
  → Merge → verify Argo Rollouts deploys
    → Manual: fill in terraform/main.tf, run state migration, add GitHub secrets, create production env
      → PR 2 (CI workflows + Renovate config)
        → Merge → verify CI passes
          → Manual: install Renovate app, validate on test branch
            → PR 3 (resume-frontend → Rollout) [separate, future]
```

---

## PR 1: ArgoCD Platform Changes

**What's in it:** argo-rollouts ArgoCD app, platform-project destination, kustomization update, .gitignore fix, .pem deletion, delete broken validate-infra-charts.yaml.

**Why it's safe:** Purely additive. Argo Rollouts is a new namespace and controller — it doesn't touch existing apps. All auto-syncing apps are unaffected.

---

### Task 1: Fix heredoc indentation in terraform-plan.yml

**Files:**
- Modify: `.github/workflows/terraform-plan.yml:55-62`

The `<<-EOF` strips leading *tabs only*. Currently lines have `spaces + tab`, so 10 spaces remain in the config file. Fix by switching to flush-left `<<'EOF'` (GitHub Actions evaluates `${{ }}` before shell, so quoting the delimiter is fine and prevents any shell variable confusion).

**Step 1: Edit the OCI credentials step in terraform-plan.yml**

Replace the heredoc block at lines 55-62:

```yaml
      - name: Configure OCI credentials
        run: |
          mkdir -p ~/.oci
          echo "${{ secrets.OCI_PRIVATE_KEY }}" > ~/.oci/private_key.pem
          chmod 600 ~/.oci/private_key.pem
          cat > ~/.oci/config <<'EOF'
[DEFAULT]
user=${{ secrets.OCI_USER_OCID }}
fingerprint=${{ secrets.OCI_FINGERPRINT }}
key_file=~/.oci/private_key.pem
tenancy=${{ secrets.OCI_TENANCY_OCID }}
region=${{ secrets.OCI_REGION }}
EOF
```

**Step 2: Verify the heredoc content is flush-left**

```bash
grep -n "DEFAULT\|user=\|fingerprint\|key_file\|tenancy\|region" .github/workflows/terraform-plan.yml
```

Expected: lines like `[DEFAULT]`, `user=${{...}}` with no leading whitespace.

---

### Task 2: Fix heredoc indentation in terraform-apply.yml

**Files:**
- Modify: `.github/workflows/terraform-apply.yml:59-66`

Same problem, same fix.

**Step 1: Edit the OCI credentials step in terraform-apply.yml**

Replace the heredoc block at lines 59-66 with the identical fix:

```yaml
      - name: Configure OCI credentials
        run: |
          mkdir -p ~/.oci
          echo "${{ secrets.OCI_PRIVATE_KEY }}" > ~/.oci/private_key.pem
          chmod 600 ~/.oci/private_key.pem
          cat > ~/.oci/config <<'EOF'
[DEFAULT]
user=${{ secrets.OCI_USER_OCID }}
fingerprint=${{ secrets.OCI_FINGERPRINT }}
key_file=~/.oci/private_key.pem
tenancy=${{ secrets.OCI_TENANCY_OCID }}
region=${{ secrets.OCI_REGION }}
EOF
```

**Step 2: Verify**

```bash
grep -n "DEFAULT\|user=\|fingerprint\|key_file\|tenancy\|region" .github/workflows/terraform-apply.yml
```

Expected: flush-left lines, no leading whitespace.

---

### Task 3: Add Renovate automerge exclusions for critical packages

**Files:**
- Modify: `renovate.json`

The current config automerges all Helm patches. Four packages must never automerge because a bad patch can cascade to a full cluster outage:
- `argo-cd` — updates ArgoCD itself; a bad chart leaves you unable to recover via GitOps
- `sealed-secrets-controller` — if this pod crashes mid-upgrade, all secrets become unreadable and every dependent app fails to start
- `nginx-ingress` — traffic routing changes immediately; all apps lose ingress
- `postgresql` — Helm upgrade can require PVC recreation; data loss possible

**Step 1: Add a safety-override rule as the FIRST entry in packageRules**

The rule must be first because Renovate applies rules in order and last-match wins for most settings — but `automerge: false` acts as an override block when placed before the general patch rule. Actually in Renovate, rules are merged additively and later rules win for conflicting settings. So place this rule AFTER the general patch automerge rule but target specific packages to override it.

Add this rule after the existing `matchUpdateTypes: ["patch"]` automerge rule:

```json
{
  "matchPackagePatterns": [
    "^argo-cd$",
    "^sealed-secrets$",
    "^postgresql$",
    "^ingress-nginx$"
  ],
  "matchDatasources": ["helm"],
  "automerge": false,
  "labels": ["requires-manual-review"],
  "additionalBranchPrefix": "renovate/"
},
```

**Step 2: Verify the JSON is valid**

```bash
cat renovate.json | python3 -m json.tool > /dev/null && echo "valid JSON"
```

Expected: `valid JSON`

---

### Task 4: Stage all PR 1 files and commit

**Step 1: Check what's staged/unstaged**

```bash
git status
```

**Step 2: Stage all PR 1 files**

```bash
git add \
  .gitignore \
  terraform/cert.pem \
  terraform/key.pem \
  argocd/platform/kustomization.yaml \
  argocd/platform/argo-rollouts.yaml \
  argocd/projects/platform-project.yaml \
  charts/argo-rollouts/ \
  .github/workflows/terraform-plan.yml \
  .github/workflows/terraform-apply.yml \
  renovate.json \
  .github/workflows/ci-validate.yml \
  .kube-linter.yaml \
  docs/ci-prerequisites.md
```

> **Note:** Do NOT stage `terraform/main.tf` yet — it still has `<NAMESPACE>` and `<REGION>` placeholders. It goes in a later commit after you fill in real values.

Also stage the deletion of the broken workflow:

```bash
git rm .github/workflows/validate-infra-charts.yaml
```

**Step 3: Commit**

```bash
git commit -m "feat: add GitOps automation (CI, Renovate, Argo Rollouts)

- CI: three parallel lint jobs (terraform/helm/kustomize) on PR
- Renovate: helm patch automerge with critical package exclusions
- Argo Rollouts: controller app, values, platform-project destination
- Remove broken validate-infra-charts.yaml workflow
- Fix OCI config heredoc (flush-left, not tab-indented)
- Remove cert.pem/key.pem from git tracking"
```

**Step 4: Push and open PR**

```bash
git push -u origin HEAD
gh pr create \
  --title "feat: GitOps automation — CI, Renovate, Argo Rollouts" \
  --body "$(cat <<'EOF'
## What

Implements phases 1-4 of the GitOps automation plan.

## Changes

- **CI** (`ci-validate.yml`): three parallel lint jobs on every PR — terraform (tflint + tfsec), helm (helm lint + kubeconform), kustomize (kustomize build + kube-linter)
- **Renovate** (`renovate.json`): tracks 15 Helm charts + TF providers; patch automerge for non-critical packages; argo-cd, sealed-secrets, postgresql, nginx-ingress require manual review
- **Argo Rollouts**: controller ArgoCD app + values; platform-project updated with argo-rollouts namespace destination
- **Cleanup**: removes broken `validate-infra-charts.yaml`; removes cert.pem/key.pem from tracking

## Safety

This PR does NOT include Terraform workflow changes (those require GitHub secrets to be set up first — see docs/ci-prerequisites.md).

Renovate is NOT yet installed — the renovate.json is inert until the GitHub App is enabled.

## Manual steps required before merging PR 2

See `docs/ci-prerequisites.md` for full runbook.

## Verification after merge

- ArgoCD should auto-sync and deploy Argo Rollouts controller
- Verify: `kubectl -n argo-rollouts get deploy`
EOF
)"
```

**Step 5: Review CI results on the PR**

The `ci-validate.yml` workflow will run. Check that:
- `terraform-lint` passes
- `helm-lint` passes
- `kustomize-lint` passes

Fix any failures before merging.

**Step 6: Merge PR 1**

```bash
gh pr merge --squash
```

---

### Task 5: Verify Argo Rollouts deployed after merge

ArgoCD watches `main`. After the merge ArgoCD will detect the new `argo-rollouts.yaml` in the platform kustomization and sync it.

**Step 1: Watch for ArgoCD sync (allow 2-3 minutes)**

```bash
kubectl -n argocd get app argo-rollouts -w
```

Expected: `STATUS: Synced`, `HEALTH: Healthy`

**Step 2: Verify controller is running**

```bash
kubectl -n argo-rollouts get deploy
```

Expected: `argo-rollouts` deployment with `READY 1/1` (or 2/2 if HA).

If the app shows `OutOfSync` or `Degraded`, check:
```bash
kubectl -n argocd get app argo-rollouts -o yaml | grep -A 20 "conditions:"
```

---

## Manual Steps: Pre-CI Setup (between PR 1 and PR 2)

These must be done locally before PR 2 is merged. None of them affect running apps. Full details in `docs/ci-prerequisites.md`.

---

### Task 6: Fill in terraform/main.tf backend placeholders

**Files:**
- Modify: `terraform/main.tf` lines 5-6

Replace `<NAMESPACE>` and `<REGION>` with your actual OCI tenancy namespace and region.

Your OCI namespace is visible in the OCI console under Tenancy Details, or:
```bash
oci os ns get
```

**Step 1: Edit main.tf**

```hcl
endpoint = "https://<your-actual-namespace>.compat.objectstorage.<your-actual-region>.oraclecloud.com"
```

Example:
```hcl
endpoint = "https://axyz1234abcd.compat.objectstorage.us-ashburn-1.oraclecloud.com"
```

---

### Task 7: Create the OCI Object Storage bucket for Terraform state

In the OCI console (or CLI):

```bash
oci os bucket create \
  --namespace <your-namespace> \
  --compartment-id <your-compartment-ocid> \
  --name terraform-state
```

Versioning is not available for S3-compatible buckets on OCI, but the bucket must exist before `terraform init`.

---

### Task 8: Back up local Terraform state and run migration

**Step 1: Back up the local state**

```bash
cp terraform/terraform.tfstate terraform/terraform.tfstate.local-backup-$(date +%Y%m%d)
```

Keep this backup until you verify the remote state is intact.

**Step 2: Create a Customer Secret Key in OCI for S3-compatible access**

In OCI console: Identity → Users → your user → Customer Secret Keys → Generate Secret Key.

Save the access key and secret key — you'll need them for GitHub Secrets and for the migration.

**Step 3: Run the state migration**

```bash
cd terraform/
terraform init \
  -migrate-state \
  -backend-config="access_key=<your-access-key>" \
  -backend-config="secret_key=<your-secret-key>"
```

Expected output: `Successfully configured the backend "s3"! Terraform will automatically use this backend unless the backend configuration changes.`

**Step 4: Verify state is in the remote bucket**

```bash
oci os object list --namespace <your-namespace> --bucket-name terraform-state
```

Expected: `all-infrastructure/terraform.tfstate` listed.

**Step 5: Verify terraform plan still works against remote state**

```bash
terraform plan \
  -backend-config="access_key=<your-access-key>" \
  -backend-config="secret_key=<your-secret-key>"
```

Expected: `No changes. Your infrastructure matches the configuration.` (or a known diff if you made any changes).

---

### Task 9: Add GitHub Secrets

In GitHub: repo → Settings → Secrets and variables → Actions → New repository secret.

**OCI Auth secrets:**
| Secret name | Value |
|-------------|-------|
| `OCI_TENANCY_OCID` | Your tenancy OCID |
| `OCI_USER_OCID` | Your user OCID |
| `OCI_FINGERPRINT` | API key fingerprint |
| `OCI_PRIVATE_KEY` | Full PEM content of your private key |
| `OCI_REGION` | e.g. `us-ashburn-1` |
| `OCI_S3_ACCESS_KEY` | Customer Secret Key access key (from Task 8) |
| `OCI_S3_SECRET_KEY` | Customer Secret Key secret (from Task 8) |

**Terraform variable secrets** (values from your local `terraform.tfvars`):
| Secret name | Matches `TF_VAR_*` env in workflow |
|-------------|-------------------------------------|
| `TF_VAR_COMPARTMENT_OCID` | |
| `TF_VAR_RESUME_COMPARTMENT_OCID` | |
| `TF_VAR_FROLF_BOT_COMPARTMENT_OCID` | |
| `TF_VAR_RESUME_BUCKET_OCID` | |
| `TF_VAR_FROLF_BOT_BUCKET_OCID` | |
| `TF_VAR_RESUME_REPO_OCID` | |
| `TF_VAR_FROLF_BOT_REPO_OCID` | |
| `TF_VAR_NAMESPACE` | Your OCI tenancy namespace |
| `TF_VAR_AVAILABILITY_DOMAIN` | |
| `TF_VAR_IMAGE_ID` | |
| `TF_VAR_SSH_PUBLIC_KEY` | |
| `TF_VAR_ADMIN_GROUP_OCID` | |
| `TF_VAR_USER_EMAIL_PREFIX` | |

---

### Task 10: Create the `production` GitHub environment

In GitHub: repo → Settings → Environments → New environment → name: `production`.

Add yourself as a required reviewer. This is the approval gate for `terraform-apply.yml` — without it, the apply runs automatically on every merge touching `terraform/`.

---

## PR 2: Terraform Workflows + Updated main.tf

**What's in it:** The updated `terraform/main.tf` with real endpoint values, plus all the workflow files that were withheld from PR 1.

Wait — all the workflow files were already committed in PR 1 above. The only thing left is `terraform/main.tf` with the real endpoint values.

---

### Task 11: Commit terraform/main.tf with real values

**Step 1: Stage and commit**

```bash
git add terraform/main.tf
git commit -m "feat: configure terraform remote state backend (OCI S3)"
git push
```

**Step 2: Open a PR to validate the terraform-plan workflow fires**

```bash
gh pr create \
  --title "feat: configure terraform remote state backend" \
  --body "Connects terraform to the OCI Object Storage S3-compatible backend. State migration was run locally in Task 8. This PR validates the terraform-plan CI job."
```

**Step 3: Verify the terraform-plan workflow runs on the PR**

In GitHub Actions, the `Terraform Plan` workflow should trigger. Check that:
- OCI credentials step succeeds (no parsing error in `~/.oci/config`)
- `terraform init` succeeds (connects to remote backend)
- `terraform plan` posts a comment on the PR showing "No changes"

If plan shows unexpected changes, do NOT merge — investigate before proceeding.

**Step 4: Merge**

```bash
gh pr merge --squash
```

After merge, the `Terraform Apply` workflow will trigger and wait for your approval in the `production` environment. Since it's a no-op plan, approve it to verify the full apply pipeline works end-to-end.

---

## Enable Renovate

Only do this after PR 2 is merged and you've verified CI works.

---

### Task 12: Install Renovate and validate on a test branch

**Step 1: Install the Renovate GitHub App**

Go to: https://github.com/apps/renovate → Install → select your repo.

**Step 2: Trigger a Renovate dry run on a test branch**

Create a scratch branch and push it — Renovate will scan and create a `renovate/configure` or dependency PRs.

```bash
git checkout -b test/renovate-validation
git commit --allow-empty -m "chore: trigger renovate scan"
git push -u origin HEAD
```

**Step 3: Verify Renovate behavior**

Check the PRs Renovate opens:
- [ ] `targetRevision: main` entries are NOT touched (they're not semver)
- [ ] Patch updates for `argo-cd`, `sealed-secrets`, `postgresql`, `nginx-ingress` do NOT have automerge enabled (check PR description for "automerge" label — should show `requires-manual-review`)
- [ ] Patch updates for other packages DO have automerge enabled
- [ ] `grafana-stack` group creates a single PR for all grafana-stack charts

**Step 4: Clean up**

```bash
git checkout main
git branch -d test/renovate-validation
git push origin --delete test/renovate-validation
```

---

## Phase 4 Follow-up: Convert resume-frontend to Rollout

This is a separate future PR. Do not do this until:
- Argo Rollouts controller is verified running (Task 5)
- You understand that converting a `Deployment` to a `Rollout` is a breaking change (the Deployment must be deleted first — Argo Rollouts does not adopt existing Deployments)

When ready, open a dedicated PR that:
1. Adds a `Rollout` manifest for `resume-frontend` in `cluster-resources/` or equivalent
2. Removes the existing `Deployment`
3. Adds a `Service` targeting the rollout pods (if not already canary-aware)

---

## Final Verification Checklist

After all PRs are merged and Renovate is active:

| Item | Command | Expected |
|------|---------|----------|
| Argo Rollouts running | `kubectl -n argo-rollouts get deploy` | `READY 1/1` |
| Terraform state remote | `oci os object list --bucket-name terraform-state` | state file listed |
| CI passes on PR | Open any test PR | all 3 jobs green |
| Terraform plan posts comment | PR touching `terraform/` | "No changes" comment |
| Renovate active | Check GitHub PRs | Renovate PRs visible |
| Critical packages not automerging | Check argo-cd PR labels | `requires-manual-review` |
