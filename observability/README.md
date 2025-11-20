# Observability

This directory contains Helm values and scaffolding for the shared monitoring stack. The idea is a single Prometheus/Grafana/Loki/Tempo stack that scrapes both project namespaces and exposes dashboards scoped by team.

Files here are intentionally small examples; customize them to match your chart versions and desired persistence/retention.

## Grafana local-storage and swap options

This repo provides a flexible approach so you can run Grafana with either local node storage (low-cost option) or cloud block volumes (durable HA option).

1. Local node storage (recommended for small clusters):

   - Add `charts/grafana/values-local.yaml` (present) and use `observability/grafana-app.yaml` which now includes the overlay to deploy the local-storage variant.
   - The repo provides an example PV/PVC in `cluster-resources/pv-grafana.yaml` and `cluster-resources/pvc-grafana.yaml`. Update the `nodeAffinity` to the correct worker node and apply it to the cluster.

2. Cloud block volume (OCI):
   - If you later need a durable, cloud block storage PV (e.g., OCI), make a new `charts/grafana/values-block.yaml` or provide an override with `persistence.storageClassName: oci-block-storage` and a suitable `size`.

Switching between modes:

- Deploy the `grafana` app for local-storage (this app includes the local overlay).
- To move to cloud block storage later, create an app that uses your `values-block.yaml` overlay and deploy it. Then migrate data (use a backup & restore or side-by-side deployment) and remove the local release when ready.
- Keep a consistent release name if you want to keep data continuity (e.g., delete the local release and deploy the OCI release with the same name), but be cautious: local PVs cannot be dynamically attached to another node.

Important: Local node PVs are tied to the node; if the node is lost or the pod is rescheduled, the data may not be available. For production environments requiring high durability, prefer cloud block volumes.

Note on safety: The sample `pv-grafana.yaml` uses `persistentVolumeReclaimPolicy: Retain`, which means deleting the PV resource will not delete data on disk; the PV will remain and the underlying files on the host are preserved. No manifest in this repo will automatically wipe or format the node's boot disk. Still, always check `nodeAffinity` and `path` before applying PV manifests.

## Migrating from local storage to cloud block storage

- Make a backup of Grafana data and dashboards (export dashboards via Grafana UI or enable sidecar-based dashboard ConfigMaps in the repo).
- Option A (zero-downtime-like): Deploy a `grafana-block` app that uses your block storage overlay first and then switch traffic to the new Grafana instance (requires updating DNS/ingress/route and ensuring new grafana has same datasources and dashboards). This keeps both Grafana instances running until you confirm data/dashboards are available in the new backend.
- Option B (in-place): Export the Grafana SQLite DB, deploy new app and import DB into the new storage class. This is more brittle and requires careful handling—especially if you switch release name which determines the release manifest.
- After verification and successful migration, delete any legacy Grafana artifacts and PV/PVCs if they are no longer needed (search for `grafana` PV/PVC names in the cluster-resources directory).

If you'd like, I can add an automation script that performs the backup & migration steps automatically (dumping the sqlite DB, copying it to a staging area, and applying the new chart release); that often involves `kubectl exec` and `tar` or `rsync` over `kubectl cp`.
