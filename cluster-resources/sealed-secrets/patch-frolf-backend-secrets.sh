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
#   DISCORD_OAUTH_REDIRECT_URL, GOOGLE_OAUTH_REDIRECT_URL, PWA_BASE_URL,
#   TRUSTED_PROXY_CIDRS,
#   STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, STRIPE_APPLICATION_FEE_CENTS,
#   STRIPE_BILLING_WEBHOOK_SECRET, STRIPE_PLATFORM_SEASON_FEE_CENTS,
#   CLUBHOUSE_GUEST_CLAIM_KEY_JSON, SPECTATE_CLAIM_KEY_JSON
#
# Capability-token signing keys (see the block near the bottom of this file):
#   CLUBHOUSE_GUEST_CLAIM_KEY_JSON="{\"v1\":\"$(openssl rand -base64 32)\"}" \
#   SPECTATE_CLAIM_KEY_JSON="{\"v1\":\"$(openssl rand -base64 32)\"}" \
#   ./patch-frolf-backend-secrets.sh /path/to/all-infrastructure-secrets/sealed-backend-secrets.sops.yaml
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
# kubeseal's built-in default (--controller-name sealed-secrets-controller) points at a
# stale, endpoint-less service left over from before the controller was deployed via the
# `sealed-secrets` Helm release (see argocd/platform/sealed-secrets-controller.yaml,
# releaseName: sealed-secrets) — the live controller service in this cluster is named
# `sealed-secrets`, not `sealed-secrets-controller`. Override explicitly rather than rely
# on kubeseal's default.
CONTROLLER_NAME="${CONTROLLER_NAME:-sealed-secrets}"
CONTROLLER_NAMESPACE="${CONTROLLER_NAMESPACE:-kube-system}"

TOKEN_ENCRYPTION_KEY="${TOKEN_ENCRYPTION_KEY:-}"
TOKEN_ENCRYPTION_KEY_PREVIOUS="${TOKEN_ENCRYPTION_KEY_PREVIOUS:-}"
AUTH_CALLOUT_SERVER_PUBLIC_KEY="${AUTH_CALLOUT_SERVER_PUBLIC_KEY:-}"
DISCORD_OAUTH_ACTIVITY_REDIRECT_URL="${DISCORD_OAUTH_ACTIVITY_REDIRECT_URL:-}"
DISCORD_OAUTH_REDIRECT_URL="${DISCORD_OAUTH_REDIRECT_URL:-}"
GOOGLE_OAUTH_REDIRECT_URL="${GOOGLE_OAUTH_REDIRECT_URL:-}"
PWA_BASE_URL="${PWA_BASE_URL:-}"
TRUSTED_PROXY_CIDRS="${TRUSTED_PROXY_CIDRS:-}"
STRIPE_SECRET_KEY="${STRIPE_SECRET_KEY:-}"
STRIPE_WEBHOOK_SECRET="${STRIPE_WEBHOOK_SECRET:-}"
STRIPE_APPLICATION_FEE_CENTS="${STRIPE_APPLICATION_FEE_CENTS:-}"
STRIPE_BILLING_WEBHOOK_SECRET="${STRIPE_BILLING_WEBHOOK_SECRET:-}"
STRIPE_PLATFORM_SEASON_FEE_CENTS="${STRIPE_PLATFORM_SEASON_FEE_CENTS:-}"
CLUBHOUSE_GUEST_CLAIM_KEY_JSON="${CLUBHOUSE_GUEST_CLAIM_KEY_JSON:-}"
SPECTATE_CLAIM_KEY_JSON="${SPECTATE_CLAIM_KEY_JSON:-}"

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
    --controller-name "${CONTROLLER_NAME}" \
    --controller-namespace "${CONTROLLER_NAMESPACE}" \
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

if [[ -n "${DISCORD_OAUTH_REDIRECT_URL}" ]]; then
  echo "Sealing DISCORD_OAUTH_REDIRECT_URL..."
  SEALED_DISCORD_OAUTH_REDIRECT_URL=$(seal_value "${DISCORD_OAUTH_REDIRECT_URL}")
  yq -i ".spec.encryptedData.DISCORD_OAUTH_REDIRECT_URL = \"${SEALED_DISCORD_OAUTH_REDIRECT_URL}\"" "${SEALED_SECRET_FILE}"
  PATCHED=$((PATCHED + 1))
fi

if [[ -n "${GOOGLE_OAUTH_REDIRECT_URL}" ]]; then
  echo "Sealing GOOGLE_OAUTH_REDIRECT_URL..."
  SEALED_GOOGLE_OAUTH_REDIRECT_URL=$(seal_value "${GOOGLE_OAUTH_REDIRECT_URL}")
  yq -i ".spec.encryptedData.GOOGLE_OAUTH_REDIRECT_URL = \"${SEALED_GOOGLE_OAUTH_REDIRECT_URL}\"" "${SEALED_SECRET_FILE}"
  PATCHED=$((PATCHED + 1))
fi

if [[ -n "${PWA_BASE_URL}" ]]; then
  echo "Sealing PWA_BASE_URL..."
  SEALED_PWA_BASE_URL=$(seal_value "${PWA_BASE_URL}")
  yq -i ".spec.encryptedData.PWA_BASE_URL = \"${SEALED_PWA_BASE_URL}\"" "${SEALED_SECRET_FILE}"
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
  # Validate numeric — a non-integer value would seal silently and produce a $0 fee.
  if [[ ! "${STRIPE_APPLICATION_FEE_CENTS}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: STRIPE_APPLICATION_FEE_CENTS must be a non-negative integer (got '${STRIPE_APPLICATION_FEE_CENTS}')" >&2
    exit 1
  fi
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
  # Validate numeric — a non-integer value would seal silently and produce a $0 fee.
  if [[ ! "${STRIPE_PLATFORM_SEASON_FEE_CENTS}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: STRIPE_PLATFORM_SEASON_FEE_CENTS must be a non-negative integer (got '${STRIPE_PLATFORM_SEASON_FEE_CENTS}')" >&2
    exit 1
  fi
  echo "Sealing STRIPE_PLATFORM_SEASON_FEE_CENTS..."
  SEALED_STRIPE_PLATFORM_SEASON_FEE_CENTS=$(seal_value "${STRIPE_PLATFORM_SEASON_FEE_CENTS}")
  yq -i ".spec.encryptedData.STRIPE_PLATFORM_SEASON_FEE_CENTS = \"${SEALED_STRIPE_PLATFORM_SEASON_FEE_CENTS}\"" "${SEALED_SECRET_FILE}"
  PATCHED=$((PATCHED + 1))
fi

# --- Capability-token signing keys -------------------------------------------
#
# CLUBHOUSE_GUEST_CLAIM_KEY_JSON signs the clubhouse guest-reservation
# manage/cancel tokens; SPECTATE_CLAIM_KEY_JSON signs Live Card's no-account
# guest scoring tokens. Both parse through opsevents.ParseKeyMap and both
# REQUIRE a key id of exactly "v1" (reservationClaimTokenKeyID /
# claimTokenKeyID), so the value shape is:
#
#   {"v1":"<base64 of exactly 32 random bytes>"}
#
# Generate one with:
#   CLUBHOUSE_GUEST_CLAIM_KEY_JSON="{\"v1\":\"$(openssl rand -base64 32)\"}"
#
# Keep all three key maps DISTINCT from each other and from OPS_HMAC_KEY_JSON:
# a guest reservation token must never be interchangeable with a Live Card or
# an ops one.
#
# Validated before sealing rather than after, because every failure mode here
# is silent at runtime: the backend's signer constructors return a nil signer
# for an unparseable or wrong-id key map and the affected handlers then fail
# closed with a bare 503, giving no indication that the KEY is what is wrong.
validate_claim_key_json() {
  local var_name="$1" value="$2"
  if ! printf %s "${value}" | yq -p=json -o=json '.' >/dev/null 2>&1; then
    echo "ERROR: ${var_name} is not valid JSON. Expected {\"v1\":\"<base64 32 bytes>\"}" >&2
    exit 1
  fi
  local b64
  b64="$(printf %s "${value}" | yq -p=json -o=yaml '.v1 // ""' | tr -d '[:space:]')"
  if [[ -z "${b64}" ]]; then
    echo "ERROR: ${var_name} has no \"v1\" key; the backend requires that exact key id." >&2
    exit 1
  fi
  local decoded_bytes
  decoded_bytes="$(printf %s "${b64}" | base64 -d 2>/dev/null | wc -c | tr -d '[:space:]')" || true
  if [[ "${decoded_bytes}" != "32" ]]; then
    echo "ERROR: ${var_name} key \"v1\" must decode to exactly 32 bytes (got ${decoded_bytes:-0})." >&2
    exit 1
  fi
}

if [[ -n "${CLUBHOUSE_GUEST_CLAIM_KEY_JSON}" ]]; then
  validate_claim_key_json CLUBHOUSE_GUEST_CLAIM_KEY_JSON "${CLUBHOUSE_GUEST_CLAIM_KEY_JSON}"
  echo "Sealing CLUBHOUSE_GUEST_CLAIM_KEY_JSON..."
  SEALED_CLUBHOUSE_GUEST_CLAIM_KEY_JSON=$(seal_value "${CLUBHOUSE_GUEST_CLAIM_KEY_JSON}")
  yq -i ".spec.encryptedData.CLUBHOUSE_GUEST_CLAIM_KEY_JSON = \"${SEALED_CLUBHOUSE_GUEST_CLAIM_KEY_JSON}\"" "${SEALED_SECRET_FILE}"
  PATCHED=$((PATCHED + 1))
fi

if [[ -n "${SPECTATE_CLAIM_KEY_JSON}" ]]; then
  validate_claim_key_json SPECTATE_CLAIM_KEY_JSON "${SPECTATE_CLAIM_KEY_JSON}"
  echo "Sealing SPECTATE_CLAIM_KEY_JSON..."
  SEALED_SPECTATE_CLAIM_KEY_JSON=$(seal_value "${SPECTATE_CLAIM_KEY_JSON}")
  yq -i ".spec.encryptedData.SPECTATE_CLAIM_KEY_JSON = \"${SEALED_SPECTATE_CLAIM_KEY_JSON}\"" "${SEALED_SECRET_FILE}"
  PATCHED=$((PATCHED + 1))
fi

echo "Done. Patched ${SEALED_SECRET_FILE} with ${PATCHED} key(s)."
