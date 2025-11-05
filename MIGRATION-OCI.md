# OCI migration notes for storage

This document provides a high-level migration checklist for moving block storage from GCP PDs to OCI block volumes and updating Kubernetes to use OCI-backed PVs.

Steps

1. Create OCI volumes using the `terraform/modules/disks` module (OCI implementation) in a dev environment.
2. Provision Kubernetes `StorageClass` for OCI (see `cluster-resources/storage-class-oci.yaml`) and apply it.
3. Create static `PersistentVolume` manifests that reference OCI `volumeHandle` (see `cluster-resources/pv-postgres-oci.yaml`).
4. Migrate application data from GCP disks to OCI volumes:
   - For databases: use logical replication if possible, or pg_dump/pg_restore for Postgres.
   - For filesystems: create snapshots or attach both volumes temporarily to copy data (rsync), being careful with consistency.
5. Update Deployments/StatefulSets to use new PVCs that bind to the OCI PVs.
6. Validate app behavior and metrics. Then decommission GCP disks and remove GCP resources from Terraform.

Notes

- Terraform cannot move resources between providers with `terraform state mv`. The safe pattern is to create new OCI resources and migrate data.
- Update any automation or cron tasks that reference GCP disk names to the new OCI volume OCIDs.
