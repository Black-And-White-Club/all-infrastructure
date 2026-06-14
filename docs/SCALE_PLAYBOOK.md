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

## Cost summary — every line is an OWNER DECISION, nothing here is auto-applied

Estimates at OCI us-ashburn-1 list prices, June 2026 — **verify against the OCI
pricing page / cost console before committing to any of them.** The current
2-VM A1.Flex cluster (4 OCPU / 24 GB total) fits inside the OCI Always Free
allowance, so today's compute cost is ~$0/mo.

| Option (section below) | Est. monthly cost | Notes |
|---|---|---|
| Stay as-is | ~$0 | Always Free A1 compute + small block/object storage |
| 3rd node (A1.Flex 2 OCPU/12 GB) | ~$28–30 | Beyond free tier: ~$0.01/OCPU-hr + ~$0.0015/GB-hr |
| HA Postgres (CloudNativePG, +2 replicas) | ~$3 storage + needs 3rd node | 2 × 50 GB block volumes ≈ $2.60; compute rides the new node |
| WAL-based PITR | < $1 | WAL archive object storage, pennies at this volume |
| Cross-region backup replication | < $2 | Second-region storage + replication egress on small dumps |
| Cloudflare in front of webhook | $0 + ~$10–12/yr domain | Free plan incl. 5 custom WAF rules covers a Stripe-IP allowlist; **requires a real domain — duckdns subdomains cannot be onboarded**. Pro ($20/mo) only if managed WAF rulesets wanted |
| NATS exporter + lag alerts | $0 | Tiny pod on existing nodes |
| Alerting graduation (Mimir ruler) | $0 | Extra components on existing nodes (RAM headroom permitting) |

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

0. **Prerequisite: a real registered domain (~$10–12/yr).** Cloudflare onboards
   domains at the nameserver level — a `duckdns.org` subdomain cannot be added.
   Changing the public hostname also means updating the Stripe webhook endpoint
   URLs, the cert-manager Certificate, PWA links, and Connect return/refresh URLs.
1. Point the domain's DNS through Cloudflare (orange-cloud).
2. Add Cloudflare WAF rule: allow only Stripe's published IP ranges on
   `/api/payments/stripe/webhook` and `/api/payments/stripe/billing/webhook`.
3. Update `TRUSTED_PROXY_CIDRS` in `backend-secrets` to include Cloudflare's
   IP ranges so the backend sees real client IPs.

The nginx `limit-rps: 20` annotation in `ingress-stripe-webhook.yaml` is a
backstop; Cloudflare adds a deeper line of defence.

---

## PSS enforce graduation (NATS) — maintenance-window procedure

**State (render-verified 2026-06-11):** namespace `frolf-bot` runs PSS
`warn`/`audit: restricted` only. All workloads are restricted-compliant EXCEPT
NATS: chart 2.14.0 silently ignores values-level `podSecurityContext:` /
`container.securityContext:` / `nodeSelector:` keys, so the NATS pod renders
with NO securityContext (image-default user) and no node pinning. Adding the
`enforce` label before fixing this blocks NATS pod creation on its next
restart — a full event-bus outage. The JetStream PVC holds message history the
DB has been restored from before; treat its file ownership as production data.

Procedure (owner-run, maintenance window, zero new cost):

1. Learn the live identity and data ownership:
   `kubectl exec -n frolf-bot frolf-nats-0 -- id`
   `kubectl exec -n frolf-bot frolf-nats-0 -- ls -ln /data`
2. In `charts/nats/values.yaml`, set the CHART-CORRECT keys (these render;
   the old top-level keys do not):
   - `podTemplate.merge.spec.securityContext`: `runAsNonRoot: true`,
     `runAsUser`/`runAsGroup` = the uid/gid observed in step 1 (or 1000 plus
     `fsGroup` matching the /data ownership so the kubelet chowns on mount),
     `seccompProfile.type: RuntimeDefault`.
   - `container.merge.securityContext`: `allowPrivilegeEscalation: false`,
     `capabilities.drop: [ALL]`.
   - Optionally `podTemplate.merge.spec.nodeSelector` for the volume-pinning
     intent — only after `kubectl get nodes --show-labels` confirms the label.
3. Verify locally BEFORE pushing: `helm template frolf-nats nats --repo
   https://nats-io.github.io/k8s/helm/charts/ --version 2.14.0 -f
   charts/nats/values.yaml -n frolf-bot` and confirm the securityContext
   appears in the rendered StatefulSet.
4. Sync, watch `frolf-nats-0` come back Ready, then verify JetStream integrity:
   `nats stream ls` / `nats stream info` (streams present, messages intact).
   Rollback = revert the commit and re-sync.
5. Only then add `pod-security.kubernetes.io/enforce: restricted` +
   `enforce-version: v1.31` to `cluster-resources/namespaces/frolf-bot.yaml`,
   and restart one stateless deployment to confirm admission passes.

---

## NATS exporter and consumer-lag alerting

When message backlog becomes a concern:

1. Deploy `natsio/prometheus-nats-exporter` as a sidecar or standalone pod.
2. Add a scrape job to `charts/alloy/values.yaml` targeting the exporter.
3. Add alert rules in `cluster-resources/grafana-alerts/grafana-alert-rules.yaml`:
   - `nats_consumer_pending_messages > 1000` sustained for 5 min.
   - `nats_consumer_ack_pending > 500` sustained for 5 min.
4. For JetStream KV lag, use `nats_kv_keys` and `nats_kv_buckets` metrics.
