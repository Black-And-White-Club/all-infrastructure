#!/usr/bin/env bash
set -euo pipefail

# Helper script to generate backend-secrets for frolf-bot
# Usage: ./generate-frolf-backend-secrets.sh
#
# Prerequisites:
# 1. Run ../scripts/generate-nats-auth-keys.sh to generate auth keys
# 2. Update the AUTH_CALLOUT_* variables below with the generated seed keys

OUTPUT_FILE="sealed-backend-secrets.yaml"
NAMESPACE="frolf-bot"
SECRET_NAME="backend-secrets"

# =============================================================================
# Database Configuration
# =============================================================================
DB_HOST="frolf-postgres-postgresql.frolf-bot.svc.cluster.local"
DB_PORT="5432"
DB_USER="postgres"
DB_PASSWORD="postgres"
DB_NAME="frolf_bot"

# Construct connection strings
POSTGRES_DSN="postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=disable"
DATABASE_URL="${POSTGRES_DSN}"

# =============================================================================
# NATS Configuration
# =============================================================================
# The auth-service user credentials must match what's in the NATS helm values
NATS_AUTH_USER="auth-service"
NATS_AUTH_PASSWORD="${NATS_AUTH_PASSWORD:-CHANGE_ME_STRONG_PASSWORD}"
NATS_URL="nats://${NATS_AUTH_USER}:${NATS_AUTH_PASSWORD}@frolf-nats.frolf-bot.svc.cluster.local:4222"

# =============================================================================
# Auth Callout Configuration
# Generate keys with: ./scripts/generate-nats-auth-keys.sh ./secrets
# Then copy the seed values here (lines starting with SA... and SU...)
# =============================================================================
AUTH_CALLOUT_ENABLED="true"
AUTH_CALLOUT_SUBJECT="\$SYS.REQ.USER.AUTH"

# TODO: Replace these with your actual generated keys!
AUTH_CALLOUT_ISSUER_NKEY="${AUTH_CALLOUT_ISSUER_NKEY:-SAXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}"
AUTH_CALLOUT_SIGNING_NKEY="${AUTH_CALLOUT_SIGNING_NKEY:-SUXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}"

# =============================================================================
# JWT Configuration
# =============================================================================
JWT_SECRET="${JWT_SECRET:-CHANGE_ME_GENERATE_STRONG_SECRET}"
JWT_ISSUER="frolf-bot"
JWT_AUDIENCE="frolf-bot-users"

# =============================================================================
# Generate the secret
# =============================================================================
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
  --from-literal=AUTH_CALLOUT_ENABLED="${AUTH_CALLOUT_ENABLED}" \
  --from-literal=AUTH_CALLOUT_SUBJECT="${AUTH_CALLOUT_SUBJECT}" \
  --from-literal=AUTH_CALLOUT_ISSUER_NKEY="${AUTH_CALLOUT_ISSUER_NKEY}" \
  --from-literal=AUTH_CALLOUT_SIGNING_NKEY="${AUTH_CALLOUT_SIGNING_NKEY}" \
  --from-literal=JWT_SECRET="${JWT_SECRET}" \
  --from-literal=JWT_ISSUER="${JWT_ISSUER}" \
  --from-literal=JWT_AUDIENCE="${JWT_AUDIENCE}" \
  --dry-run=client -o yaml > "${SECRET_NAME}.yaml"

echo "Sealing secret..."
kubeseal --format=yaml < "${SECRET_NAME}.yaml" > "${OUTPUT_FILE}"

# Clean up raw secret
rm "${SECRET_NAME}.yaml"

echo "Sealed secret created at ${OUTPUT_FILE}"
echo ""
echo "IMPORTANT: Make sure to also update the NATS helm values with:"
echo "  - The account PUBLIC key (for issuer field)"
echo "  - Matching NATS_AUTH_PASSWORD"
