# Disks module (compatibility)

This module now creates OCI block volumes based on a `disks` map input. It is intended as the canonical disk module for the OCI migration.

Important: Provider change requires creating new cloud resources (OCI volumes). You cannot `terraform state mv` a GCP disk into an OCI volume. Follow the migration steps below to perform a safe cutover:

1. Commit the new module (OCI implementation) to the shared repo and push the migration branch (e.g. `migrate-service-account`).
2. In the project repo, update the `module` source to point at the shared module and set `compartment_ocid` and `default_availability_domain`. Example:

   module "disks" {
   source = "git::ssh://git@github.com/YOUR_ORG/all-infrastructure.git//terraform/modules/disks?ref=migrate-service-account"
   compartment_ocid = var.compartment_ocid
   default_availability_domain = var.availability_domain
   disks = {
   frolf_bot_postgres_disk = { name = "frolf-bot-postgres-disk", size = 10 }
   }
   }

3. Run `terraform init` to fetch the new module and `terraform plan` to see the new resources to create. The plan will show new OCI volumes to be created — this is expected.

4. Create the OCI volumes (apply the plan in a dev/test environment first). Then migrate data from the GCP disks to the OCI volumes (snapshot + copy, rsync, or DB logical replication depending on the workload).

5. Update your Kubernetes PVs to reference the new OCI volumes (see `cluster-resources/storage-class-oci.yaml` and `pv-postgres-oci.yaml` examples in the repo). Apply the manifests and validate your workloads against the new volumes.

6. Once traffic is switched to OCI, safely destroy GCP disks and remove GCP-specific resources from code.

Notes

- Because provider resources differ, no `terraform state mv` is possible across providers. Create new OCI resources and migrate data between them.
