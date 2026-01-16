 
locals {
  cloud_init_user_data = {
    for name, n in var.nodes :
    name => templatefile("${path.module}/cloud-init/user-data.yaml.tftpl", {
      hostname      = name
      ansible_pubkey = var.ssh_public_key
    })
  }
 
   iso_file_id = "${var.iso_storage}:iso/${var.iso_file}"
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
 
  tags = each.value.tags
 
  clone {
    vm_id = var.template_vmid
  }
 
  # IMPORTANT: démarre la VM automatiquement
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
        address = "${each.value.ip}/24"
        gateway = var.gateway
      }
    }
 
    user_account {
      username = "ansible"
      keys     = [var.ssh_public_key]
    }
 
    # IMPORTANT: attache le snippet cloud-init à la VM
    user_data_file_id = proxmox_virtual_environment_file.user_data[each.key].id
  }
 
  agent {
    enabled = true
  }
 
 
  # Optionnel mais utile: éviter que Terraform tente de créer les VMs avant la dispo du snippet
  depends_on = [proxmox_virtual_environment_file.user_data]
}
 
 
### vm install iso
 
 
resource "proxmox_virtual_environment_vm" "install_vm" {
  for_each  = var.install_vms
  name      = each.value.name
  node_name = var.node_name
 
  tags = each.value.tags
 
  # VM hardware
  cpu {
    cores = each.value.cpu
    type  = "host"
  }
 
  memory {
    dedicated = each.value.mem
  }
 
  disk {
    datastore_id = var.datastore_vm
    interface    = "scsi0"
    size         = each.value.disk_gb
  }
 
  network_device {
    model  = "virtio"
    bridge = each.value.bridge
  }
 
  # Agent activé (utile après install si qemu-guest-agent est installé dans l'OS)
  agent { enabled = true }
 
  # Démarrage automatique (tu peux mettre false si tu veux préparer d'abord)
  started = true
  on_boot = true
 
  # ISO seulement si install_mode=true
  dynamic "cdrom" {
    for_each = var.install_mode ? [1] : []
    content {
      file_id   = local.iso_file_id
      interface = "ide2"
    }
  }
 
  # Boot : ISO d'abord pendant install, puis disque
  boot_order = var.install_mode ? ["ide2", "scsi0"] : ["scsi0"]
 
  # Important : éviter les erreurs type "ide2 hotplug problem" lors de bascule install_mode
  # Proxmox n'aime pas certains changements de média à chaud.
  lifecycle {
    ignore_changes = [
      # selon provider, il peut considérer cdrom/boot_order comme drift à corriger.
      # On ignore pour éviter les erreurs "hotplug problem".
      cdrom,
      boot_order,
    ]
  }
}
 
### opnsense
 
resource "proxmox_virtual_environment_vm" "opnsense" {
  name      = "opnsense-fw"
  node_name = var.node_name
  tags      = ["firewall", "opnsense", "prod"]
 
  cpu {
    cores = 2
    type  = "host"
  }
 
  memory {
    dedicated = 4096
  }
 
  # Disque
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 32
    file_format  = "raw"
  }
 
  # NIC 1: WAN
  network_device {
    model      = "virtio"
    bridge     = "vmbr0"
    firewall   = true
    # vlan_id  = 10   # optionnel si trunk/vlan
  }
 
  # NIC 2: LAN156
  network_device {
    model    = "virtio"
    bridge   = "vmbr156"
    firewall = true
  }
 
  # NIC 3: OPT1/DMZ
#  network_device {
#    model    = "virtio"
#    bridge   = "vmbr2"
#    firewall = true
#  }
 
  # Boot sur ISO OPNsense si install initiale
  cdrom {
    file_id   = "local:iso/OPNsense-25.7-dvd-amd64.iso"
    interface = "ide2"
  }
 
  boot_order = ["ide2", "scsi0"]
}