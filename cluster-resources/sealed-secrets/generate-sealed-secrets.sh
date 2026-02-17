#!/usr/bin/env bash
set -euo pipefail

# Helper script to generate DB credentials for resume-backend and create
# SealedSecret manifests without leaving plaintext Secret manifests behind.
#
# Usage:
#   ./generate-sealed-secrets.sh [output-dir]

OUTPUT_DIR="${1:-./out}"
NAMESPACE_DB="resume-db"
NAMESPACE_APP="resume-app"
SECRET_NAME="resume-backend-postgresql"
POSTGRES_USER="resume_user"
POSTGRES_DB="resume_db"

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command '$cmd' is not installed." >&2
    exit 1
  fi
}

require_command openssl
require_command kubeseal

mkdir -p "$OUTPUT_DIR"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PG_PASSWORD="$(openssl rand -hex 20)"
PG_HOST="resume-backend-postgresql.${NAMESPACE_DB}.svc.cluster.local"
PG_PORT=5432
DB_URL="postgresql://${POSTGRES_USER}:${PG_PASSWORD}@${PG_HOST}:${PG_PORT}/${POSTGRES_DB}?sslmode=disable"

cat > "${TMP_DIR}/${SECRET_NAME}.secret.yaml" <<EOF
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

cat > "${TMP_DIR}/${SECRET_NAME}-app.secret.yaml" <<EOF
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

kubeseal --format=yaml < "${TMP_DIR}/${SECRET_NAME}.secret.yaml" > "${OUTPUT_DIR}/sealed-${SECRET_NAME}.yaml"
kubeseal --format=yaml < "${TMP_DIR}/${SECRET_NAME}-app.secret.yaml" > "${OUTPUT_DIR}/sealed-${SECRET_NAME}-app.yaml"

echo "Sealed secrets generated in ${OUTPUT_DIR}:"
ls -1 "${OUTPUT_DIR}/sealed-${SECRET_NAME}"*.yaml
