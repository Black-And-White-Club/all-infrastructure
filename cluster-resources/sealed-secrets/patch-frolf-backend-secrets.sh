#!/usr/bin/env bash
set -euo pipefail

# Patches new keys into an existing sealed-backend-secrets.yaml without
# requiring all existing secret values to be re-supplied.
#
# Usage:
#   TOKEN_ENCRYPTION_KEY=... AUTH_CALLOUT_SERVER_PUBLIC_KEY=... \
#   [TOKEN_ENCRYPTION_KEY_PREVIOUS=...] \
#   [TRUSTED_PROXY_CIDRS=10.0.0.0/8,192.168.0.0/16] \
#   [STRIPE_SECRET_KEY=sk_live_...] \
#   [STRIPE_WEBHOOK_SECRET=whsec_...] \
#   [STRIPE_APPLICATION_FEE_CENTS=50] \
#   ./patch-frolf-backend-secrets.sh [sealed-secret-file]
#
# TOKEN_ENCRYPTION_KEY (and TOKEN_ENCRYPTION_KEY_PREVIOUS, when set for key
# rotation) must each be exactly 32 bytes; the backend hard-fails otherwise.
#
# Known keys that can be patched individually (set only the ones you want to
# update; unset vars are silently skipped):
#   TOKEN_ENCRYPTION_KEY, TOKEN_ENCRYPTION_KEY_PREVIOUS,
#   AUTH_CALLOUT_SERVER_PUBLIC_KEY, DISCORD_OAUTH_ACTIVITY_REDIRECT_URL,
#   TRUSTED_PROXY_CIDRS,
#   STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, STRIPE_APPLICATION_FEE_CENTS,
#   STRIPE_BILLING_WEBHOOK_SECRET, STRIPE_PLATFORM_SEASON_FEE_CENTS
#
# Stripe cutover workflow (seal all three in one pass, then flip STRIPE_ENABLED):
#   STRIPE_SECRET_KEY=sk_live_... \
#   STRIPE_WEBHOOK_SECRET=whsec_... \
#   STRIPE_APPLICATION_FEE_CENTS=50 \
#   ./patch-frolf-backend-secrets.sh /path/to/all-infrastructure-secrets/sealed-backend-secrets.sops.yaml
# Then in all-infrastructure (base deployment.yaml): set STRIPE_ENABLED value to "true",
# commit, and let ArgoCD sync. See cluster-resources/sealed-secrets/README.md#stripe-cutover.

SEALED_SECRET_FILE="${1:-sealed-backend-secrets.yaml}"
NAMESPACE="${NAMESPACE:-frolf-bot}"
SECRET_NAME="${SECRET_NAME:-backend-secrets}"

TOKEN_ENCRYPTION_KEY="${TOKEN_ENCRYPTION_KEY:-}"
TOKEN_ENCRYPTION_KEY_PREVIOUS="${TOKEN_ENCRYPTION_KEY_PREVIOUS:-}"
AUTH_CALLOUT_SERVER_PUBLIC_KEY="${AUTH_CALLOUT_SERVER_PUBLIC_KEY:-}"
DISCORD_OAUTH_ACTIVITY_REDIRECT_URL="${DISCORD_OAUTH_ACTIVITY_REDIRECT_URL:-}"
TRUSTED_PROXY_CIDRS="${TRUSTED_PROXY_CIDRS:-}"
STRIPE_SECRET_KEY="${STRIPE_SECRET_KEY:-}"
STRIPE_WEBHOOK_SECRET="${STRIPE_WEBHOOK_SECRET:-}"
STRIPE_APPLICATION_FEE_CENTS="${STRIPE_APPLICATION_FEE_CENTS:-}"
STRIPE_BILLING_WEBHOOK_SECRET="${STRIPE_BILLING_WEBHOOK_SECRET:-}"
STRIPE_PLATFORM_SEASON_FEE_CENTS="${STRIPE_PLATFORM_SEASON_FEE_CENTS:-}"

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

PATCHED=0

if [[ -n "${TOKEN_ENCRYPTION_KEY}" ]]; then
  TOKEN_ENCRYPTION_KEY_BYTES="$(printf %s "${TOKEN_ENCRYPTION_KEY}" | wc -c | tr -d '[:space:]')"
  if [[ "${TOKEN_ENCRYPTION_KEY_BYTES}" -ne 32 ]]; then
    echo "ERROR: TOKEN_ENCRYPTION_KEY must be exactly 32 bytes (got ${TOKEN_ENCRYPTION_KEY_BYTES})" >&2
    exit 1
  fi
  echo "Sealing TOKEN_ENCRYPTION_KEY..."
  SEALED_TOKEN_ENCRYPTION_KEY=$(seal_value "${TOKEN_ENCRYPTION_KEY}")
  yq -i ".spec.encryptedData.TOKEN_ENCRYPTION_KEY = \"${SEALED_TOKEN_ENCRYPTION_KEY}\"" "${SEALED_SECRET_FILE}"
  PATCHED=$((PATCHED + 1))
fi

if [[ -n "${TOKEN_ENCRYPTION_KEY_PREVIOUS}" ]]; then
  TOKEN_ENCRYPTION_KEY_PREVIOUS_BYTES="$(printf %s "${TOKEN_ENCRYPTION_KEY_PREVIOUS}" | wc -c | tr -d '[:space:]')"
  if [[ "${TOKEN_ENCRYPTION_KEY_PREVIOUS_BYTES}" -ne 32 ]]; then
    echo "ERROR: TOKEN_ENCRYPTION_KEY_PREVIOUS must be exactly 32 bytes (got ${TOKEN_ENCRYPTION_KEY_PREVIOUS_BYTES})" >&2
    exit 1
  fi
  echo "Sealing TOKEN_ENCRYPTION_KEY_PREVIOUS..."
  SEALED_TOKEN_ENCRYPTION_KEY_PREVIOUS=$(seal_value "${TOKEN_ENCRYPTION_KEY_PREVIOUS}")
  yq -i ".spec.encryptedData.TOKEN_ENCRYPTION_KEY_PREVIOUS = \"${SEALED_TOKEN_ENCRYPTION_KEY_PREVIOUS}\"" "${SEALED_SECRET_FILE}"
  PATCHED=$((PATCHED + 1))
fi

if [[ -n "${AUTH_CALLOUT_SERVER_PUBLIC_KEY}" ]]; then
  echo "Sealing AUTH_CALLOUT_SERVER_PUBLIC_KEY..."
  SEALED_AUTH_CALLOUT_SERVER_PUBLIC_KEY=$(seal_value "${AUTH_CALLOUT_SERVER_PUBLIC_KEY}")
  yq -i ".spec.encryptedData.AUTH_CALLOUT_SERVER_PUBLIC_KEY = \"${SEALED_AUTH_CALLOUT_SERVER_PUBLIC_KEY}\"" "${SEALED_SECRET_FILE}"
  PATCHED=$((PATCHED + 1))
fi

if [[ -n "${DISCORD_OAUTH_ACTIVITY_REDIRECT_URL}" ]]; then
  echo "Sealing DISCORD_OAUTH_ACTIVITY_REDIRECT_URL..."
  SEALED_ACTIVITY_REDIRECT=$(seal_value "${DISCORD_OAUTH_ACTIVITY_REDIRECT_URL}")
  yq -i ".spec.encryptedData.DISCORD_OAUTH_ACTIVITY_REDIRECT_URL = \"${SEALED_ACTIVITY_REDIRECT}\"" "${SEALED_SECRET_FILE}"
  PATCHED=$((PATCHED + 1))
fi

if [[ -n "${TRUSTED_PROXY_CIDRS}" ]]; then
  echo "Sealing TRUSTED_PROXY_CIDRS..."
  SEALED_TRUSTED_PROXY_CIDRS=$(seal_value "${TRUSTED_PROXY_CIDRS}")
  yq -i ".spec.encryptedData.TRUSTED_PROXY_CIDRS = \"${SEALED_TRUSTED_PROXY_CIDRS}\"" "${SEALED_SECRET_FILE}"
  PATCHED=$((PATCHED + 1))
fi

if [[ -n "${STRIPE_SECRET_KEY}" ]]; then
  echo "Sealing STRIPE_SECRET_KEY..."
  SEALED_STRIPE_SECRET_KEY=$(seal_value "${STRIPE_SECRET_KEY}")
  yq -i ".spec.encryptedData.STRIPE_SECRET_KEY = \"${SEALED_STRIPE_SECRET_KEY}\"" "${SEALED_SECRET_FILE}"
  PATCHED=$((PATCHED + 1))
fi

if [[ -n "${STRIPE_WEBHOOK_SECRET}" ]]; then
  echo "Sealing STRIPE_WEBHOOK_SECRET..."
  SEALED_STRIPE_WEBHOOK_SECRET=$(seal_value "${STRIPE_WEBHOOK_SECRET}")
  yq -i ".spec.encryptedData.STRIPE_WEBHOOK_SECRET = \"${SEALED_STRIPE_WEBHOOK_SECRET}\"" "${SEALED_SECRET_FILE}"
  PATCHED=$((PATCHED + 1))
fi

if [[ -n "${STRIPE_APPLICATION_FEE_CENTS}" ]]; then
  # STRIPE_APPLICATION_FEE_CENTS is a non-secret integer (≥0 cents applied as a
  # platform fee per charge). It is sealed here — rather than set as a plain
  # value in deployment.yaml — so the entire Stripe feature activates in a
  # single owner sealing action, keeping the "flip STRIPE_ENABLED to true" step
  # as the only remaining cutover change.
  echo "Sealing STRIPE_APPLICATION_FEE_CENTS..."
  SEALED_STRIPE_APPLICATION_FEE_CENTS=$(seal_value "${STRIPE_APPLICATION_FEE_CENTS}")
  yq -i ".spec.encryptedData.STRIPE_APPLICATION_FEE_CENTS = \"${SEALED_STRIPE_APPLICATION_FEE_CENTS}\"" "${SEALED_SECRET_FILE}"
  PATCHED=$((PATCHED + 1))
fi

if [[ -n "${STRIPE_BILLING_WEBHOOK_SECRET}" ]]; then
  echo "Sealing STRIPE_BILLING_WEBHOOK_SECRET..."
  SEALED_STRIPE_BILLING_WEBHOOK_SECRET=$(seal_value "${STRIPE_BILLING_WEBHOOK_SECRET}")
  yq -i ".spec.encryptedData.STRIPE_BILLING_WEBHOOK_SECRET = \"${SEALED_STRIPE_BILLING_WEBHOOK_SECRET}\"" "${SEALED_SECRET_FILE}"
  PATCHED=$((PATCHED + 1))
fi

if [[ -n "${STRIPE_PLATFORM_SEASON_FEE_CENTS}" ]]; then
  # STRIPE_PLATFORM_SEASON_FEE_CENTS is a non-secret integer (≥0 cents charged
  # to each club as a platform billing fee per season). It is sealed here — rather
  # than set as a plain value in deployment.yaml — so the entire billing feature
  # activates in a single owner sealing action, parallel to the collection-rail
  # pattern used for STRIPE_APPLICATION_FEE_CENTS.
  echo "Sealing STRIPE_PLATFORM_SEASON_FEE_CENTS..."
  SEALED_STRIPE_PLATFORM_SEASON_FEE_CENTS=$(seal_value "${STRIPE_PLATFORM_SEASON_FEE_CENTS}")
  yq -i ".spec.encryptedData.STRIPE_PLATFORM_SEASON_FEE_CENTS = \"${SEALED_STRIPE_PLATFORM_SEASON_FEE_CENTS}\"" "${SEALED_SECRET_FILE}"
  PATCHED=$((PATCHED + 1))
fi

echo "Done. Patched ${SEALED_SECRET_FILE} with ${PATCHED} key(s)."
