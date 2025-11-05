resource "oci_artifacts_container_repository" "repo" {
  compartment_id = var.compartment_ocid
  display_name   = var.repo_name
  is_immutable   = false
}

# Note: OCIR permissions are managed via policies/groups; add the necessary policies to allow
# the AIU/CI user to push/pull images. This module intentionally creates the repository only.
