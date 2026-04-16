#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VALIDATOR_SCRIPT="$REPO_ROOT/scripts/validate-production-overlay-images.sh"

# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

write_valid_overlay_fixture() {
	local overlay_file="$1"
	cat > "$overlay_file" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
images:
  - name: sample-app
    newName: us-ashburn-1.ocir.io/id2uwn5pyixh/sample/app
    newTag: v1.2.3
YAML
}

write_valid_render_fixture() {
	local render_file="$1"
	cat > "$render_file" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
spec:
  template:
    spec:
      containers:
        - name: sample-app
          image: us-ashburn-1.ocir.io/id2uwn5pyixh/sample/app:v1.2.3
YAML
}

test_usage_requires_two_args() {
	run_cmd bash "$VALIDATOR_SCRIPT"
	assert_status 2
	assert_output_contains "usage:"
}

test_missing_overlay_file_fails() {
	run_cmd bash "$VALIDATOR_SCRIPT" /tmp/missing-overlay.yaml /tmp/missing-render.yaml
	assert_status 2
	assert_output_contains "overlay file not found"
}

test_valid_overlay_and_render_pass() {
	local tmpdir overlay render
	tmpdir="$(mktemp -d)"
	overlay="$tmpdir/kustomization.yaml"
	render="$tmpdir/rendered.yaml"
	write_valid_overlay_fixture "$overlay"
	write_valid_render_fixture "$render"

	run_cmd bash "$VALIDATOR_SCRIPT" "$overlay" "$render"
	assert_status 0
	assert_output_contains "production overlay image mapping checks passed"
	rm -rf "$tmpdir"
}

test_duplicate_image_entries_fail() {
	local tmpdir overlay render
	tmpdir="$(mktemp -d)"
	overlay="$tmpdir/kustomization.yaml"
	render="$tmpdir/rendered.yaml"
	write_valid_overlay_fixture "$overlay"
	write_valid_render_fixture "$render"
	cat >> "$overlay" <<'YAML'
  - name: sample-app-extra
    newName: us-ashburn-1.ocir.io/id2uwn5pyixh/sample/extra
    newTag: v9.9.9
YAML

	run_cmd bash "$VALIDATOR_SCRIPT" "$overlay" "$render"
	assert_status 1
	assert_output_contains "exactly one updater-owned image entry"
	rm -rf "$tmpdir"
}

test_missing_new_name_fails() {
	local tmpdir overlay render
	tmpdir="$(mktemp -d)"
	overlay="$tmpdir/kustomization.yaml"
	render="$tmpdir/rendered.yaml"
	write_valid_overlay_fixture "$overlay"
	write_valid_render_fixture "$render"
	sed '/newName:/d' "$overlay" > "$overlay.tmp"
	mv "$overlay.tmp" "$overlay"

	run_cmd bash "$VALIDATOR_SCRIPT" "$overlay" "$render"
	assert_status 1
	assert_output_contains "must define newName"
	rm -rf "$tmpdir"
}

test_fully_qualified_overlay_name_fails() {
	local tmpdir overlay render
	tmpdir="$(mktemp -d)"
	overlay="$tmpdir/kustomization.yaml"
	render="$tmpdir/rendered.yaml"
	write_valid_overlay_fixture "$overlay"
	write_valid_render_fixture "$render"
	sed 's/name: sample-app/name: us-ashburn-1.ocir.io\/id2uwn5pyixh\/sample\/app/' "$overlay" > "$overlay.tmp"
	mv "$overlay.tmp" "$overlay"

	run_cmd bash "$VALIDATOR_SCRIPT" "$overlay" "$render"
	assert_status 1
	assert_output_contains "must be a placeholder"
	rm -rf "$tmpdir"
}

test_placeholder_leak_in_render_fails() {
	local tmpdir overlay render
	tmpdir="$(mktemp -d)"
	overlay="$tmpdir/kustomization.yaml"
	render="$tmpdir/rendered.yaml"
	write_valid_overlay_fixture "$overlay"
	write_valid_render_fixture "$render"
	sed 's#us-ashburn-1.ocir.io/id2uwn5pyixh/sample/app:v1.2.3#sample-app#' "$render" > "$render.tmp"
	mv "$render.tmp" "$render"

	run_cmd bash "$VALIDATOR_SCRIPT" "$overlay" "$render"
	assert_status 1
	assert_output_contains "still contains placeholder image"
	rm -rf "$tmpdir"
}

tests=(
	test_usage_requires_two_args
	test_missing_overlay_file_fails
	test_valid_overlay_and_render_pass
	test_duplicate_image_entries_fail
	test_missing_new_name_fails
	test_fully_qualified_overlay_name_fails
	test_placeholder_leak_in_render_fails
)

for test_fn in "${tests[@]}"; do
	echo "running $test_fn"
	"$test_fn"
done
