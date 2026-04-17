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

# write_valid_manifest <file>
# Writes a minimal but fully valid frolf-backend rendered manifest to <file>.
# Both test suites share this fixture so it stays in sync automatically.
write_valid_manifest() {
	local file="$1"
	cat > "$file" <<'YAML'
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
          image: us-ashburn-1.ocir.io/id2uwn5pyixh/frolf-bot/backend:v1.0.257
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
          image: us-ashburn-1.ocir.io/id2uwn5pyixh/frolf-bot/backend:v1.0.257
          env:
            - name: AUTO_MIGRATE
              value: "false"
            - name: TRUSTED_PROXY_CIDRS
              valueFrom:
                secretKeyRef:
                  name: backend-secrets
                  key: TRUSTED_PROXY_CIDRS
                  optional: true
YAML
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
