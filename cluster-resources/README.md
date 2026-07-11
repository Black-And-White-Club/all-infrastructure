# Cluster resources

This directory contains cluster-level Kubernetes manifests that should be applied to every cluster managed by this platform.

Layout:

- `namespaces/` — Namespaces and LimitRange defaults used by platform + projects
- `storage/` — StorageClasses plus intentionally managed local-storage PV/PVC
  exceptions (`pv-grafana.yaml`, `pv-loki-local.yaml`,
  `pv-resume-postgres-local.yaml`, `pv-tempo-ingester-wal.yaml`,
  `pvc-resume-postgres.yaml`). The `cluster-storage` Argo app syncs this whole
  directory, so new storage manifests placed here are applied automatically.

Retired comment-only PVC stubs live under `retired/` and are no longer part of the active Argo storage scope.

Make sure to adapt provisioner names and parameters to your cloud provider.
