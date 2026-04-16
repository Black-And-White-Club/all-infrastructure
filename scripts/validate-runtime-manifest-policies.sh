#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-.}"
fail=0

manifest_dirs=(
	"$repo_root/kustomize"
	"$repo_root/cluster-resources"
	"$repo_root/argocd"
)

existing_manifest_dirs=()
for dir in "${manifest_dirs[@]}"; do
	if [[ -d "$dir" ]]; then
		existing_manifest_dirs+=("$dir")
	fi
done

if [[ "${#existing_manifest_dirs[@]}" -eq 0 ]]; then
	echo "ERROR: no manifest directories found under $repo_root" >&2
	exit 2
fi

if latest_hits="$(rg -n --glob '*.yaml' --glob '*.yml' 'image:[[:space:]]*[^[:space:]#]+:latest([[:space:]]|$)' "${existing_manifest_dirs[@]}" || true)" && [[ -n "$latest_hits" ]]; then
	echo "ERROR: mutable :latest image refs are not allowed in runtime manifests:" >&2
	echo "$latest_hits" >&2
	fail=1
fi

if library_hits="$(rg -n --glob '*.yaml' --glob '*.yml' 'image:[[:space:]]*docker\.io/library/' "${existing_manifest_dirs[@]}" || true)" && [[ -n "$library_hits" ]]; then
	echo "ERROR: docker.io/library fallback refs are not allowed in runtime manifests:" >&2
	echo "$library_hits" >&2
	fail=1
fi

while IFS= read -r deployment_file; do
	[[ -n "$deployment_file" ]] || continue
	if ! grep -Eq '^[[:space:]]*revisionHistoryLimit:[[:space:]]*[0-9]+' "$deployment_file"; then
		echo "ERROR: deployment manifest is missing revisionHistoryLimit: $deployment_file" >&2
		fail=1
	fi
done < <(rg -l --glob '*.yaml' --glob '*.yml' '^kind:[[:space:]]*Deployment$' "$repo_root/kustomize" "$repo_root/cluster-resources" 2>/dev/null || true)

while IFS= read -r cronjob_file; do
	[[ -n "$cronjob_file" ]] || continue
	if ! grep -Eq '^[[:space:]]*successfulJobsHistoryLimit:[[:space:]]*[0-9]+' "$cronjob_file"; then
		echo "ERROR: cronjob manifest is missing successfulJobsHistoryLimit: $cronjob_file" >&2
		fail=1
	fi
	if ! grep -Eq '^[[:space:]]*failedJobsHistoryLimit:[[:space:]]*[0-9]+' "$cronjob_file"; then
		echo "ERROR: cronjob manifest is missing failedJobsHistoryLimit: $cronjob_file" >&2
		fail=1
	fi
done < <(rg -l --glob '*.yaml' --glob '*.yml' '^kind:[[:space:]]*CronJob$' "$repo_root/cluster-resources" 2>/dev/null || true)

if [[ "$fail" -ne 0 ]]; then
	exit 1
fi

echo "runtime manifest policy checks passed for $repo_root"
