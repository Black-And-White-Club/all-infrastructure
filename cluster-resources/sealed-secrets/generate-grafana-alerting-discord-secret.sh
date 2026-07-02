#!/usr/bin/env bash
set -euo pipefail

# Generates a SealedSecret for grafana-alerting-discord in the observability namespace.
# The secret contains GRAFANA_ALERTING_DISCORD_WEBHOOK, which Grafana injects via
# envFromSecrets (charts/grafana/values.yaml) so the alerts file-provisioning YAML
# can reference it as ${GRAFANA_ALERTING_DISCORD_WEBHOOK}.
#
# Usage:
#   GRAFANA_ALERTING_DISCORD_WEBHOOK=https://discord.com/api/webhooks/... \
#   SECRETS_REPO_DIR=/path/to/all-infrastructure-secrets \
#   ./generate-grafana-alerting-discord-secret.sh
#
# The output file is written to ${SECRETS_REPO_DIR}/sealed-grafana-alerting-discord.yaml.
# Encrypt and commit to the private repo:
#   sops --encrypt --in-place "${SECRETS_REPO_DIR}/sealed-grafana-alerting-discord.yaml"
#   cd "${SECRETS_REPO_DIR}" && git add sealed-grafana-alerting-discord.yaml \
#     && git commit -m "feat(alerting): seal grafana-alerting-discord webhook"

OUTPUT_FILE="${SECRETS_REPO_DIR:-.}/sealed-grafana-alerting-discord.yaml"
NAMESPACE="observability"
SECRET_NAME="grafana-alerting-discord"

GRAFANA_ALERTING_DISCORD_WEBHOOK="${GRAFANA_ALERTING_DISCORD_WEBHOOK:-}"

if [[ -z "${GRAFANA_ALERTING_DISCORD_WEBHOOK}" ]]; then
  echo "ERROR: GRAFANA_ALERTING_DISCORD_WEBHOOK must be set." >&2
  echo "       Get the webhook URL from the Discord channel → Edit Channel → Integrations → Webhooks." >&2
  exit 1
fi

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command '$cmd' is not installed." >&2
    exit 1
  fi
}

require_command kubectl
require_command kubeseal

RAW_SECRET_FILE="$(mktemp)"
trap 'rm -f "$RAW_SECRET_FILE"' EXIT

kubectl create secret generic "${SECRET_NAME}" \
  --namespace "${NAMESPACE}" \
  --from-literal=GRAFANA_ALERTING_DISCORD_WEBHOOK="${GRAFANA_ALERTING_DISCORD_WEBHOOK}" \
  --dry-run=client -o yaml > "${RAW_SECRET_FILE}"

kubeseal --format=yaml --controller-name "${CONTROLLER_NAME:-sealed-secrets}" --controller-namespace "${CONTROLLER_NAMESPACE:-kube-system}" < "${RAW_SECRET_FILE}" > "${OUTPUT_FILE}"
echo "Sealed secret created at ${OUTPUT_FILE}"
