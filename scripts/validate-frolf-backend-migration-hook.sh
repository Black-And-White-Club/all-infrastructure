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

require_optional_env_secret_ref() {
	local haystack="$1"
	local env_name="$2"
	local label="$3"

	if ! grep -Fq -- "name: ${env_name}" <<<"$haystack"; then
		return 0
	fi

	if ! awk -v env_name="$env_name" '
		BEGIN { in_target=0; found=0; ok=0 }
		/^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ {
			if (in_target) {
				exit(ok ? 0 : 1)
			}
			if ($0 ~ ("^[[:space:]]*-[[:space:]]*name:[[:space:]]*" env_name "([[:space:]]|$)")) {
				in_target=1
				found=1
			}
			next
		}
		in_target && /^[[:space:]]*optional:[[:space:]]*true([[:space:]]|$)/ {
			ok=1
		}
		END {
			if (!found || ok) {
				exit 0
			}
			exit 1
		}
	' <<<"$haystack"; then
		echo "ERROR: ${label} must set optional: true" >&2
		return 1
	fi

	return 0
}

failed=0
expected_image_repo="us-ashburn-1.ocir.io/id2uwn5pyixh/frolf-bot/backend"

if ! job_doc="$(extract_doc "Job" "frolf-bot-backend-migrate" "$manifest")"; then
	echo "ERROR: rendered manifest is missing Job/frolf-bot-backend-migrate" >&2
	exit 1
fi

require_contains "$job_doc" "argocd.argoproj.io/hook: PreSync" "PreSync hook annotation" || failed=1
require_contains "$job_doc" "argocd.argoproj.io/hook-delete-policy: BeforeHookCreation" "hook delete policy" || failed=1
require_contains "$job_doc" "argocd.argoproj.io/sync-wave: \"-1\"" "sync wave" || failed=1
require_contains "$job_doc" "name: migrate" "migration container" || failed=1
require_contains "$job_doc" "- migrate" "migration container args" || failed=1
require_contains "$job_doc" "name: DATABASE_URL" "DATABASE_URL env var" || failed=1
require_contains "$job_doc" "name: JWT_SECRET" "JWT_SECRET env var" || failed=1
require_contains "$job_doc" "image: ${expected_image_repo}:" "migration job image" || failed=1

if ! deploy_doc="$(extract_doc "Deployment" "frolf-bot-backend" "$manifest")"; then
	echo "ERROR: rendered manifest is missing Deployment/frolf-bot-backend" >&2
	exit 1
fi

# Check that AUTO_MIGRATE is set to "false" by inspecting the line immediately
# following "name: AUTO_MIGRATE". Using grep -A1 avoids the awk state-machine
# bug where any later env var with value: "false" would satisfy the check.
if ! printf '%s\n' "$deploy_doc" \
	| grep -A1 'name:[[:space:]]*AUTO_MIGRATE' \
	| grep -q 'value:[[:space:]]*"false"'; then
	echo "ERROR: Deployment/frolf-bot-backend must set AUTO_MIGRATE to \"false\"" >&2
	failed=1
fi

require_contains "$deploy_doc" "image: ${expected_image_repo}:" "deployment image" || failed=1
require_optional_env_secret_ref "$deploy_doc" "TRUSTED_PROXY_CIDRS" "Deployment/frolf-bot-backend TRUSTED_PROXY_CIDRS secret ref" || failed=1

if [[ $failed -ne 0 ]]; then
	exit 1
fi

echo "frolf-backend migration hook manifest checks passed"
