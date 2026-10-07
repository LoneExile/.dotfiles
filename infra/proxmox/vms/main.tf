locals {
  debian_image = {
    url    = "https://cloud.debian.org/images/cloud/trixie/20261001-2618/debian-13-genericcloud-amd64-20261001-2618.qcow2"
    sha512 = "f46f0671a6e5bdec5291ab8972bae2f10e5408c2f64a74078f11efc2f06a436a9d0313ed50e0472542eeabf780e9f7c792ac0a314c6c20507fcd9fd81b468c3d"
  }

  nodes = toset([for v in values(var.vms) : v.node])
}

resource "proxmox_download_file" "debian" {
  for_each = local.nodes

  node_name          = each.key
  content_type       = "import"
  datastore_id       = var.image_datastore
  file_name          = "debian-13-genericcloud-amd64-20261001-2618.qcow2"
  url                = local.debian_image.url
  checksum           = local.debian_image.sha512
  checksum_algorithm = "sha512"
}

resource "proxmox_virtual_environment_vm" "vm" {
  for_each = var.vms

  name      = each.key
  node_name = each.value.node
  vm_id     = each.value.vmid
  on_boot   = true
  # Destroy cannot rely on the guest agent (absent during the Debian stage).
  stop_on_destroy = true

  operating_system {
    type = "l26"
  }

  cpu {
    cores = each.value.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.memory_mb
    floating  = 0
  }

  scsi_hardware = "virtio-scsi-single"

  # The Debian cloud image panics on a disk resize without a serial device, and the role's console is ttyS0 (qm terminal).
  serial_device {}

  agent {
    enabled = true
    # The Debian stage has no guest agent, so apply must not wait for an address.
    wait_for_ip {
      disabled = true
    }
  }

  network_device {
    bridge      = var.network_bridge
    mac_address = each.value.mac
  }

  disk {
    datastore_id = var.vm_datastore
    interface    = "scsi0"
    import_from  = proxmox_download_file.debian[each.value.node].id
    size         = each.value.disk_gb
    discard      = "on"
    iothread     = true
  }

  boot_order = ["scsi0"]

  initialization {
    datastore_id = var.vm_datastore

    dns {
      servers = each.value.dns
    }

    ip_config {
      ipv4 {
        address = each.value.ipv4_cidr
        gateway = each.value.gateway
      }
    }

    user_account {
      keys = split("\n", trimspace(var.ssh_authorized_keys))
    }

    upgrade = false
  }

  lifecycle {
    # disko rewrites the disk after install; without this a new image pin would replace every live VM on the next plan.
    ignore_changes = [disk[0].import_from]
  }
}
