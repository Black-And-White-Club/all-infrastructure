Terraform module to create OCI Object Storage buckets for observability (Mimir/Loki/Tempo).

Usage:

module "object_storage" {
source = "./modules/object-storage"

compartment_ocid = var.compartment_ocid
namespace = data.oci_objectstorage_namespace.namespace.namespace
buckets = {
mimir = { name = "mimir-shared-bucket" }
loki = { name = "loki-shared-bucket" }
tempo = { name = "tempo-shared-bucket" }
}
}

Notes:

- This module only creates buckets; it does not create credentials. Create a dedicated service user and API key for cluster components, and seal the secret using sealed-secrets in the `cluster-resources/sealed-secrets` folder.
- You may want to configure bucket lifecycle rules and object versioning using additional attributes in the bucket object.
