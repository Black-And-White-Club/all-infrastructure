#!/usr/bin/env bash
set -euo pipefail

# Helper script to generate backend-secrets for frolf-bot
# Usage: ./generate-frolf-backend-secrets.sh

OUTPUT_FILE="sealed-backend-secrets.yaml"
NAMESPACE="frolf-bot"
SECRET_NAME="backend-secrets"

# Values derived from current cluster state and configuration
DB_HOST="frolf-postgres-postgresql.frolf-bot.svc.cluster.local"
DB_PORT="5432"
DB_USER="postgres"
DB_PASSWORD="postgres"
DB_NAME="frolf_bot"
NATS_URL="nats://frolf-nats.frolf-bot.svc.cluster.local:4222"

# Construct connection strings
POSTGRES_DSN="postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=disable"
DATABASE_URL="${POSTGRES_DSN}"

echo "Generating raw secret..."
kubectl create secret generic ${SECRET_NAME} \
  --namespace ${NAMESPACE} \
  --from-literal=DATABASE_URL="${DATABASE_URL}" \
  --from-literal=DB_HOST="${DB_HOST}" \
  --from-literal=DB_PORT="${DB_PORT}" \
  --from-literal=DB_USER="${DB_USER}" \
  --from-literal=DB_PASSWORD="${DB_PASSWORD}" \
  --from-literal=DB_NAME="${DB_NAME}" \
  --from-literal=POSTGRES_DSN="${POSTGRES_DSN}" \
  --from-literal=NATS_URL="${NATS_URL}" \
  --dry-run=client -o yaml > "${SECRET_NAME}.yaml"

echo "Sealing secret..."
kubeseal --format=yaml < "${SECRET_NAME}.yaml" > "${OUTPUT_FILE}"

# Clean up raw secret
rm "${SECRET_NAME}.yaml"

echo "Sealed secret created at ${OUTPUT_FILE}"
