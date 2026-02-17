variable "compartment_ocid" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

resource "oci_bastion_bastion" "bastion" {
  bastion_type     = "STANDARD"
  compartment_id   = var.compartment_ocid
  target_subnet_id = var.subnet_id
  client_cidr_block_allow_list = var.allowed_cidrs
  name             = "k8s-bastion"
  max_session_ttl_in_seconds   = 10800 # 3 hours
}

output "bastion_id" {
  value = oci_bastion_bastion.bastion.id
}
