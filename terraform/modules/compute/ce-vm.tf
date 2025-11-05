resource "oci_core_instance" "vm" {
  count = var.vm_count

  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  shape               = var.shape
  display_name        = var.vm_names[count.index]

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = false
  }

  source_details {
    source_type = "image"
    source_id   = var.image_id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}

data "oci_core_private_ips" "private_ips" {
  count = var.vm_count

  subnet_id = oci_core_subnet.public.id

  filter {
    name   = "ip_address"
    values = [oci_core_instance.vm[count.index].private_ip]
  }
}

# Reserved public IPs - only create for VMs where assign_reserved_ips[index] is true
resource "oci_core_public_ip" "reserved_ip" {
  for_each = {
    for idx, should_assign in var.assign_reserved_ips :
    idx => idx if should_assign
  }

  compartment_id = var.compartment_ocid
  lifetime       = "RESERVED"
  private_ip_id  = data.oci_core_private_ips.private_ips[each.value].private_ips[0].id
  display_name   = "${var.vm_names[each.value]}-public-ip"
}

# Disk attachments - currently attaches to first VM only
# TODO: Make this configurable via variable specifying which VM receives which disks
resource "oci_core_volume_attachment" "attachments" {
  for_each = var.disk_ocids

  instance_id     = oci_core_instance.vm[0].id
  volume_id       = each.value
  attachment_type = "paravirtualized"
}
