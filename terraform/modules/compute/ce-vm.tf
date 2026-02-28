locals {
  # Mark instances that are targets for any disk attachments (so we can conditionally include user_data)
  disk_attach_indexes = values(var.disk_attach_to)
}

resource "oci_core_instance" "vm" {
  count = var.vm_count

  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  shape               = var.shape
  display_name        = var.vm_names[count.index]

  dynamic "shape_config" {
    for_each = length(regexall("Flex$", var.shape)) > 0 ? [1] : []
    content {
      ocpus         = lookup(var.shape_configs, count.index, var.shape_config).ocpus
      memory_in_gbs = lookup(var.shape_configs, count.index, var.shape_config).memory_in_gbs
    }
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
  }

  source_details {
    source_type             = "image"
    source_id               = var.image_id
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  }

  metadata = merge(
    {
      ssh_authorized_keys = var.ssh_public_key
    },
    (var.enable_resume_db_auto_mount && contains(local.disk_attach_indexes, count.index)) ? {
      user_data = base64encode(<<-CLOUDINIT
        #cloud-config
        runcmd:
          - |
            set -e
            MOUNT_POINT="${var.resume_db_mount_point}"
            if ! grep -qs "${var.resume_db_mount_point}" /proc/mounts; then
              DEVICE=""
              # pick first block device that's not the root (/dev/sda*) and not loop
              for DEV in $(lsblk -ndo NAME | grep -vE '^loop|^sr|^sda'); do
                  if [ -z "$(lsblk -ndo MOUNTPOINT /dev/$${DEV})" ]; then
                    DEVICE="/dev/$${DEV}"
                  break
                fi
              done
              if [ -n "$DEVICE" ]; then
                if ! blkid "$${DEVICE}" >/dev/null 2>&1; then
                  mkfs.ext4 -F "$${DEVICE}"
                fi
                mkdir -p "${var.resume_db_mount_point}"
                UUID=$(blkid -s UUID -o value "$${DEVICE}")
                if ! grep -q "$${UUID}" /etc/fstab; then
                  echo "UUID=$${UUID} ${var.resume_db_mount_point} ext4 defaults,noatime 0 2" >> /etc/fstab
                fi
                mount "${var.resume_db_mount_point}"
                chown 1001:1001 "${var.resume_db_mount_point}"
                chmod 700 "${var.resume_db_mount_point}"
              fi
            fi
      CLOUDINIT
      )
    } : {}
  )

  lifecycle {
    ignore_changes = [metadata]
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

  # Attach to the instance index provided in var.disk_attach_to (map), defaulting to 0 (first instance)
  instance_id     = oci_core_instance.vm[lookup(var.disk_attach_to, each.key, 0)].id
  volume_id       = each.value
  attachment_type = "paravirtualized"
}
