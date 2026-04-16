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

search_manifest_matches() {
	local pattern="$1"
	shift

	if [[ "$#" -eq 0 ]]; then
		return 0
	fi

	grep -RInE --include='*.yaml' --include='*.yml' "$pattern" "$@" || true
}

list_manifest_files() {
	local pattern="$1"
	shift

	if [[ "$#" -eq 0 ]]; then
		return 0
	fi

	grep -RIlE --include='*.yaml' --include='*.yml' "$pattern" "$@" || true
}

if [[ "${#existing_manifest_dirs[@]}" -eq 0 ]]; then
	echo "ERROR: no manifest directories found under $repo_root" >&2
	exit 2
fi

if latest_hits="$(search_manifest_matches 'image:[[:space:]]*[^[:space:]#]+:latest([[:space:]]|$)' "${existing_manifest_dirs[@]}")" && [[ -n "$latest_hits" ]]; then
	echo "ERROR: mutable :latest image refs are not allowed in runtime manifests:" >&2
	echo "$latest_hits" >&2
	fail=1
fi

if library_hits="$(search_manifest_matches 'image:[[:space:]]*docker\.io/library/' "${existing_manifest_dirs[@]}")" && [[ -n "$library_hits" ]]; then
	echo "ERROR: docker.io/library fallback refs are not allowed in runtime manifests:" >&2
	echo "$library_hits" >&2
	fail=1
fi

deployment_manifest_dirs=()
for dir in "$repo_root/kustomize" "$repo_root/cluster-resources"; do
	if [[ -d "$dir" ]]; then
		deployment_manifest_dirs+=("$dir")
	fi
done

while IFS= read -r deployment_file; do
	[[ -n "$deployment_file" ]] || continue
	if ! grep -Eq '^[[:space:]]*revisionHistoryLimit:[[:space:]]*[0-9]+' "$deployment_file"; then
		echo "ERROR: deployment manifest is missing revisionHistoryLimit: $deployment_file" >&2
		fail=1
	fi
done < <(list_manifest_files '^kind:[[:space:]]*Deployment$' "${deployment_manifest_dirs[@]}")

cronjob_manifest_dirs=()
if [[ -d "$repo_root/cluster-resources" ]]; then
	cronjob_manifest_dirs+=("$repo_root/cluster-resources")
fi

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
done < <(list_manifest_files '^kind:[[:space:]]*CronJob$' "${cronjob_manifest_dirs[@]}")

if [[ "$fail" -ne 0 ]]; then
	exit 1
fi

echo "runtime manifest policy checks passed for $repo_root"
