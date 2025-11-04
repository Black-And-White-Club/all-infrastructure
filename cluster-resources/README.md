# Cluster resources

This directory contains cluster-level Kubernetes manifests that should be applied to every cluster managed by this platform.

Examples included here:

- `namespaces.yaml` — Namespaces used by platform + projects
- `storage-classes.yaml` — StorageClass definitions for project-specific Postgres instances
- `pv-*.yaml` — Example PV templates (local/backing disk placeholders)

Make sure to adapt provisioner names and parameters to your cloud provider.
