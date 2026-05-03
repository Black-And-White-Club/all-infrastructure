#!/usr/bin/env bash
set -euo pipefail

# Helper script to generate sealed backend-secrets for frolf-bot.
# All sensitive values must be provided explicitly through environment variables.
#
# Usage:
#   DB_PASSWORD=... NATS_AUTH_PASSWORD=... AUTH_CALLOUT_ISSUER_NKEY=... \
#   AUTH_CALLOUT_SIGNING_NKEY=... JWT_SECRET=... TOKEN_ENCRYPTION_KEY=... \
#   AUTH_CALLOUT_SERVER_PUBLIC_KEY=... \
#   DISCORD_OAUTH_CLIENT_ID=... DISCORD_OAUTH_CLIENT_SECRET=... \
#   GOOGLE_OAUTH_CLIENT_ID=... GOOGLE_OAUTH_CLIENT_SECRET=... \
#   SMTP_HOST=... SMTP_USER=... SMTP_PASSWORD=... SMTP_FROM=... \
#   [SMTP_PORT=587] \
#   [TOKEN_ENCRYPTION_KEY_PREVIOUS=...] \
#   [TRUSTED_PROXY_CIDRS=10.0.0.0/8,192.168.0.0/16] \
#   ./generate-frolf-backend-secrets.sh [output-file]
#
# TOKEN_ENCRYPTION_KEY must be exactly 32 bytes. TOKEN_ENCRYPTION_KEY_PREVIOUS
# is optional (used during key rotation) and must also be exactly 32 bytes when
# set.

OUTPUT_FILE="${1:-${SECRETS_REPO_DIR:-.}/sealed-backend-secrets.yaml}"
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
AUTH_CALLOUT_SERVER_PUBLIC_KEY="${AUTH_CALLOUT_SERVER_PUBLIC_KEY:-}"

JWT_SECRET="${JWT_SECRET:-}"
TOKEN_ENCRYPTION_KEY="${TOKEN_ENCRYPTION_KEY:-}"
TOKEN_ENCRYPTION_KEY_PREVIOUS="${TOKEN_ENCRYPTION_KEY_PREVIOUS:-}"
JWT_ISSUER="${JWT_ISSUER:-frolf-bot}"
JWT_AUDIENCE="${JWT_AUDIENCE:-frolf-bot-users}"

DISCORD_OAUTH_CLIENT_ID="${DISCORD_OAUTH_CLIENT_ID:-}"
DISCORD_OAUTH_CLIENT_SECRET="${DISCORD_OAUTH_CLIENT_SECRET:-}"
DISCORD_OAUTH_REDIRECT_URL="${DISCORD_OAUTH_REDIRECT_URL:-https://frolf-bot.duckdns.org/api/auth/discord/callback}"
DISCORD_OAUTH_ACTIVITY_REDIRECT_URL="${DISCORD_OAUTH_ACTIVITY_REDIRECT_URL:-}"
GOOGLE_OAUTH_CLIENT_ID="${GOOGLE_OAUTH_CLIENT_ID:-}"
GOOGLE_OAUTH_CLIENT_SECRET="${GOOGLE_OAUTH_CLIENT_SECRET:-}"
GOOGLE_OAUTH_REDIRECT_URL="${GOOGLE_OAUTH_REDIRECT_URL:-https://frolf-bot.duckdns.org/api/auth/google/callback}"
PWA_BASE_URL="${PWA_BASE_URL:-https://frolf-bot.duckdns.org}"
TRUSTED_PROXY_CIDRS="${TRUSTED_PROXY_CIDRS:-}"

SMTP_HOST="${SMTP_HOST:-}"
# 587 (STARTTLS submission) is the well-known default; safe to keep without operator input.
SMTP_PORT="${SMTP_PORT:-587}"
SMTP_USER="${SMTP_USER:-}"
SMTP_PASSWORD="${SMTP_PASSWORD:-}"
SMTP_FROM="${SMTP_FROM:-}"

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
require_var AUTH_CALLOUT_SERVER_PUBLIC_KEY
require_var JWT_SECRET
require_var TOKEN_ENCRYPTION_KEY
require_var DISCORD_OAUTH_CLIENT_ID
require_var DISCORD_OAUTH_CLIENT_SECRET
require_var GOOGLE_OAUTH_CLIENT_ID
require_var GOOGLE_OAUTH_CLIENT_SECRET
require_var SMTP_HOST
require_var SMTP_USER
require_var SMTP_PASSWORD
require_var SMTP_FROM

# TOKEN_ENCRYPTION_KEY must be exactly 32 bytes (the backend hard-fails at
# config-load otherwise). Use byte-length to be UTF-8 safe.
TOKEN_ENCRYPTION_KEY_BYTES="$(printf %s "${TOKEN_ENCRYPTION_KEY}" | wc -c | tr -d '[:space:]')"
if [[ "${TOKEN_ENCRYPTION_KEY_BYTES}" -ne 32 ]]; then
  echo "ERROR: TOKEN_ENCRYPTION_KEY must be exactly 32 bytes (got ${TOKEN_ENCRYPTION_KEY_BYTES})" >&2
  exit 1
fi

if [[ -n "${TOKEN_ENCRYPTION_KEY_PREVIOUS}" ]]; then
  TOKEN_ENCRYPTION_KEY_PREVIOUS_BYTES="$(printf %s "${TOKEN_ENCRYPTION_KEY_PREVIOUS}" | wc -c | tr -d '[:space:]')"
  if [[ "${TOKEN_ENCRYPTION_KEY_PREVIOUS_BYTES}" -ne 32 ]]; then
    echo "ERROR: TOKEN_ENCRYPTION_KEY_PREVIOUS must be exactly 32 bytes (got ${TOKEN_ENCRYPTION_KEY_PREVIOUS_BYTES})" >&2
    exit 1
  fi
fi

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
  --from-literal=AUTH_CALLOUT_SERVER_PUBLIC_KEY="${AUTH_CALLOUT_SERVER_PUBLIC_KEY}" \
  --from-literal=JWT_SECRET="${JWT_SECRET}" \
  --from-literal=TOKEN_ENCRYPTION_KEY="${TOKEN_ENCRYPTION_KEY}" \
  --from-literal=TOKEN_ENCRYPTION_KEY_PREVIOUS="${TOKEN_ENCRYPTION_KEY_PREVIOUS}" \
  --from-literal=JWT_ISSUER="${JWT_ISSUER}" \
  --from-literal=JWT_AUDIENCE="${JWT_AUDIENCE}" \
  --from-literal=DISCORD_OAUTH_CLIENT_ID="${DISCORD_OAUTH_CLIENT_ID}" \
  --from-literal=DISCORD_OAUTH_CLIENT_SECRET="${DISCORD_OAUTH_CLIENT_SECRET}" \
  --from-literal=DISCORD_OAUTH_REDIRECT_URL="${DISCORD_OAUTH_REDIRECT_URL}" \
  --from-literal=DISCORD_OAUTH_ACTIVITY_REDIRECT_URL="${DISCORD_OAUTH_ACTIVITY_REDIRECT_URL}" \
  --from-literal=GOOGLE_OAUTH_CLIENT_ID="${GOOGLE_OAUTH_CLIENT_ID}" \
  --from-literal=GOOGLE_OAUTH_CLIENT_SECRET="${GOOGLE_OAUTH_CLIENT_SECRET}" \
  --from-literal=GOOGLE_OAUTH_REDIRECT_URL="${GOOGLE_OAUTH_REDIRECT_URL}" \
  --from-literal=PWA_BASE_URL="${PWA_BASE_URL}" \
  --from-literal=TRUSTED_PROXY_CIDRS="${TRUSTED_PROXY_CIDRS}" \
  --from-literal=SMTP_HOST="${SMTP_HOST}" \
  --from-literal=SMTP_PORT="${SMTP_PORT}" \
  --from-literal=SMTP_USER="${SMTP_USER}" \
  --from-literal=SMTP_PASSWORD="${SMTP_PASSWORD}" \
  --from-literal=SMTP_FROM="${SMTP_FROM}" \
  --dry-run=client -o yaml > "${RAW_SECRET_FILE}"

kubeseal --format=yaml < "${RAW_SECRET_FILE}" > "${OUTPUT_FILE}"
echo "Sealed secret created at ${OUTPUT_FILE}"
