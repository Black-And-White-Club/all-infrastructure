# Cluster resources

This directory contains cluster-level Kubernetes manifests that should be applied to every cluster managed by this platform.

Examples included here:

- `namespaces.yaml` — Namespaces used by platform + projects
- `storage-classes.yaml` — StorageClass definitions for project-specific Postgres instances

Current intentionally managed local-storage exceptions:

- `pv-grafana.yaml`
- `pv-loki-local.yaml`
- `pv-resume-postgres-local.yaml`
- `pv-tempo-ingester-wal.yaml`
- `pvc-resume-postgres.yaml`

Retired comment-only PVC stubs live under `retired/` and are no longer part of the active Argo storage scope.

Make sure to adapt provisioner names and parameters to your cloud provider.
