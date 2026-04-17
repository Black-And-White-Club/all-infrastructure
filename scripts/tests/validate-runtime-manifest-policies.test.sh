#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VALIDATOR_SCRIPT="$REPO_ROOT/scripts/validate-runtime-manifest-policies.sh"

# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

write_valid_repo_fixture() {
	local repo_root="$1"
	mkdir -p "$repo_root/kustomize/sample/base" "$repo_root/cluster-resources/jobs" "$repo_root/argocd"
	cat > "$repo_root/kustomize/sample/base/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
spec:
  revisionHistoryLimit: 3
  template:
    spec:
      containers:
        - name: sample-app
          image: us-ashburn-1.ocir.io/id2uwn5pyixh/sample/app:v1.2.3
          env:
            - name: TRUSTED_PROXY_CIDRS
              valueFrom:
                secretKeyRef:
                  name: sample-secrets
                  key: TRUSTED_PROXY_CIDRS
                  optional: true
YAML
	cat > "$repo_root/cluster-resources/jobs/sample-cronjob.yaml" <<'YAML'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: sample-job
spec:
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: sample-job
              image: bitnamilegacy/kubectl:1.31.4-debian-12-r0
YAML
}

test_valid_repo_passes() {
	local tmpdir
	tmpdir="$(mktemp -d)"
	write_valid_repo_fixture "$tmpdir"

	run_cmd bash "$VALIDATOR_SCRIPT" "$tmpdir"
	assert_status 0
	assert_output_contains "runtime manifest policy checks passed"
	rm -rf "$tmpdir"
}

test_latest_image_fails() {
	local tmpdir
	tmpdir="$(mktemp -d)"
	write_valid_repo_fixture "$tmpdir"
	sed -i.bak 's#us-ashburn-1.ocir.io/id2uwn5pyixh/sample/app:v1.2.3#us-ashburn-1.ocir.io/id2uwn5pyixh/sample/app:latest#' "$tmpdir/kustomize/sample/base/deployment.yaml"

	run_cmd bash "$VALIDATOR_SCRIPT" "$tmpdir"
	assert_status 1
	assert_output_contains "mutable :latest image refs"
	rm -rf "$tmpdir"
}

test_library_image_fails() {
	local tmpdir
	tmpdir="$(mktemp -d)"
	write_valid_repo_fixture "$tmpdir"
	sed -i.bak 's#bitnamilegacy/kubectl:1.31.4-debian-12-r0#docker.io/library/frolf-bot-backend:latest#' "$tmpdir/cluster-resources/jobs/sample-cronjob.yaml"

	run_cmd bash "$VALIDATOR_SCRIPT" "$tmpdir"
	assert_status 1
	assert_output_contains "docker.io/library fallback refs"
	rm -rf "$tmpdir"
}

test_missing_revision_history_limit_fails() {
	local tmpdir
	tmpdir="$(mktemp -d)"
	write_valid_repo_fixture "$tmpdir"
	sed -i.bak '/revisionHistoryLimit:/d' "$tmpdir/kustomize/sample/base/deployment.yaml"

	run_cmd bash "$VALIDATOR_SCRIPT" "$tmpdir"
	assert_status 1
	assert_output_contains "missing revisionHistoryLimit"
	rm -rf "$tmpdir"
}

test_missing_cronjob_history_limits_fail() {
	local tmpdir
	tmpdir="$(mktemp -d)"
	write_valid_repo_fixture "$tmpdir"
	sed -i.bak '/successfulJobsHistoryLimit:/d;/failedJobsHistoryLimit:/d' "$tmpdir/cluster-resources/jobs/sample-cronjob.yaml"

	run_cmd bash "$VALIDATOR_SCRIPT" "$tmpdir"
	assert_status 1
	assert_output_contains "missing successfulJobsHistoryLimit"
	assert_output_contains "missing failedJobsHistoryLimit"
	rm -rf "$tmpdir"
}

test_trusted_proxy_secret_ref_must_be_optional() {
	local tmpdir
	tmpdir="$(mktemp -d)"
	write_valid_repo_fixture "$tmpdir"
	sed -i.bak '/optional: true/d' "$tmpdir/kustomize/sample/base/deployment.yaml"

	run_cmd bash "$VALIDATOR_SCRIPT" "$tmpdir"
	assert_status 1
	assert_output_contains "TRUSTED_PROXY_CIDRS secret refs must set optional: true"
	rm -rf "$tmpdir"
}

tests=(
	test_valid_repo_passes
	test_latest_image_fails
	test_library_image_fails
	test_missing_revision_history_limit_fails
	test_missing_cronjob_history_limits_fail
	test_trusted_proxy_secret_ref_must_be_optional
)

for test_fn in "${tests[@]}"; do
	echo "running $test_fn"
	"$test_fn"
done
