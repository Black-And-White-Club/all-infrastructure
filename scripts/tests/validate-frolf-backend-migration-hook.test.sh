#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VALIDATOR_SCRIPT="$REPO_ROOT/scripts/validate-frolf-backend-migration-hook.sh"

# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

write_valid_manifest() {
	local file="$1"
	cat > "$file" <<'YAML'
apiVersion: batch/v1
kind: Job
metadata:
  name: frolf-bot-backend-migrate
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded
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
              value: "false"
YAML
}

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
	sed 's/value: "false"/value: "true"/' "$manifest" > "$manifest.tmp"
	mv "$manifest.tmp" "$manifest"

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
)

for test_fn in "${tests[@]}"; do
	echo "running $test_fn"
	"$test_fn"
done
