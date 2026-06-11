# Scale Playbook

This document describes when and how to scale the frolf-bot platform beyond
its current single-node homelab footprint, and the trade-offs at each stage.

---

## Trigger thresholds — when to act

| Signal | Threshold | Action |
|--------|-----------|--------|
| Club count | > 10 active clubs | Evaluate HA postgres (CloudNativePG or Patroni) |
| Charge volume | > 1 000 charges/month | Enable Stripe Connect rate-limit monitoring; review webhook ingress burst limit |
| Pod restarts | > 3 per hour (sustained) | Investigate OOM or logic bug; increase memory limits |
| CPU sustained | > 80% of limit for 15 min | Increase CPU limit; evaluate HPA |
| PVC usage | > 85% | Expand volume or add archival |
| Backup staleness | > 26h (alerted by Grafana) | Investigate backup CronJob; verify OCI bucket health |

---

## 3-node path

The current cluster is a single OCI compute instance (`worker-1`). Moving to
3 nodes (1 control-plane + 2 workers) involves:

1. Terraform: add 2 worker instances in `terraform/` (follow existing compute module).
2. Ansible: re-run `setup-local-k8s.yml` or kubespray join-node playbook.
3. Remove `nodeSelector: kubernetes.io/hostname: worker-1` from frolf-postgres
   and frolf-nats values files, OR configure a new node with the label.
4. If RWO OCI block volumes are used (current), pin StatefulSets to the node
   that has the attached volume. Use topology-aware volume binding to automate
   this in future.

For Deployments (frolf-bot-backend, frolf-bot-pwa, frolf-discord, frolf-bot-ops),
add `replicas: 2` and ensure no inter-pod affinity conflicts.

---

## HA Postgres options

### Option A: CloudNativePG (recommended)

CloudNativePG is the community-maintained Kubernetes operator for PostgreSQL.
It supports streaming replication, automated failover, and point-in-time recovery.

- Deploy the CRD/operator via Helm chart or ArgoCD.
- Create a `Cluster` resource with `instances: 3`.
- Migrate from the current Bitnami StatefulSet (requires a pg_dump/restore step).
- PITR: CloudNativePG writes WAL to an object store (OCI bucket). Configure
  `backup.barmanObjectStore` in the Cluster spec.

### Option B: Patroni (manual HA)

Patroni is battle-tested but requires more operational overhead (etcd or consul
for DCS, custom init scripts). Prefer CloudNativePG for new deployments.

---

## Alerting graduation: Grafana → Mimir Ruler + Alertmanager

**Current approach (accepted trade-off):** Grafana Unified Alerting fires rules
from within the Grafana process. With a single Grafana replica, alert evaluation
stops if Grafana restarts. This is acceptable for a homelab/low-traffic setup.

**Graduation path (when to upgrade):**
- Multi-cluster monitoring, or
- Grafana restarts causing missed alerts are unacceptable.

Steps:
1. Enable Mimir ruler component in `charts/mimir/values.yaml` (`ruler.enabled: true`).
2. Deploy Alertmanager (standalone or via kube-prometheus-stack's component).
3. Migrate alert rules from Grafana file provisioning YAML format to Prometheus/Mimir
   ruler format (similar structure; swap `grafana-alert-rules.yaml` in
   `cluster-resources/grafana-alerts/` for Mimir ruler ConfigMaps).
4. Configure Grafana to use Mimir as the ruler backend:
   `datasources.yaml.datasources[name=Mimir].jsonData.ruler: true` and set ruler URL.
5. Remove `sidecar.alerts` from `charts/grafana/values.yaml`.

---

## WAL-based PITR

With CloudNativePG (above), configure continuous WAL archival to the OCI bucket:

```yaml
backup:
  barmanObjectStore:
    destinationPath: "s3://<bucket>/wal/"
    endpointURL: "<s3-endpoint>"
    s3Credentials:
      accessKeyId:
        name: frolf-postgres-backup-creds
        key: access-key
      secretAccessKey:
        name: frolf-postgres-backup-creds
        key: secret-key
  retentionPolicy: "30d"
```

This allows recovery to any point in the last 30 days — critical for payment data.

---

## Cross-region OCI bucket replication for backups

The current backup bucket is in `us-ashburn-1`. To add cross-region replication:

1. Create a second bucket in another OCI region (e.g., `uk-london-1`).
2. Enable OCI Object Storage replication policy on the source bucket pointing to
   the destination.
3. Update `docs/POSTGRES_RESTORE_TEST.md` to reference both regions and verify
   the replica during drills.

---

## WAF / Cloudflare in front of the webhook host

If webhook abuse becomes a concern at higher charge volumes:

1. Point `frolf-bot.duckdns.org` DNS through Cloudflare (orange-cloud).
2. Add Cloudflare WAF rule: allow only Stripe's published IP ranges on
   `/api/payments/stripe/webhook` and `/api/payments/stripe/billing/webhook`.
3. Update `TRUSTED_PROXY_CIDRS` in `backend-secrets` to include Cloudflare's
   IP ranges so the backend sees real client IPs.

The nginx `limit-rps: 20` annotation in `ingress-stripe-webhook.yaml` is a
backstop; Cloudflare adds a deeper line of defence.

---

## NATS exporter and consumer-lag alerting

When message backlog becomes a concern:

1. Deploy `natsio/prometheus-nats-exporter` as a sidecar or standalone pod.
2. Add a scrape job to `charts/alloy/values.yaml` targeting the exporter.
3. Add alert rules in `cluster-resources/grafana-alerts/grafana-alert-rules.yaml`:
   - `nats_consumer_pending_messages > 1000` sustained for 5 min.
   - `nats_consumer_ack_pending > 500` sustained for 5 min.
4. For JetStream KV lag, use `nats_kv_keys` and `nats_kv_buckets` metrics.
