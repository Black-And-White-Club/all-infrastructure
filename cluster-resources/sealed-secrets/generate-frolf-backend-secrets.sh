#!/usr/bin/env bash
set -euo pipefail

# Helper script to generate sealed backend-secrets for frolf-bot.
# All sensitive values must be provided explicitly through environment variables.
#
# Usage:
#   DB_PASSWORD=... NATS_AUTH_PASSWORD=... AUTH_CALLOUT_ISSUER_NKEY=... \
#   AUTH_CALLOUT_SIGNING_NKEY=... JWT_SECRET=... \
#   DISCORD_OAUTH_CLIENT_ID=... DISCORD_OAUTH_CLIENT_SECRET=... \
#   GOOGLE_OAUTH_CLIENT_ID=... GOOGLE_OAUTH_CLIENT_SECRET=... \
#   ./generate-frolf-backend-secrets.sh [output-file]

OUTPUT_FILE="${1:-sealed-backend-secrets.yaml}"
NAMESPACE="${NAMESPACE:-frolf-bot}"
SECRET_NAME="${SECRET_NAME:-backend-secrets}"

DB_HOST="${DB_HOST:-frolf-postgres-postgresql.frolf-bot.svc.cluster.local}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_NAME="${DB_NAME:-frolf_bot}"

NATS_AUTH_USER="${NATS_AUTH_USER:-auth-service}"
NATS_AUTH_PASSWORD="${NATS_AUTH_PASSWORD:-}"

AUTH_CALLOUT_ENABLED="${AUTH_CALLOUT_ENABLED:-true}"
AUTH_CALLOUT_SUBJECT="${AUTH_CALLOUT_SUBJECT:-\$SYS.REQ.USER.AUTH}"
AUTH_CALLOUT_ISSUER_NKEY="${AUTH_CALLOUT_ISSUER_NKEY:-}"
AUTH_CALLOUT_SIGNING_NKEY="${AUTH_CALLOUT_SIGNING_NKEY:-}"

JWT_SECRET="${JWT_SECRET:-}"
JWT_ISSUER="${JWT_ISSUER:-frolf-bot}"
JWT_AUDIENCE="${JWT_AUDIENCE:-frolf-bot-users}"

DISCORD_OAUTH_CLIENT_ID="${DISCORD_OAUTH_CLIENT_ID:-}"
DISCORD_OAUTH_CLIENT_SECRET="${DISCORD_OAUTH_CLIENT_SECRET:-}"
DISCORD_OAUTH_REDIRECT_URL="${DISCORD_OAUTH_REDIRECT_URL:-https://frolf-bot.duckdns.org/api/auth/discord/callback}"
GOOGLE_OAUTH_CLIENT_ID="${GOOGLE_OAUTH_CLIENT_ID:-}"
GOOGLE_OAUTH_CLIENT_SECRET="${GOOGLE_OAUTH_CLIENT_SECRET:-}"
GOOGLE_OAUTH_REDIRECT_URL="${GOOGLE_OAUTH_REDIRECT_URL:-https://frolf-bot.duckdns.org/api/auth/google/callback}"
PWA_BASE_URL="${PWA_BASE_URL:-https://frolf-bot.duckdns.org}"

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command '$cmd' is not installed." >&2
    exit 1
  fi
}

require_var() {
  local var_name="$1"
  local var_value="${!var_name:-}"
  if [[ -z "${var_value}" ]]; then
    echo "ERROR: ${var_name} is required and must be set." >&2
    exit 1
  fi
}

require_command kubectl
require_command kubeseal

require_var DB_PASSWORD
require_var NATS_AUTH_PASSWORD
require_var AUTH_CALLOUT_ISSUER_NKEY
require_var AUTH_CALLOUT_SIGNING_NKEY
require_var JWT_SECRET
require_var DISCORD_OAUTH_CLIENT_ID
require_var DISCORD_OAUTH_CLIENT_SECRET
require_var GOOGLE_OAUTH_CLIENT_ID
require_var GOOGLE_OAUTH_CLIENT_SECRET

POSTGRES_DSN="postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=disable"
DATABASE_URL="${POSTGRES_DSN}"
NATS_URL="nats://${NATS_AUTH_USER}:${NATS_AUTH_PASSWORD}@frolf-nats.frolf-bot.svc.cluster.local:4222"

RAW_SECRET_FILE="$(mktemp)"
trap 'rm -f "$RAW_SECRET_FILE"' EXIT

kubectl create secret generic "${SECRET_NAME}" \
  --namespace "${NAMESPACE}" \
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
  --from-literal=DISCORD_OAUTH_CLIENT_ID="${DISCORD_OAUTH_CLIENT_ID}" \
  --from-literal=DISCORD_OAUTH_CLIENT_SECRET="${DISCORD_OAUTH_CLIENT_SECRET}" \
  --from-literal=DISCORD_OAUTH_REDIRECT_URL="${DISCORD_OAUTH_REDIRECT_URL}" \
  --from-literal=GOOGLE_OAUTH_CLIENT_ID="${GOOGLE_OAUTH_CLIENT_ID}" \
  --from-literal=GOOGLE_OAUTH_CLIENT_SECRET="${GOOGLE_OAUTH_CLIENT_SECRET}" \
  --from-literal=GOOGLE_OAUTH_REDIRECT_URL="${GOOGLE_OAUTH_REDIRECT_URL}" \
  --from-literal=PWA_BASE_URL="${PWA_BASE_URL}" \
  --dry-run=client -o yaml > "${RAW_SECRET_FILE}"

kubeseal --format=yaml < "${RAW_SECRET_FILE}" > "${OUTPUT_FILE}"
echo "Sealed secret created at ${OUTPUT_FILE}"
