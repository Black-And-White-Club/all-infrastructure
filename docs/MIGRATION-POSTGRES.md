# Migration Guide: Migrate Postgres and Observability PVs to Dynamic PVCs

This guide walks through safely migrating statically provisioned hostPath/local PVs to dynamically provisioned PVCs using the `oci-block-storage` StorageClass and moving observability data to OCI Object Storage.

Prerequisites

- Ensure you have backups of the data on the hostPath PVs (pg_dump for Postgres and the appropriate backup for Mimir/Loki/Tempo).
- Make sure ArgoCD is configured to manage the platform charts and that the `all-infrastructure` chart values are updated for PVC dynamic provisioning.

Steps

1. Confirm current PV usage: `kubectl get pv,pvc -A | grep -E "hostPath|local|<your PV name>"`
2. Backup Postgres data:
   - `kubectl -n resume-db exec <postgres-pod> -- pg_dumpall -U <user> > /tmp/resume-db-backup.sql` (copy out)
   - Or use `pg_dump` for per-database backups.
3. For Postgres: Update chart values (done in values file) and let Helm/ArgoCD create a PVC with `storageClass: oci-block-storage`:
   - Confirm `postresql/values.yaml` or specific app values has `primary.persistence.storageClass: oci-block-storage`.
   - Let the chart create a new PVC. Then restore data into the new database (or perform a continuous replication if needed).
4. For Grafana/Prometheus/Mimir/Loki/Tempo:
   - Mimir/Loki/Tempo: Change blocks/chunks/trace store to use S3-compatible/OCI Object Storage and use 'oci-block-storage' for local caches (ingesters/ingester caches/queriers) in values file.
   - Grafana: Set persistence.storageClass: oci-block-storage in its values.
5. Verify PVCs are bound and pods restart and run successfully: `kubectl get pvc -n <ns>` and `kubectl get pods -n <ns> --watch`.
6. Confirm new workloads are using the new storage and that data is present. If using a new database, validate application connectivity.
7. When everything is validated, remove the old PV from the cluster: `kubectl delete pv <pv-name>`. Only after you confirm data is safe and no pods reference the PV.

Rollbacks and Safety

- If you create a new PVC and the workload fails, restore the backup into the new PVC or revert the chart values until resolved.
- Always ensure you keep the PV with `persistentVolumeReclaimPolicy: Retain` until data is migrated.

Notes

- The migration process requires careful coordination for production workloads — consider doing this during a maintenance window.
- For very large datasets, consider setting up replication or streaming replication to an external DB (managed database) before cutting over.
