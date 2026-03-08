#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

test_scripts=()
while IFS= read -r test_script; do
	test_scripts+=("$test_script")
done < <(find "$SCRIPT_DIR" -maxdepth 1 -type f -name "*.test.sh" | sort)

if [[ "${#test_scripts[@]}" -eq 0 ]]; then
	echo "no script tests found in $SCRIPT_DIR" >&2
	exit 1
fi

for test_script in "${test_scripts[@]}"; do
	echo "==> $(basename "$test_script")"
	bash "$test_script"
done

echo "all script tests passed"
