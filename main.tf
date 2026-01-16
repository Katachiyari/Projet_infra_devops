locals {
  cloud_init_user_data = {
    for name, n in var.nodes :
    name => templatefile("${path.module}/cloud-init/user-data.yaml.tftpl", {
      hostname = name
    })
  }
}

resource "proxmox_virtual_environment_file" "user_data" {
  for_each     = var.nodes
  node_name    = var.node_name
  datastore_id = var.datastore_snippets
  content_type = "snippets"

  source_raw {
    data      = local.cloud_init_user_data[each.key]
    file_name = "user-data-${each.key}.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  for_each  = var.nodes
  name      = each.key
  node_name = var.node_name
  tags      = sort(distinct([for t in each.value.tags : lower(t)]))

  clone {
    vm_id = var.template_vmid
  }

  started = true
  on_boot = true

  cpu {
    cores = each.value.cpu
  }

  memory {
    dedicated = each.value.mem
  }

  disk {
    datastore_id = var.datastore_vm
    interface    = "scsi0"
    size         = each.value.disk
  }

  network_device {
    model  = "virtio"
    bridge = each.value.bridge
  }

  initialization {
    ip_config {
      ipv4 {
        address = format("%s/%d", each.value.ip, var.cidr_suffix)
        gateway = var.gateway
      }
    }

    user_account {
      username = "ansible"
      keys     = [var.ssh_public_key]
    }

    # attache ton cloud-config (installe qemu-guest-agent + hardening)
    user_data_file_id = proxmox_virtual_environment_file.user_data[each.key].id
  }

  lifecycle {
    # Le provider remplace le resource file snippet quand son contenu change.
    # On évite que ça force le remplacement de la VM.
    ignore_changes = [
      initialization[0].user_data_file_id,
    ]
  }

  agent {
    enabled = true
  }

  depends_on = [proxmox_virtual_environment_file.user_data]
}
