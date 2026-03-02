#!/usr/bin/env bash
set -euo pipefail

# Safely delete OCI block volumes that are currently UNATTACHED.
#
# Safety checks:
# 1) Candidate volumes must be lifecycle-state=AVAILABLE
# 2) Candidate volumes must have zero ATTACHED volume-attachment records
# 3) Before each deletion, checks (1) and (2) are re-run to avoid races
#
# Default mode is dry-run (no deletes). Use --execute to actually delete.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_TFVARS="${SCRIPT_DIR}/../terraform/terraform.tfvars"

COMPARTMENT_ID=""
PROFILE="${OCI_CLI_PROFILE:-DEFAULT}"
CONFIG_FILE="${OCI_CONFIG_FILE:-$HOME/.oci/config}"
DRY_RUN=1

usage() {
  cat <<'EOF'
Usage:
  delete-unattached-oci-volumes.sh [options]

Options:
  --compartment-id <ocid>  OCI compartment OCID to inspect/delete
  --tfvars <path>          Read compartment_ocid from tfvars (default: ../terraform/terraform.tfvars)
  --profile <name>         OCI CLI profile (default: DEFAULT or OCI_CLI_PROFILE)
  --config-file <path>     OCI CLI config file (default: ~/.oci/config or OCI_CONFIG_FILE)
  --execute                Perform deletes (default is dry-run)
  --dry-run                Explicit dry-run mode
  -h, --help               Show this help

Examples:
  # Dry-run only (safe)
  ./delete-unattached-oci-volumes.sh

  # Actually delete unattached volumes in this compartment
  ./delete-unattached-oci-volumes.sh --execute

  # Explicit compartment
  ./delete-unattached-oci-volumes.sh --compartment-id ocid1.compartment...
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[error] Required command not found: $1" >&2
    exit 1
  }
}

compartment_from_tfvars() {
  local tfvars_file="$1"
  if [[ ! -f "$tfvars_file" ]]; then
    return 1
  fi
  awk -F'"' '/^[[:space:]]*compartment_ocid[[:space:]]*=/{print $2; exit}' "$tfvars_file"
}

oci_json() {
  # Filter any non-JSON log lines, keeping output from the first JSON object/array.
  OCI_CONFIG_FILE="$CONFIG_FILE" OCI_CLI_PROFILE="$PROFILE" SUPPRESS_LABEL_WARNING=True \
    oci --cli-rc-file /dev/null "$@" --output json \
    | sed -n '/^[[:space:]]*[{\[]/,$p'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --compartment-id)
      COMPARTMENT_ID="${2:-}"
      shift 2
      ;;
    --tfvars)
      tfvars_path="${2:-}"
      if [[ -z "$tfvars_path" ]]; then
        echo "[error] --tfvars requires a path" >&2
        exit 1
      fi
      COMPARTMENT_ID="$(compartment_from_tfvars "$tfvars_path" || true)"
      shift 2
      ;;
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    --config-file)
      CONFIG_FILE="${2:-}"
      shift 2
      ;;
    --execute)
      DRY_RUN=0
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[error] Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_cmd oci
require_cmd jq

if [[ -z "$COMPARTMENT_ID" ]]; then
  COMPARTMENT_ID="$(compartment_from_tfvars "$DEFAULT_TFVARS" || true)"
fi

if [[ -z "$COMPARTMENT_ID" ]]; then
  echo "[error] compartment OCID is required. Pass --compartment-id or ensure $DEFAULT_TFVARS has compartment_ocid." >&2
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[error] OCI config file not found: $CONFIG_FILE" >&2
  exit 1
fi

vols_file="$(mktemp)"
atts_file="$(mktemp)"
candidates_file="$(mktemp)"
trap 'rm -f "$vols_file" "$atts_file" "$candidates_file"' EXIT

echo "[info] Profile: $PROFILE"
echo "[info] Config:  $CONFIG_FILE"
echo "[info] Compartment: $COMPARTMENT_ID"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[info] Mode: DRY-RUN (no resources will be deleted)"
else
  echo "[info] Mode: EXECUTE (unattached volumes will be deleted)"
fi

oci_json bv volume list --compartment-id "$COMPARTMENT_ID" --all > "$vols_file"
oci_json compute volume-attachment list --compartment-id "$COMPARTMENT_ID" --all > "$atts_file"

jq -r -n --slurpfile vols "$vols_file" --slurpfile atts "$atts_file" '
  ($atts[0].data
   | map(select(."lifecycle-state" == "ATTACHED"))
   | group_by(."volume-id")
   | map({key: .[0]."volume-id", value: length})
   | from_entries) as $attached_map
  | ($vols[0].data // [])
  | map(select(."lifecycle-state" == "AVAILABLE"))
  | map(. + {attached_count: ($attached_map[.id] // 0)})
  | map(select(.attached_count == 0))
  | sort_by(."time-created")
  | .[]
  | [.id, ."display-name", (."size-in-gbs" | tostring), ."time-created"]
  | @tsv
' > "$candidates_file"

candidate_count="$(wc -l < "$candidates_file" | tr -d ' ')"
echo "[info] Unattached AVAILABLE volume candidates: $candidate_count"

if [[ "$candidate_count" -eq 0 ]]; then
  echo "[info] Nothing to delete."
  exit 0
fi

echo "[info] Candidate list:"
while IFS=$'\t' read -r vol_id vol_name vol_size vol_created; do
  echo "  - $vol_name ($vol_id), size=${vol_size}Gi, created=$vol_created"
done < "$candidates_file"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[info] Dry-run complete. Re-run with --execute to delete the listed unattached volumes."
  exit 0
fi

deleted=0
skipped=0
failed=0

echo "[info] Starting safe deletion..."
while IFS=$'\t' read -r vol_id vol_name vol_size vol_created; do
  # Re-check just before delete.
  state_now="$(oci_json bv volume get --volume-id "$vol_id" | jq -r '.data."lifecycle-state"')"
  attached_now="$(oci_json compute volume-attachment list --compartment-id "$COMPARTMENT_ID" --volume-id "$vol_id" --all | jq '[.data[] | select(."lifecycle-state" == "ATTACHED")] | length')"

  if [[ "$state_now" != "AVAILABLE" || "$attached_now" -ne 0 ]]; then
    echo "[skip] $vol_name ($vol_id): state=$state_now attached=$attached_now"
    skipped=$((skipped + 1))
    continue
  fi

  echo "[delete] $vol_name ($vol_id)"
  if OCI_CONFIG_FILE="$CONFIG_FILE" OCI_CLI_PROFILE="$PROFILE" SUPPRESS_LABEL_WARNING=True \
      oci --cli-rc-file /dev/null bv volume delete --volume-id "$vol_id" --force >/dev/null; then
    deleted=$((deleted + 1))
  else
    echo "[error] Failed to delete $vol_id"
    failed=$((failed + 1))
  fi
done < "$candidates_file"

echo "[info] Completed. deleted=$deleted skipped=$skipped failed=$failed"

