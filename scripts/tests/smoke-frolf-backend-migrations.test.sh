#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SMOKE_SCRIPT="$REPO_ROOT/scripts/smoke-frolf-backend-migrations.sh"

# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

ORIGINAL_PATH="$PATH"

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

write_fake_kustomize() {
	local fake_bin="$1"
	cat > "$fake_bin/kustomize" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" != "build" ]]; then
	echo "unexpected kustomize args: $*" >&2
	exit 9
fi
cat "$FAKE_MANIFEST_PATH"
SCRIPT
	chmod +x "$fake_bin/kustomize"
}

write_fake_kubectl() {
	local fake_bin="$1"
	cat > "$fake_bin/kubectl" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${FAKE_KUBECTL_LOG:?FAKE_KUBECTL_LOG is required}"
if [[ "${FAKE_KUBECTL_FAIL_ON_CALL:-0}" -eq 1 ]]; then
	echo "kubectl should not be called in this test" >&2
	exit 99
fi
if [[ "$*" == *"config current-context"* ]]; then
	printf '%s\n' "${FAKE_KUBE_CONTEXT:-dev}"
	exit 0
fi
if [[ "$*" == *"get deployment"* ]]; then
	printf '%s\n' "${FAKE_KUBECTL_GET_DEPLOYMENT_OUTPUT:-AUTO_MIGRATE=false}"
	exit 0
fi
exit 0
SCRIPT
	chmod +x "$fake_bin/kubectl"
}

test_dry_run_default_does_not_call_kubectl() {
	local tmpdir fake_bin overlay_dir manifest log_file
	tmpdir="$(mktemp -d)"
	fake_bin="$tmpdir/bin"
	overlay_dir="$tmpdir/overlay"
	manifest="$tmpdir/rendered.yaml"
	log_file="$tmpdir/kubectl.log"

	mkdir -p "$fake_bin" "$overlay_dir"
	write_valid_manifest "$manifest"
	write_fake_kustomize "$fake_bin"
	write_fake_kubectl "$fake_bin"

	export FAKE_MANIFEST_PATH="$manifest"
	export FAKE_KUBECTL_LOG="$log_file"
	export FAKE_KUBECTL_FAIL_ON_CALL=1

	PATH="$fake_bin:$ORIGINAL_PATH"
	run_cmd bash "$SMOKE_SCRIPT" --overlay "$overlay_dir"

	assert_status 0
	assert_output_contains "[dry-run] manifest checks passed"
	assert_output_contains "Dry run complete. No cluster writes were performed."
	PATH="$ORIGINAL_PATH"
	rm -rf "$tmpdir"
}

test_execute_prod_context_requires_allow_prod() {
	local tmpdir fake_bin overlay_dir manifest log_file
	tmpdir="$(mktemp -d)"
	fake_bin="$tmpdir/bin"
	overlay_dir="$tmpdir/overlay"
	manifest="$tmpdir/rendered.yaml"
	log_file="$tmpdir/kubectl.log"

	mkdir -p "$fake_bin" "$overlay_dir"
	write_valid_manifest "$manifest"
	write_fake_kustomize "$fake_bin"
	write_fake_kubectl "$fake_bin"

	export FAKE_MANIFEST_PATH="$manifest"
	export FAKE_KUBECTL_LOG="$log_file"
	export FAKE_KUBE_CONTEXT="production"
	unset FAKE_KUBECTL_FAIL_ON_CALL

	PATH="$fake_bin:$ORIGINAL_PATH"
	run_cmd bash "$SMOKE_SCRIPT" --overlay "$overlay_dir" --execute --runs 1

	assert_status 1
	assert_output_contains "without --allow-prod"
	assert_file_contains "$log_file" "config current-context"
	assert_file_not_contains "$log_file" "apply -f"
	PATH="$ORIGINAL_PATH"
	rm -rf "$tmpdir"
}

test_execute_with_allow_prod_runs_expected_kubectl_calls() {
	local tmpdir fake_bin overlay_dir manifest log_file
	tmpdir="$(mktemp -d)"
	fake_bin="$tmpdir/bin"
	overlay_dir="$tmpdir/overlay"
	manifest="$tmpdir/rendered.yaml"
	log_file="$tmpdir/kubectl.log"

	mkdir -p "$fake_bin" "$overlay_dir"
	write_valid_manifest "$manifest"
	write_fake_kustomize "$fake_bin"
	write_fake_kubectl "$fake_bin"

	export FAKE_MANIFEST_PATH="$manifest"
	export FAKE_KUBECTL_LOG="$log_file"
	export FAKE_KUBE_CONTEXT="production"
	unset FAKE_KUBECTL_FAIL_ON_CALL

	PATH="$fake_bin:$ORIGINAL_PATH"
	run_cmd bash "$SMOKE_SCRIPT" \
		--overlay "$overlay_dir" \
		--execute \
		--context production \
		--allow-prod \
		--runs 2

	assert_status 0
	assert_output_contains "frolf-backend migration smoke test passed"
	assert_occurrences "$log_file" "delete job frolf-bot-backend-migrate" 2
	assert_occurrences "$log_file" "apply -f" 2
	assert_occurrences "$log_file" "wait --for=condition=Complete job/frolf-bot-backend-migrate" 2
	assert_occurrences "$log_file" "logs job/frolf-bot-backend-migrate" 2
	assert_occurrences "$log_file" "get deployment frolf-bot-backend" 1
	PATH="$ORIGINAL_PATH"
	rm -rf "$tmpdir"
}

test_runs_must_be_positive_integer() {
	run_cmd bash "$SMOKE_SCRIPT" --runs 0
	assert_status 2
	assert_output_contains "--runs must be an integer >= 1"
}

tests=(
	test_dry_run_default_does_not_call_kubectl
	test_execute_prod_context_requires_allow_prod
	test_execute_with_allow_prod_runs_expected_kubectl_calls
	test_runs_must_be_positive_integer
)

for test_fn in "${tests[@]}"; do
	echo "running $test_fn"
	"$test_fn"
done
