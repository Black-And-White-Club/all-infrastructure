#!/usr/bin/env bash
set -euo pipefail

# Patches new keys into an existing sealed-backend-secrets.yaml without
# requiring all existing secret values to be re-supplied.
#
# Usage:
#   TOKEN_ENCRYPTION_KEY=... AUTH_CALLOUT_SERVER_PUBLIC_KEY=... \
#   ./patch-frolf-backend-secrets.sh [sealed-secret-file]

SEALED_SECRET_FILE="${1:-sealed-backend-secrets.yaml}"
NAMESPACE="${NAMESPACE:-frolf-bot}"
SECRET_NAME="${SECRET_NAME:-backend-secrets}"

TOKEN_ENCRYPTION_KEY="${TOKEN_ENCRYPTION_KEY:-}"
AUTH_CALLOUT_SERVER_PUBLIC_KEY="${AUTH_CALLOUT_SERVER_PUBLIC_KEY:-}"

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

require_command kubeseal
require_command yq

require_var TOKEN_ENCRYPTION_KEY
require_var AUTH_CALLOUT_SERVER_PUBLIC_KEY

if [[ ! -f "${SEALED_SECRET_FILE}" ]]; then
  echo "ERROR: ${SEALED_SECRET_FILE} not found." >&2
  exit 1
fi

seal_value() {
  echo -n "$1" | kubeseal --raw \
    --namespace "${NAMESPACE}" \
    --name "${SECRET_NAME}" \
    --scope strict
}

echo "Sealing TOKEN_ENCRYPTION_KEY..."
SEALED_TOKEN_ENCRYPTION_KEY=$(seal_value "${TOKEN_ENCRYPTION_KEY}")

echo "Sealing AUTH_CALLOUT_SERVER_PUBLIC_KEY..."
SEALED_AUTH_CALLOUT_SERVER_PUBLIC_KEY=$(seal_value "${AUTH_CALLOUT_SERVER_PUBLIC_KEY}")

echo "Patching ${SEALED_SECRET_FILE}..."
yq -i ".spec.encryptedData.TOKEN_ENCRYPTION_KEY = \"${SEALED_TOKEN_ENCRYPTION_KEY}\"" "${SEALED_SECRET_FILE}"
yq -i ".spec.encryptedData.AUTH_CALLOUT_SERVER_PUBLIC_KEY = \"${SEALED_AUTH_CALLOUT_SERVER_PUBLIC_KEY}\"" "${SEALED_SECRET_FILE}"

echo "Done. Patched ${SEALED_SECRET_FILE} with 2 new keys."
