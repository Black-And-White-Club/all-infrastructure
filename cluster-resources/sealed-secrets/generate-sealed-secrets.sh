#!/usr/bin/env bash
set -euo pipefail

# Helper script to generate DB credentials for resume-backend, create Kubernetes Secret YAML,
# and kubeseal it into a SealedSecret to be committed to the infra repository.
#
# Usage:
#   ./generate-sealed-secrets.sh --output-dir ./out
#
# Requirements:
#  - kubectl (for kubectl get secret optional checks)
#  - kubeseal (to create sealed secret YAML)
#  - openssl or head for password generation

WORKDIR="$(pwd)"
OUTPUT_DIR="${1:-./out}"
mkdir -p "$OUTPUT_DIR"

echo "Generating sealed secrets into: $OUTPUT_DIR"

NAMESPACE_DB="resume-db"
NAMESPACE_APP="resume-app"
SECRET_NAME="resume-backend-postgresql"
POSTGRES_USER="resume_user"
POSTGRES_DB="resume_db"

# Generate a new secure password (40 hex chars = 20 bytes)
PG_PASSWORD=$(openssl rand -hex 20)
echo "Generated password (first 6 chars): ${PG_PASSWORD:0:6}..." # avoid printing the full password

# Database host service (helm release: resume-backend-postgresql in resume-db namespace)
PG_HOST="resume-backend-postgresql.${NAMESPACE_DB}.svc.cluster.local"
PG_PORT=5432
DB_URL="postgresql://${POSTGRES_USER}:${PG_PASSWORD}@${PG_HOST}:${PG_PORT}/${POSTGRES_DB}?sslmode=disable"

echo "Building raw secret YAMLs (local only)"

cat > "$OUTPUT_DIR/${SECRET_NAME}.secret.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE_DB}
type: Opaque
stringData:
  postgresql-password: "${PG_PASSWORD}"
  postgresql-username: "${POSTGRES_USER}"
  postgresql-database: "${POSTGRES_DB}"
  DATABASE_URL: "${DB_URL}"
EOF

cat > "$OUTPUT_DIR/${SECRET_NAME}-app.secret.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE_APP}
type: Opaque
stringData:
  postgresql-password: "${PG_PASSWORD}"
  postgresql-username: "${POSTGRES_USER}"
  postgresql-database: "${POSTGRES_DB}"
  DATABASE_URL: "${DB_URL}"
EOF

if ! command -v kubeseal >/dev/null 2>&1; then
  echo "kubeseal not installed; writing plaintext secret YAMLs to $OUTPUT_DIR."
  echo "You must run kubeseal locally with your cluster's Sealed Secrets public cert to produce sealed YAML files before committing."
  echo "Example: kubeseal --format=yaml < ${SECRET_NAME}.secret.yaml > sealed-${SECRET_NAME}.yaml"
  exit 0
fi

echo "Creating sealed secrets using kubeseal: ensure you have access to the cluster or the sealer cert."
kubeseal --format=yaml < "$OUTPUT_DIR/${SECRET_NAME}.secret.yaml" > "$OUTPUT_DIR/sealed-${SECRET_NAME}.yaml"
kubeseal --format=yaml < "$OUTPUT_DIR/${SECRET_NAME}-app.secret.yaml" > "$OUTPUT_DIR/sealed-${SECRET_NAME}-app.yaml"

echo "Sealed secrets created successfully in: $OUTPUT_DIR"
echo "Next steps:"
echo "  1) Inspect the sealed files and commit the sealed YAML files to your infra repo under:"
echo "     all-infrastructure/cluster-resources/sealed-secrets/"
echo "  2) Remove the plaintext secret YAML files from version control before committing."
echo "  3) Run 'argocd app sync' or wait for ArgoCD to apply the sealed secret and create Kubernetes Secret objects."

echo "Sealed files:"
ls -1 "$OUTPUT_DIR/sealed-"*.yaml || true
