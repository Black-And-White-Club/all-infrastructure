# Instance Principals for OCI CSI Driver
#
# This module creates the dynamic group and policies needed for the
# OCI CSI driver to provision block volumes using Instance Principals.
# This eliminates the need for API keys in Kubernetes secrets.

variable "tenancy_ocid" {
  description = "OCID of the tenancy"
  type        = string
}

variable "compartment_ocid" {
  description = "OCID of the compartment where volumes will be created"
  type        = string
}

variable "dynamic_group_name" {
  description = "Name for the dynamic group"
  type        = string
  default     = "k8s-csi-nodes"
}

variable "policy_name" {
  description = "Name for the IAM policy"
  type        = string
  default     = "K8sCSIDriverPolicy"
}

variable "matching_rule" {
  description = "Matching rule for the dynamic group. Defaults to all instances in the compartment."
  type        = string
  default     = ""
}

# Dynamic group that includes the K8s worker nodes
resource "oci_identity_dynamic_group" "csi_nodes" {
  compartment_id = var.tenancy_ocid
  name           = var.dynamic_group_name
  description    = "Dynamic group for Kubernetes nodes running the OCI CSI driver"

  # Default: match all instances in the compartment
  # You can make this more specific by instance OCID or tags
  matching_rule = var.matching_rule != "" ? var.matching_rule : "instance.compartment.id = '${var.compartment_ocid}'"
}

# IAM policies for the CSI driver to manage block volumes
resource "oci_identity_policy" "csi_policy" {
  compartment_id = var.tenancy_ocid
  name           = var.policy_name
  description    = "Policies for OCI CSI driver to manage block volumes via Instance Principals"

  statements = [
    # Block volume management
    "Allow dynamic-group ${oci_identity_dynamic_group.csi_nodes.name} to manage volumes in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.csi_nodes.name} to manage volume-attachments in compartment id ${var.compartment_ocid}",

    # Required for attaching volumes to instances
    "Allow dynamic-group ${oci_identity_dynamic_group.csi_nodes.name} to use instances in compartment id ${var.compartment_ocid}",

    # Required for the CSI driver to read instance metadata
    "Allow dynamic-group ${oci_identity_dynamic_group.csi_nodes.name} to read instance-family in compartment id ${var.compartment_ocid}",
  ]
}

output "dynamic_group_id" {
  description = "OCID of the created dynamic group"
  value       = oci_identity_dynamic_group.csi_nodes.id
}

output "dynamic_group_name" {
  description = "Name of the created dynamic group"
  value       = oci_identity_dynamic_group.csi_nodes.name
}

output "policy_id" {
  description = "OCID of the created policy"
  value       = oci_identity_policy.csi_policy.id
}
