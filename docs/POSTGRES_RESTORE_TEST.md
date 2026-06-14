# Postgres Restore Test Drill

Run this drill monthly to verify backup integrity. Record the result in the
table at the bottom of this document.

---

## Backup source

Backups are produced by `cluster-resources/cronjobs/frolf-postgres-backup.yaml`
(runs daily at 03:00 UTC). Two gzip dumps are written per run:

| File pattern | Database |
|---|---|
| `frolf-bot-YYYY-MM-DD.sql.gz` | frolf_bot (application data) |
| `frolfops-YYYY-MM-DD.sql.gz` | frolfops (ops/audit data) |

The dumps are uploaded to OCI Object Storage using credentials from the
`frolf-postgres-backup-creds` SealedSecret (keys: `access-key`, `secret-key`,
`bucket-name`, `s3-endpoint`). The endpoint is OCI's S3-compatible API in
`us-ashburn-1`.

---

## Step 1 — Fetch the latest backup from OCI

```bash
# Retrieve bucket name and endpoint from the sealed secret (after decrypting locally
# or reading from the private repo).
BUCKET_NAME="<from frolf-postgres-backup-creds secret: bucket-name>"
S3_ENDPOINT="<from frolf-postgres-backup-creds secret: s3-endpoint>"
AWS_ACCESS_KEY_ID="<from frolf-postgres-backup-creds secret: access-key>"
AWS_SECRET_ACCESS_KEY="<from frolf-postgres-backup-creds secret: secret-key>"

TODAY=$(date +%Y-%m-%d)
aws s3 cp \
  "s3://${BUCKET_NAME}/frolf-bot-${TODAY}.sql.gz" \
  /tmp/frolf-bot-restore-test.sql.gz \
  --endpoint-url "${S3_ENDPOINT}" \
  --region us-ashburn-1
```

If today's dump is not yet available (job runs at 03:00 UTC), use yesterday's
date. List available backups with:
```bash
aws s3 ls "s3://${BUCKET_NAME}/" --endpoint-url "${S3_ENDPOINT}" --region us-ashburn-1 | sort | tail -10
```

---

## Step 2 — Restore into a throwaway local container

```bash
# Start a temporary Postgres 17 container (no persistent volume).
docker run --rm -d \
  --name pg-restore-test \
  -e POSTGRES_PASSWORD=testpass \
  -p 5433:5432 \
  postgres:17.4

# Wait for it to be ready.
until docker exec pg-restore-test pg_isready -U postgres; do sleep 1; done

# Create the target database.
docker exec pg-restore-test psql -U postgres -c "CREATE DATABASE frolf_bot;"

# Restore the dump.
gunzip -c /tmp/frolf-bot-restore-test.sql.gz \
  | docker exec -i pg-restore-test psql -U postgres -d frolf_bot

echo "Restore complete."
```

---

## Step 3 — Sanity checks

Run the following queries against the restored database:

```bash
PGPASSWORD=testpass psql -h localhost -p 5433 -U postgres -d frolf_bot <<'EOF'
-- Row counts on money tables
SELECT 'charge_batches'        AS table_name, COUNT(*) FROM charge_batches;
SELECT 'charge_allocations'    AS table_name, COUNT(*) FROM charge_allocations;
SELECT 'ace_pot_ledger'        AS table_name, COUNT(*) FROM ace_pot_ledger;
SELECT 'stripe_billing_invoices' AS table_name, COUNT(*) FROM stripe_billing_invoices;

-- Latest applied migration
SELECT id FROM bun_migrations ORDER BY id DESC LIMIT 1;

-- Ledger sum invariant: net credits must be >= 0 (no negative balance)
SELECT SUM(amount_cents) AS net_balance FROM ace_pot_ledger;
EOF
```

Expected: all tables return non-negative row counts, `bun_migrations.id` is
a 14-digit timestamp, and `net_balance` >= 0. Any unexpected zero counts or
negative balances should be investigated before declaring the backup valid.

---

## Step 4 — Cleanup

```bash
docker stop pg-restore-test
rm /tmp/frolf-bot-restore-test.sql.gz
```

---

## Drill log

| Date | Operator | Dump date restored | Row counts OK | Ledger invariant OK | Notes |
|------|----------|--------------------|---------------|----------------------|-------|
| | | | | | First drill |
