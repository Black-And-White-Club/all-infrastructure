#!/usr/bin/env bash
set -euo pipefail

# Usage: OCI_ACCESS_KEY=xxx OCI_SECRET_KEY=xxx ./generate-frolf-postgres-backup-creds.sh
#
# Prerequisites:
#   - kubectl configured to talk to the cluster
#   - kubeseal installed and sealed-secrets controller running in the cluster
#   - OCI Customer Secret Key pair created in:
#     OCI Console → Identity → Users → <your user> → Customer Secret Keys

NAMESPACE="frolf-bot"
SECRET_NAME="frolf-postgres-backup-creds"
S3_ENDPOINT="https://id2uwn5pyixh.compat.objectstorage.us-ashburn-1.oraclecloud.com"
BUCKET_NAME="frolf-postgres-backup"

kubectl create secret generic "$SECRET_NAME" \
  --namespace "$NAMESPACE" \
  --from-literal=access-key="${OCI_ACCESS_KEY}" \
  --from-literal=secret-key="${OCI_SECRET_KEY}" \
  --from-literal=bucket-name="${BUCKET_NAME}" \
  --from-literal=s3-endpoint="${S3_ENDPOINT}" \
  --dry-run=client -o yaml \
| kubeseal --format=yaml > "sealed-frolf-postgres-backup-creds.yaml"

echo "Generated: sealed-frolf-postgres-backup-creds.yaml"
echo "Next: git add sealed-frolf-postgres-backup-creds.yaml && git commit"
