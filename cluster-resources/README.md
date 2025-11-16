# Cluster resources

This directory contains cluster-level Kubernetes manifests that should be applied to every cluster managed by this platform.

Examples included here:

- `namespaces.yaml` — Namespaces used by platform + projects
- `storage-classes.yaml` — StorageClass definitions for project-specific Postgres instances
- `pv-*.yaml` — Example PV templates were used previously for local provisioning but are now intentionally removed or commented out in favor of dynamically-provisioned PVCs using the `oci-block-storage` StorageClass.
  - Prefer chart-managed PVCs and do not check hostPath PV manifests into `cluster-resources/`.

Make sure to adapt provisioner names and parameters to your cloud provider.
