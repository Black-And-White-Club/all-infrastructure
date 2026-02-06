#!/usr/bin/env bash
set -euo pipefail

# Helper script to generate NATS credentials sealed secret
# Usage: NATS_AUTH_SERVICE_PASSWORD=xxx NATS_SYS_PASSWORD=xxx NATS_DISCORD_BOT_PASSWORD=xxx ./generate-nats-secrets.sh

OUTPUT_FILE="sealed-nats-secrets.yaml"
NAMESPACE="frolf-bot"
SECRET_NAME="nats-secrets"

NATS_AUTH_SERVICE_PASSWORD="${NATS_AUTH_SERVICE_PASSWORD:-}"
NATS_SYS_PASSWORD="${NATS_SYS_PASSWORD:-}"
NATS_DISCORD_BOT_PASSWORD="${NATS_DISCORD_BOT_PASSWORD:-}"

if [[ -z "$NATS_AUTH_SERVICE_PASSWORD" ]] || [[ -z "$NATS_SYS_PASSWORD" ]] || [[ -z "$NATS_DISCORD_BOT_PASSWORD" ]]; then
  echo "ERROR: NATS_AUTH_SERVICE_PASSWORD, NATS_SYS_PASSWORD, and NATS_DISCORD_BOT_PASSWORD must be set" >&2
  exit 1
fi

echo "Generating raw secret..."
kubectl create secret generic ${SECRET_NAME} \
  --namespace ${NAMESPACE} \
  --from-literal=NATS_AUTH_SERVICE_PASSWORD="${NATS_AUTH_SERVICE_PASSWORD}" \
  --from-literal=NATS_SYS_PASSWORD="${NATS_SYS_PASSWORD}" \
  --from-literal=NATS_DISCORD_BOT_PASSWORD="${NATS_DISCORD_BOT_PASSWORD}" \
  --dry-run=client -o yaml > "${SECRET_NAME}.yaml"

echo "Sealing secret..."
kubeseal --format=yaml < "${SECRET_NAME}.yaml" > "${OUTPUT_FILE}"

# Clean up raw secret
rm "${SECRET_NAME}.yaml"

echo "Sealed secret created at ${OUTPUT_FILE}"
