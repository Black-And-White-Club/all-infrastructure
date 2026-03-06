#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
	echo "usage: $0 <rendered-manifest.yaml>" >&2
	exit 2
fi

manifest="$1"
if [[ ! -f "$manifest" ]]; then
	echo "ERROR: manifest file not found: $manifest" >&2
	exit 2
fi

extract_doc() {
	local kind="$1"
	local name="$2"
	local file="$3"
	awk -v kind="$kind" -v name="$name" '
		BEGIN { RS="---"; found=0 }
		$0 ~ ("kind:[[:space:]]*" kind) && $0 ~ ("name:[[:space:]]*" name) {
			print
			found=1
			exit 0
		}
		END {
			if (!found) exit 1
		}
	' "$file"
}

require_contains() {
	local haystack="$1"
	local needle="$2"
	local label="$3"
	if ! grep -Fq -- "$needle" <<<"$haystack"; then
		echo "ERROR: missing $label ('$needle')" >&2
		return 1
	fi
	return 0
}

failed=0

if ! job_doc="$(extract_doc "Job" "frolf-bot-backend-migrate" "$manifest")"; then
	echo "ERROR: rendered manifest is missing Job/frolf-bot-backend-migrate" >&2
	exit 1
fi

require_contains "$job_doc" "argocd.argoproj.io/hook: PreSync" "PreSync hook annotation" || failed=1
require_contains "$job_doc" "argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded" "hook delete policy" || failed=1
require_contains "$job_doc" "argocd.argoproj.io/sync-wave: \"-1\"" "sync wave" || failed=1
require_contains "$job_doc" "name: migrate" "migration container" || failed=1
require_contains "$job_doc" "- migrate" "migration container args" || failed=1
require_contains "$job_doc" "name: DATABASE_URL" "DATABASE_URL env var" || failed=1
require_contains "$job_doc" "name: JWT_SECRET" "JWT_SECRET env var" || failed=1

if ! deploy_doc="$(extract_doc "Deployment" "frolf-bot-backend" "$manifest")"; then
	echo "ERROR: rendered manifest is missing Deployment/frolf-bot-backend" >&2
	exit 1
fi

if ! awk '
	$0 ~ /name:[[:space:]]*AUTO_MIGRATE/ {
		seen=1
		next
	}
	seen && $0 ~ /value:[[:space:]]*"false"/ {
		ok=1
		exit 0
	}
	END {
		exit !(seen && ok)
	}
' <<<"$deploy_doc"; then
	echo "ERROR: Deployment/frolf-bot-backend must set AUTO_MIGRATE to \"false\"" >&2
	failed=1
fi

if [[ $failed -ne 0 ]]; then
	exit 1
fi

echo "frolf-backend migration hook manifest checks passed"
