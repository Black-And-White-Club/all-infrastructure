#!/usr/bin/env bash
set -euo pipefail

# Helper script to generate Discord bot sealed secret
# Usage: DISCORD_TOKEN=xxx DISCORD_APP_ID=xxx NATS_DISCORD_BOT_PASSWORD=xxx ./generate-discord-secrets.sh

OUTPUT_FILE="sealed-discord-secrets.yaml"
NAMESPACE="frolf-bot"
SECRET_NAME="discord-secrets"

DISCORD_TOKEN="${DISCORD_TOKEN:-}"
DISCORD_APP_ID="${DISCORD_APP_ID:-}"
NATS_DISCORD_BOT_PASSWORD="${NATS_DISCORD_BOT_PASSWORD:-}"

if [[ -z "$DISCORD_TOKEN" ]] || [[ -z "$DISCORD_APP_ID" ]] || [[ -z "$NATS_DISCORD_BOT_PASSWORD" ]]; then
  echo "ERROR: DISCORD_TOKEN, DISCORD_APP_ID, and NATS_DISCORD_BOT_PASSWORD must be set" >&2
  exit 1
fi

NATS_URL="nats://discord-bot:${NATS_DISCORD_BOT_PASSWORD}@frolf-nats.frolf-bot.svc.cluster.local:4222"

echo "Generating raw secret..."
kubectl create secret generic ${SECRET_NAME} \
  --namespace ${NAMESPACE} \
  --from-literal=token="${DISCORD_TOKEN}" \
  --from-literal=app-id="${DISCORD_APP_ID}" \
  --from-literal=NATS_URL="${NATS_URL}" \
  --dry-run=client -o yaml > "${SECRET_NAME}.yaml"

echo "Sealing secret..."
kubeseal --format=yaml < "${SECRET_NAME}.yaml" > "${OUTPUT_FILE}"

# Clean up raw secret
rm "${SECRET_NAME}.yaml"

echo "Sealed secret created at ${OUTPUT_FILE}"
