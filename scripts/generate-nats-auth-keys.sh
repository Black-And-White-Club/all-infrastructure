#!/usr/bin/env bash
set -euo pipefail

# Generate NATS Auth Callout NKeys
# Requires: go install github.com/nats-io/nkeys/nk@latest

OUTPUT_DIR="${1:-.}"
mkdir -p "$OUTPUT_DIR"

echo "Generating NATS Auth Callout keys..."

# Generate Account key (issuer) - identifies who can issue user JWTs
echo "Generating Account (Issuer) key..."
ACCOUNT_OUTPUT=$(nk -gen account)
ACCOUNT_SEED=$(echo "$ACCOUNT_OUTPUT" | head -1)
ACCOUNT_PUBLIC=$(nk -inkey <(echo "$ACCOUNT_SEED") -pubout)

# Generate User signing key - used by backend to sign user JWTs
echo "Generating User (Signing) key..."
USER_OUTPUT=$(nk -gen user)
USER_SEED=$(echo "$USER_OUTPUT" | head -1)
USER_PUBLIC=$(nk -inkey <(echo "$USER_SEED") -pubout)

# Save to files (keep these secure!)
echo "$ACCOUNT_SEED" > "$OUTPUT_DIR/auth-account.nk"
echo "$ACCOUNT_PUBLIC" > "$OUTPUT_DIR/auth-account.pub"
echo "$USER_SEED" > "$OUTPUT_DIR/auth-signing.nk"
echo "$USER_PUBLIC" > "$OUTPUT_DIR/auth-signing.pub"

cat << EOF

=== NATS Auth Callout Keys Generated ===

Account (Issuer) Key:
  Seed (SECRET - AUTH_CALLOUT_ISSUER_NKEY): $ACCOUNT_SEED
  Public: $ACCOUNT_PUBLIC

User (Signing) Key:
  Seed (SECRET - AUTH_CALLOUT_SIGNING_NKEY): $USER_SEED
  Public: $USER_PUBLIC

Files saved to: $OUTPUT_DIR/
  - auth-account.nk  (issuer seed - keep secret)
  - auth-account.pub (issuer public key - use in nats.conf)
  - auth-signing.nk  (signing seed - keep secret)
  - auth-signing.pub (signing public key)

For your backend .env:
  AUTH_CALLOUT_ENABLED=true
  AUTH_CALLOUT_ISSUER_NKEY=$ACCOUNT_SEED
  AUTH_CALLOUT_SIGNING_NKEY=$USER_SEED

For nats.conf, use the Account PUBLIC key: $ACCOUNT_PUBLIC

EOF
