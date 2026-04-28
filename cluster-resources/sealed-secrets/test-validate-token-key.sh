#!/usr/bin/env bash
set -euo pipefail

# Smoke test for TOKEN_ENCRYPTION_KEY length validation in
# generate-frolf-backend-secrets.sh and patch-frolf-backend-secrets.sh.
# Stubs kubectl/kubeseal/yq so the test runs without a cluster.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATE="${SCRIPT_DIR}/generate-frolf-backend-secrets.sh"
PATCH="${SCRIPT_DIR}/patch-frolf-backend-secrets.sh"

STUB_DIR="$(mktemp -d)"
trap 'rm -rf "$STUB_DIR"' EXIT

for cmd in kubectl kubeseal yq; do
  cat >"${STUB_DIR}/${cmd}" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "${STUB_DIR}/${cmd}"
done

KEY_32="abcdefghijklmnopqrstuvwxyz012345"
KEY_31="abcdefghijklmnopqrstuvwxyz01234"
KEY_33="abcdefghijklmnopqrstuvwxyz0123456"

run_generate() {
  local key="$1" prev="${2:-}"
  PATH="${STUB_DIR}:${PATH}" \
    DB_PASSWORD=x NATS_AUTH_PASSWORD=x AUTH_CALLOUT_ISSUER_NKEY=x \
    AUTH_CALLOUT_SIGNING_NKEY=x AUTH_CALLOUT_SERVER_PUBLIC_KEY=x \
    JWT_SECRET=x TOKEN_ENCRYPTION_KEY="$key" TOKEN_ENCRYPTION_KEY_PREVIOUS="$prev" \
    DISCORD_OAUTH_CLIENT_ID=x DISCORD_OAUTH_CLIENT_SECRET=x \
    GOOGLE_OAUTH_CLIENT_ID=x GOOGLE_OAUTH_CLIENT_SECRET=x \
    bash "$GENERATE" "${STUB_DIR}/out.yaml"
}

run_patch() {
  local key="$1" prev="${2:-}"
  local f="${STUB_DIR}/sealed.yaml"
  : >"$f"
  PATH="${STUB_DIR}:${PATH}" \
    TOKEN_ENCRYPTION_KEY="$key" TOKEN_ENCRYPTION_KEY_PREVIOUS="$prev" \
    bash "$PATCH" "$f"
}

expect_fail() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "FAIL: ${label} should have exited non-zero" >&2
    exit 1
  fi
  echo "ok: ${label} rejected"
}

expect_pass() {
  local label="$1"; shift
  if ! "$@" >/dev/null 2>&1; then
    echo "FAIL: ${label} should have succeeded" >&2
    "$@" || true
    exit 1
  fi
  echo "ok: ${label} accepted"
}

expect_fail "generate 31-byte key"      run_generate "$KEY_31"
expect_fail "generate 33-byte key"      run_generate "$KEY_33"
expect_fail "generate 31-byte previous" run_generate "$KEY_32" "$KEY_31"
expect_pass "generate 32-byte key"      run_generate "$KEY_32"
expect_pass "generate 32-byte + prev"   run_generate "$KEY_32" "$KEY_32"

expect_fail "patch 31-byte key"      run_patch "$KEY_31"
expect_fail "patch 33-byte key"      run_patch "$KEY_33"
expect_fail "patch 31-byte previous" run_patch "" "$KEY_31"
expect_pass "patch 32-byte key"      run_patch "$KEY_32"
expect_pass "patch 32-byte previous" run_patch "" "$KEY_32"

echo "All TOKEN_ENCRYPTION_KEY validation checks passed."
