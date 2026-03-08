#!/usr/bin/env bash
set -euo pipefail

# frolf-backend migration smoke checks.
#
# Default mode is dry-run (render + manifest contract validation only).
# Use --execute to run the migration Job against a live cluster.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR_SCRIPT="$SCRIPT_DIR/validate-frolf-backend-migration-hook.sh"

OVERLAY_PATH="kustomize/frolf-backend/overlays/production"
NAMESPACE="${NAMESPACE:-frolf-bot}"
JOB_NAME="${JOB_NAME:-frolf-bot-backend-migrate}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-frolf-bot-backend}"
TIMEOUT="${TIMEOUT:-15m}"
RUNS="${RUNS:-2}"
KUBE_CONTEXT=""
EXECUTE_MODE=0
ALLOW_PROD=0

usage() {
	cat <<USAGE
Usage: $0 [options]

Options:
  --overlay <path>        Kustomize overlay path (default: $OVERLAY_PATH)
  --namespace <name>      Kubernetes namespace (default: $NAMESPACE)
  --job <name>            Migration Job name (default: $JOB_NAME)
  --deployment <name>     Backend Deployment name (default: $DEPLOYMENT_NAME)
  --timeout <duration>    kubectl wait timeout in execute mode (default: $TIMEOUT)
  --runs <n>              Number of migration job executions in execute mode (default: $RUNS)
  --context <name>        kube context to target in execute mode
  --execute               Run live Job execution against cluster
  --allow-prod            Required with --execute when context looks like prod/production
  --help                  Show this help message

Examples:
  # Safe default: dry run only (no cluster writes)
  $0

  # Dry run with explicit overlay
  $0 --overlay kustomize/frolf-backend/overlays/production

  # Live runtime smoke (run twice) against a specific context
  $0 --execute --context my-cluster --runs 2

  # Explicit prod run (requires opt-in)
  $0 --execute --context production --allow-prod
USAGE
}

require_arg() {
	local flag="$1"
	if [[ $# -lt 2 ]] || [[ -z "${2:-}" ]]; then
		echo "$flag requires a non-empty argument" >&2
		exit 2
	fi
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--overlay)
			require_arg "$1" "${2:-}"
			OVERLAY_PATH="$2"
			shift 2
			;;
		--namespace)
			require_arg "$1" "${2:-}"
			NAMESPACE="$2"
			shift 2
			;;
		--job)
			require_arg "$1" "${2:-}"
			JOB_NAME="$2"
			shift 2
			;;
		--deployment)
			require_arg "$1" "${2:-}"
			DEPLOYMENT_NAME="$2"
			shift 2
			;;
		--timeout)
			require_arg "$1" "${2:-}"
			TIMEOUT="$2"
			shift 2
			;;
		--runs)
			require_arg "$1" "${2:-}"
			RUNS="$2"
			shift 2
			;;
		--context)
			require_arg "$1" "${2:-}"
			KUBE_CONTEXT="$2"
			shift 2
			;;
		--execute)
			EXECUTE_MODE=1
			shift
			;;
		--allow-prod)
			ALLOW_PROD=1
			shift
			;;
		--help|-h)
			usage
			exit 0
			;;
		*)
			echo "Unknown option: $1" >&2
			usage
			exit 2
			;;
	esac
done

if [[ -z "$OVERLAY_PATH" ]]; then
	echo "--overlay cannot be empty" >&2
	exit 2
fi

if ! [[ "$RUNS" =~ ^[0-9]+$ ]] || [[ "$RUNS" -lt 1 ]]; then
	echo "--runs must be an integer >= 1" >&2
	exit 2
fi

if ! command -v kustomize >/dev/null 2>&1; then
	echo "kustomize is required but not installed" >&2
	exit 2
fi

if [[ ! -x "$VALIDATOR_SCRIPT" ]]; then
	echo "validator script is missing or not executable: $VALIDATOR_SCRIPT" >&2
	exit 2
fi

tmp_manifest="$(mktemp)"
tmp_job="$(mktemp)"
cleanup() {
	rm -f "$tmp_manifest" "$tmp_job"
}
trap cleanup EXIT

echo "[dry-run] rendering overlay: $OVERLAY_PATH"
kustomize build "$OVERLAY_PATH" > "$tmp_manifest"

"$VALIDATOR_SCRIPT" "$tmp_manifest"

awk -v job_name="$JOB_NAME" '
	BEGIN { RS="---" }
	$0 ~ /kind:[[:space:]]*Job/ && $0 ~ ("name:[[:space:]]*" job_name) {
		printf "---\n%s", $0
		found=1
	}
	END {
		if (!found) exit 1
	}
' "$tmp_manifest" > "$tmp_job"

if [[ ! -s "$tmp_job" ]]; then
	echo "Unable to extract migration job manifest from rendered output" >&2
	exit 1
fi

echo "[dry-run] manifest checks passed"

if [[ "$EXECUTE_MODE" -eq 0 ]]; then
	echo "Dry run complete. No cluster writes were performed."
	exit 0
fi

if ! command -v kubectl >/dev/null 2>&1; then
	echo "kubectl is required for --execute mode" >&2
	exit 2
fi

kubectl_cmd=(kubectl)
if [[ -n "$KUBE_CONTEXT" ]]; then
	kubectl_cmd+=(--context "$KUBE_CONTEXT")
else
	if ! KUBE_CONTEXT="$(${kubectl_cmd[@]} config current-context 2>/dev/null)"; then
		echo "Unable to determine current kubectl context; use --context" >&2
		exit 1
	fi
fi

normalized_context="$(tr '[:upper:]' '[:lower:]' <<<"$KUBE_CONTEXT")"
if [[ "$ALLOW_PROD" -ne 1 ]] && [[ "$normalized_context" =~ prod|production ]]; then
	echo "Refusing to run --execute against prod-like context '$KUBE_CONTEXT' without --allow-prod" >&2
	exit 1
fi

echo "[execute] context=$KUBE_CONTEXT namespace=$NAMESPACE runs=$RUNS"

for run in $(seq 1 "$RUNS"); do
	echo "[run $run/$RUNS] applying migration job $JOB_NAME in namespace $NAMESPACE"
	"${kubectl_cmd[@]}" -n "$NAMESPACE" delete job "$JOB_NAME" --ignore-not-found=true >/dev/null
	"${kubectl_cmd[@]}" -n "$NAMESPACE" apply -f "$tmp_job"
	"${kubectl_cmd[@]}" -n "$NAMESPACE" wait --for=condition=Complete "job/$JOB_NAME" --timeout="$TIMEOUT"
	echo "[run $run/$RUNS] migration job logs"
	"${kubectl_cmd[@]}" -n "$NAMESPACE" logs "job/$JOB_NAME"
done

echo "Verifying deployment $DEPLOYMENT_NAME keeps AUTO_MIGRATE=false"
if ! "${kubectl_cmd[@]}" -n "$NAMESPACE" get deployment "$DEPLOYMENT_NAME" \
	-o jsonpath='{range .spec.template.spec.containers[*].env[*]}{.name}={.value}{"\n"}{end}' \
	| grep -q '^AUTO_MIGRATE=false$'; then
	echo "ERROR: deployment/$DEPLOYMENT_NAME is missing AUTO_MIGRATE=false" >&2
	exit 1
fi

echo "frolf-backend migration smoke test passed"
