#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Generate a docker-registry secret for OCI (OCIR) and seal it with kubeseal.
The resulting YAML is ready to commit under all-infrastructure/cluster-resources/sealed-secrets.

Options:
  --namespace NAME                Kubernetes namespace that will consume the secret (default: resume-app)
  --output FILE                   Output path for the sealed secret YAML (default: "$SCRIPT_DIR/ocir-secret-<namespace>-sealed.yaml")
  --secret-name NAME              Kubernetes Secret name (default: ocir-secret)
  --registry HOSTNAME             OCIR registry host (default: us-ashburn-1.ocir.io or set OCIR_REGISTRY/OCIR_REGION)
  --username USERNAME             Username to authenticate against OCIR (required, defaults to OCIR_USERNAME env)
  --password TOKEN               Password or auth token for OCIR (required, defaults to OCIR_AUTH_TOKEN || OCIR_PASSWORD)
  --email EMAIL                   Email for the dockerconfigjson (default: no-reply@black-and-white.club)
  --controller-namespace NAME     SealedSecrets controller namespace (default: kube-system)
  --controller-name NAME          SealedSecrets controller name (default: sealed-secrets)
  --kubeconfig PATH              kubeconfig file to pass to kubectl/kubeseal (defaults to value of KUBECONFIG environment variable)
  --kubeseal-arg ARG              Additional argument to pass to kubeseal (can be repeated)
  -h, --help                      Show this help
EOF
}

NAMESPACE="resume-app"
SECRET_NAME="ocir-secret"
REGISTRY="${OCIR_REGISTRY:-${OCIR_REGION:-us-ashburn-1.ocir.io}}"
EMAIL="${OCIR_EMAIL:-no-reply@black-and-white.club}"
CONTROLLER_NAMESPACE="kube-system"
CONTROLLER_NAME="sealed-secrets-controller"
OUTPUT=""
KUBE_CONFIG_FILE=""
KUBESEAL_EXTRA_ARGS=()
KUBECTL_KUBECONFIG_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    --secret-name)
      SECRET_NAME="$2"
      shift 2
      ;;
    --registry)
      REGISTRY="$2"
      shift 2
      ;;
    --username)
      OCIR_USERNAME_OVERRIDE="$2"
      shift 2
      ;;
    --password)
      OCIR_PASSWORD_OVERRIDE="$2"
      shift 2
      ;;
    --email)
      EMAIL="$2"
      shift 2
      ;;
    --controller-namespace)
      CONTROLLER_NAMESPACE="$2"
      shift 2
      ;;
    --controller-name)
      CONTROLLER_NAME="$2"
      shift 2
      ;;
    --kubeconfig)
      KUBE_CONFIG_FILE="$2"
      shift 2
      ;;
    --kubeseal-arg)
      KUBESEAL_EXTRA_ARGS+=("$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

USERNAME="${OCIR_USERNAME_OVERRIDE:-${OCIR_USERNAME:-}}"
PASSWORD="${OCIR_PASSWORD_OVERRIDE:-${OCIR_AUTH_TOKEN:-${OCIR_PASSWORD:-}}}"

if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
  echo "ERROR: You must provide both --username and --password (or set OCIR_USERNAME and OCIR_AUTH_TOKEN / OCIR_PASSWORD)" >&2
  usage
  exit 1
fi

if [[ -z "$OUTPUT" ]]; then
  OUTPUT="$SCRIPT_DIR/ocir-secret-${NAMESPACE}-sealed.yaml"
fi

KUBECTL_KUBECONFIG_ARGS=()
KUBESEAL_KUBECONFIG_ARGS=()
if [[ -n "$KUBE_CONFIG_FILE" ]]; then
  KUBECTL_KUBECONFIG_ARGS+=("--kubeconfig" "$KUBE_CONFIG_FILE")
  KUBESEAL_KUBECONFIG_ARGS+=("--kubeconfig" "$KUBE_CONFIG_FILE")
elif [[ -n "${KUBECONFIG:-}" ]]; then
  KUBECTL_KUBECONFIG_ARGS+=("--kubeconfig" "$KUBECONFIG")
  KUBESEAL_KUBECONFIG_ARGS+=("--kubeconfig" "$KUBECONFIG")
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl is required" >&2
  exit 1
fi
if ! command -v kubeseal >/dev/null 2>&1; then
  echo "ERROR: kubeseal is required" >&2
  exit 1
fi

PLAIN_SECRET_FILE="$(mktemp)"
trap 'rm -f "$PLAIN_SECRET_FILE"' EXIT

kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" create secret docker-registry "$SECRET_NAME" \
  -n "$NAMESPACE" \
  --docker-server="$REGISTRY" \
  --docker-username="$USERNAME" \
  --docker-password="$PASSWORD" \
  --docker-email="$EMAIL" \
  --dry-run=client -o yaml > "$PLAIN_SECRET_FILE"

KUBESEAL_ARGS=("--format=yaml" "--controller-name" "$CONTROLLER_NAME" "--controller-namespace" "$CONTROLLER_NAMESPACE")
KUBESEAL_ARGS+=("${KUBESEAL_EXTRA_ARGS[@]:-}")
KUBESEAL_ARGS+=("${KUBESEAL_KUBECONFIG_ARGS[@]:-}")

kubeseal "${KUBESEAL_ARGS[@]}" < "$PLAIN_SECRET_FILE" > "$OUTPUT"

cat <<EOF
Sealed OCI pull secret written to: $OUTPUT
Remember to commit this file (and keep the plaintext YAML out of git).
EOF
