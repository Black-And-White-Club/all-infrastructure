# SealedSecrets — Generator Scripts and Templates

This directory contains generator scripts and templates for producing SealedSecret
manifests. **Sealed secret payloads are stored in the private repo
`all-infrastructure-secrets`, encrypted with SOPS+age.** Do NOT commit sealed or
plaintext secret YAMLs to this public repo.

## Secret Rotation Workflow

After running any generator script, use the following workflow to update the private repo:

```bash
# 1. Run the generator, writing output directly into the private repo
SECRETS_REPO_DIR=/path/to/all-infrastructure-secrets ./generate-<name>.sh

# 2. Encrypt the new file in-place with SOPS+age
sops --encrypt --in-place "${SECRETS_REPO_DIR}/sealed-<name>.sops.yaml"

# 3. Commit to the private repo
cd "${SECRETS_REPO_DIR}" && git add sealed-<name>.sops.yaml && git commit -m "rotate: <secret-name>"
```

ArgoCD will pick up the change via KSOPS and apply the updated SealedSecret to the cluster.

## Generating OCIR pull secrets for the frolf workloads

Use the `generate-ocir-sealed-secret.sh` helper to produce sealed secrets for
`ocir-secret` without hardcoding credentials directly in the repository.

```bash
export OCIR_USERNAME="<ocir username>"
export OCIR_AUTH_TOKEN="<auth token>"
SECRETS_REPO_DIR=/path/to/all-infrastructure-secrets

# Build sealed secrets for the namespaces that need the pull secret.
SECRETS_REPO_DIR="$SECRETS_REPO_DIR" ./generate-ocir-sealed-secret.sh --namespace resume-app
SECRETS_REPO_DIR="$SECRETS_REPO_DIR" ./generate-ocir-sealed-secret.sh --namespace argocd

# Encrypt and commit
sops --encrypt --in-place "${SECRETS_REPO_DIR}/ocir-secret-resume-app-sealed.sops.yaml"
sops --encrypt --in-place "${SECRETS_REPO_DIR}/ocir-secret-argocd-sealed.sops.yaml"
cd "$SECRETS_REPO_DIR" && git add . && git commit -m "rotate: ocir-secret"
```

## OCI object storage credentials

```bash
SECRETS_REPO_DIR=/path/to/all-infrastructure-secrets
kubectl --kubeconfig ~/.kube/config-oci -n kube-system create secret generic oci-objectstore-creds \
  --from-literal=tenancy="$OCI_TENANCY" \
  --from-literal=user="$OCI_USER" \
  --from-literal=fingerprint="$OCI_FINGERPRINT" \
  --from-file=privateKey="$OCI_KEY_PATH" \
  --from-literal=region="$OCI_REGION" \
  --from-literal=compartmentId="$OCI_COMPARTMENT" \
  --from-literal=namespace="$OCI_NAMESPACE" \
  --dry-run=client -o yaml \
| kubeseal --format=yaml > "${SECRETS_REPO_DIR}/sealed-oci-object-storage-creds.sops.yaml"

sops --encrypt --in-place "${SECRETS_REPO_DIR}/sealed-oci-object-storage-creds.sops.yaml"
cd "$SECRETS_REPO_DIR" && git add . && git commit -m "rotate: oci-objectstore-creds"
```

## Stripe cutover — sealing the Stripe collection rail keys {#stripe-cutover}

The Stripe collection rail ships with `STRIPE_ENABLED=false` in
`kustomize/frolf-backend/base/runtime/deployment.yaml`. The three sealed keys
(`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_APPLICATION_FEE_CENTS`)
are referenced as `optional: true` so pods schedule before the seal step.

### Step 1: Seal the three keys (patch workflow — no full regen required)

```bash
cd /path/to/all-infrastructure-secrets

# Decrypt the current sealed file so yq can splice in the new keys
sops --decrypt --in-place sealed-backend-secrets.sops.yaml

STRIPE_SECRET_KEY="sk_live_..." \
STRIPE_WEBHOOK_SECRET="whsec_..." \
STRIPE_APPLICATION_FEE_CENTS="50" \
/path/to/all-infrastructure/cluster-resources/sealed-secrets/patch-frolf-backend-secrets.sh \
  sealed-backend-secrets.sops.yaml

# Re-encrypt and commit
sops --encrypt --in-place sealed-backend-secrets.sops.yaml
git add sealed-backend-secrets.sops.yaml
git commit -m "feat(payments): seal Stripe collection rail credentials"
```

> **Note**: The NetworkPolicy (TCP/443 egress) and webhook ingress are safe to
> land in Git and sync via ArgoCD **before** this sealing step — they are
> non-breaking additions. Only the `STRIPE_ENABLED` flip (Step 2) activates
> live traffic.

### Step 2: Flip STRIPE_ENABLED to "true"

In `all-infrastructure` (`kustomize/frolf-backend/base/runtime/deployment.yaml`),
change:

```yaml
- name: STRIPE_ENABLED
  value: "false"
```

to:

```yaml
- name: STRIPE_ENABLED
  value: "true"
```

Commit and push to the GitOps branch. ArgoCD will sync the Deployment, and the
backend will start the Stripe module on next pod startup.

### Alternative: full regen

If you need to regenerate **all** backend secrets at once (e.g. key rotation),
`generate-frolf-backend-secrets.sh` now requires the three Stripe vars too:

```bash
STRIPE_SECRET_KEY=sk_live_... \
STRIPE_WEBHOOK_SECRET=whsec_... \
STRIPE_APPLICATION_FEE_CENTS=50 \
<all other existing vars> \
SECRETS_REPO_DIR=/path/to/all-infrastructure-secrets \
./generate-frolf-backend-secrets.sh
```

## DB credentials for resume-backend

Use `generate-sealed-secrets.sh` to generate both `resume-db` and `resume-app` SealedSecrets:

```bash
SECRETS_REPO_DIR=/path/to/all-infrastructure-secrets
./generate-sealed-secrets.sh "$SECRETS_REPO_DIR"

# Encrypt each output file
for f in "${SECRETS_REPO_DIR}"/sealed-resume-backend-postgresql*.yaml; do
  mv "$f" "${f%.yaml}.sops.yaml"
  sops --encrypt --in-place "${f%.yaml}.sops.yaml"
done
cd "$SECRETS_REPO_DIR" && git add . && git commit -m "rotate: resume-backend-postgresql"
```
