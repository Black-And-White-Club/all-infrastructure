# SealedSecret management for infra-managed DBs

This directory contains sealed secret templates for infra-managed DBs. The files are templates — they must contain `kubeseal`-generated encrypted data before being applied.

Workflow (infra-centric):

1. Create the initial secret in the `resume-db` namespace locally:

```bash
export PG_PASSWORD=$(openssl rand -hex 16)
kubectl -n resume-db create secret generic resume-backend-postgresql \
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
