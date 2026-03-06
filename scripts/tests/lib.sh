#!/usr/bin/env bash
set -euo pipefail

RUN_STATUS=0
RUN_OUTPUT=""

run_cmd() {
	set +e
	RUN_OUTPUT="$("$@" 2>&1)"
	RUN_STATUS=$?
	set -e
}

assert_status() {
	local expected="$1"
	if [[ "$RUN_STATUS" -ne "$expected" ]]; then
		echo "expected exit status $expected, got $RUN_STATUS" >&2
		echo "$RUN_OUTPUT" >&2
		return 1
	fi
}

assert_output_contains() {
	local needle="$1"
	if ! grep -Fq -- "$needle" <<<"$RUN_OUTPUT"; then
		echo "expected output to contain: $needle" >&2
		echo "$RUN_OUTPUT" >&2
		return 1
	fi
}

assert_file_contains() {
	local file="$1"
	local needle="$2"
	if [[ ! -f "$file" ]]; then
		echo "expected file to exist: $file" >&2
		return 1
	fi
	if ! grep -Fq -- "$needle" "$file"; then
		echo "expected file $file to contain: $needle" >&2
		cat "$file" >&2
		return 1
	fi
}

assert_file_not_contains() {
	local file="$1"
	local needle="$2"
	if [[ ! -f "$file" ]]; then
		return 0
	fi
	if grep -Fq -- "$needle" "$file"; then
		echo "expected file $file to not contain: $needle" >&2
		cat "$file" >&2
		return 1
	fi
}

assert_occurrences() {
	local file="$1"
	local needle="$2"
	local expected="$3"
	local count=0
	if [[ -f "$file" ]]; then
		count="$(grep -F -c -- "$needle" "$file" || true)"
	fi
	if [[ "$count" -ne "$expected" ]]; then
		echo "expected $expected occurrences of '$needle' in $file, got $count" >&2
		if [[ -f "$file" ]]; then
			cat "$file" >&2
		fi
		return 1
	fi
}
