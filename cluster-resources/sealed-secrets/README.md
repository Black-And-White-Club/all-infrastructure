# SealedSecrets for OCI Credentials

This directory should contain SealedSecrets for any OCI credentials used by
in-cluster services (OCI CSI driver, object storage uploads, etc.). Do NOT
commit unsealed (plaintext) secrets to Git.

To create a SealedSecret for object storage uploads (used by backups or other jobs/controllers):

1. Create a local Kubernetes Secret (dry-run) with your values:

```bash
kubectl --kubeconfig ~/.kube/config-oci -n kube-system create secret generic oci-objectstore-creds \
  --from-literal=tenancy="$OCI_TENANCY" \
  --from-literal=user="$OCI_USER" \
  --from-literal=fingerprint="$OCI_FINGERPRINT" \
  --from-file=privateKey="$OCI_KEY_PATH" \
  --from-literal=region="$OCI_REGION" \
  --from-literal=compartmentId="$OCI_COMPARTMENT" \
  --from-literal=namespace="$OCI_NAMESPACE" \
  --dry-run=client -o yaml > /tmp/oci-objectstore-creds.yaml
```

2. Seal the secret (use the kubeconfig to target your cluster):

```bash
kubeseal --kubeconfig ~/.kube/config-oci --controller-name sealed-secrets \
  --controller-namespace kube-system -o yaml < /tmp/oci-objectstore-creds.yaml \
  > all-infrastructure/cluster-resources/sealed-secrets/oci-objectstore-creds-sealed.yaml
```

3. Commit the sealed secret file to Git and push. ArgoCD will apply it and the
   sealed-secrets controller will create the real secret in the cluster.

Important: Jobs or controllers that upload to object storage expect the secret named
`oci-objectstore-creds` in the `kube-system` namespace and the Postgres password
to be present in `resume-backend-postgresql` secret in the `resume-db` namespace.

# SealedSecret management for infra-managed DBs

This directory contains sealed secret templates for infra-managed DBs. The files are templates — they must contain `kubeseal`-generated encrypted data before being applied.

Workflow (infra-centric):

1. Create the initial secret in the `resume-db` namespace locally:

```bash
export PG_PASSWORD=$(openssl rand -hex 16)
kubectl --kubeconfig ~/.kube/config-oci -n resume-db create secret generic resume-backend-postgresql \
  --from-literal=postgresql-password="${PG_PASSWORD}" \
  --from-literal=postgresql-username="resume_user" \
  --from-literal=postgresql-database="resume_db" \
  --dry-run=client -o yaml > resume-backend-postgresql-secret.yaml
```

2. Seal it and produce the sealed secret for the `resume-db` namespace (run this locally):

```bash
kubeseal --format=yaml < resume-backend-postgresql-secret.yaml > sealed-resume-backend-postgresql.yaml
```

3. If the app needs a secret in the app namespace as well, you can create it using this script (`generate-sealed-secrets.sh`) which will create both `resume-db` and `resume-app` sealed secrets.

4. ArgoCD will pick up the sealed secret YAML and apply the required Kubernetes secrets at deployment time.
5. To generate the secrets locally, run:

```bash
./all-infrastructure/cluster-resources/sealed-secrets/generate-sealed-secrets.sh ./tmp
```

That script will generate a secure password, write raw secret YAMLs to `./tmp`, and then convert them into SealedSecret YAMLs using `kubeseal` (if available). Commit only the `sealed-` YAMLs into `all-infrastructure/cluster-resources/sealed-secrets/`.
