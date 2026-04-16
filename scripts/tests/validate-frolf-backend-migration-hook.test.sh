#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VALIDATOR_SCRIPT="$REPO_ROOT/scripts/validate-frolf-backend-migration-hook.sh"

# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

test_usage_requires_manifest_arg() {
	run_cmd bash "$VALIDATOR_SCRIPT"
	assert_status 2
	assert_output_contains "usage:"
}

test_missing_manifest_file_fails() {
	run_cmd bash "$VALIDATOR_SCRIPT" "/tmp/does-not-exist.yaml"
	assert_status 2
	assert_output_contains "manifest file not found"
}

test_valid_manifest_passes() {
	local tmpdir manifest
	tmpdir="$(mktemp -d)"
	manifest="$tmpdir/manifest.yaml"
	write_valid_manifest "$manifest"

	run_cmd bash "$VALIDATOR_SCRIPT" "$manifest"
	assert_status 0
	assert_output_contains "migration hook manifest checks passed"
	rm -rf "$tmpdir"
}

test_missing_presync_hook_fails() {
	local tmpdir manifest
	tmpdir="$(mktemp -d)"
	manifest="$tmpdir/manifest.yaml"
	write_valid_manifest "$manifest"
	sed 's/argocd.argoproj.io\/hook: PreSync/argocd.argoproj.io\/hook: Sync/' "$manifest" > "$manifest.tmp"
	mv "$manifest.tmp" "$manifest"

	run_cmd bash "$VALIDATOR_SCRIPT" "$manifest"
	assert_status 1
	assert_output_contains "missing PreSync hook annotation"
	rm -rf "$tmpdir"
}

test_auto_migrate_must_be_false() {
	local tmpdir manifest
	tmpdir="$(mktemp -d)"
	manifest="$tmpdir/manifest.yaml"
	write_valid_manifest "$manifest"
	# Scope the replacement to only the AUTO_MIGRATE value line.
	sed 's/\(AUTO_MIGRATE\)/\1/' "$manifest" \
		| awk '/name:[[:space:]]*AUTO_MIGRATE/{found=1} found && /value:/{sub(/"false"/, "\"true\""); found=0} {print}' \
		> "$manifest.tmp"
	mv "$manifest.tmp" "$manifest"

	run_cmd bash "$VALIDATOR_SCRIPT" "$manifest"
	assert_status 1
	assert_output_contains "must set AUTO_MIGRATE to \"false\""
	rm -rf "$tmpdir"
}

test_job_image_must_resolve_to_ocir_repo() {
	local tmpdir manifest
	tmpdir="$(mktemp -d)"
	manifest="$tmpdir/manifest.yaml"
	write_valid_manifest "$manifest"
	sed 's#us-ashburn-1.ocir.io/id2uwn5pyixh/frolf-bot/backend:v1.0.257#frolf-bot-backend#' "$manifest" > "$manifest.tmp"
	mv "$manifest.tmp" "$manifest"

	run_cmd bash "$VALIDATOR_SCRIPT" "$manifest"
	assert_status 1
	assert_output_contains "missing migration job image"
	rm -rf "$tmpdir"
}

test_deployment_image_must_resolve_to_ocir_repo() {
	local tmpdir manifest
	tmpdir="$(mktemp -d)"
	manifest="$tmpdir/manifest.yaml"
	write_valid_manifest "$manifest"
	awk '
		BEGIN { in_deployment=0 }
		{
			if ($0 ~ /^kind:[[:space:]]*Deployment$/) {
				in_deployment=1
			}
			if (in_deployment && $0 ~ /image:[[:space:]]*us-ashburn-1\.ocir\.io\/id2uwn5pyixh\/frolf-bot\/backend:v1\.0\.257/) {
				sub(/us-ashburn-1\.ocir\.io\/id2uwn5pyixh\/frolf-bot\/backend:v1\.0\.257/, "frolf-bot-backend")
				in_deployment=0
			}
			print
		}
	' "$manifest" > "$manifest.tmp"
	mv "$manifest.tmp" "$manifest"

	run_cmd bash "$VALIDATOR_SCRIPT" "$manifest"
	assert_status 1
	assert_output_contains "missing deployment image"
	rm -rf "$tmpdir"
}

# Regression test: validator must fail when AUTO_MIGRATE is "true" even if a
# later env var in the same deployment has value: "false". The original awk
# state-machine implementation would incorrectly pass in this case.
test_auto_migrate_true_with_other_false_env_below_must_fail() {
	local tmpdir manifest
	tmpdir="$(mktemp -d)"
	manifest="$tmpdir/manifest.yaml"
	cat > "$manifest" <<'YAML'
apiVersion: batch/v1
kind: Job
metadata:
  name: frolf-bot-backend-migrate
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
    argocd.argoproj.io/sync-wave: "-1"
spec:
  template:
    spec:
      containers:
        - name: migrate
          args:
            - migrate
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: backend-secrets
                  key: DATABASE_URL
            - name: JWT_SECRET
              valueFrom:
                secretKeyRef:
                  name: backend-secrets
                  key: JWT_SECRET
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frolf-bot-backend
spec:
  template:
    spec:
      containers:
        - name: backend
          env:
            - name: AUTO_MIGRATE
              value: "true"
            - name: OTEL_SDK_DISABLED
              value: "false"
YAML

	run_cmd bash "$VALIDATOR_SCRIPT" "$manifest"
	assert_status 1
	assert_output_contains "must set AUTO_MIGRATE to \"false\""
	rm -rf "$tmpdir"
}

tests=(
	test_usage_requires_manifest_arg
	test_missing_manifest_file_fails
	test_valid_manifest_passes
	test_missing_presync_hook_fails
	test_auto_migrate_must_be_false
	test_job_image_must_resolve_to_ocir_repo
	test_deployment_image_must_resolve_to_ocir_repo
	test_auto_migrate_true_with_other_false_env_below_must_fail
)

for test_fn in "${tests[@]}"; do
	echo "running $test_fn"
	"$test_fn"
done
