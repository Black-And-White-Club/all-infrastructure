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
