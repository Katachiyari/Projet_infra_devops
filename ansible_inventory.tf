locals {
  ansible_hosts = {
    for name, n in var.nodes :
    name => {
      ansible_host = n.ip
    }
  }

  # Build group membership based on tags (case-insensitive): if a node has a tag
  # that appears in var.ansible_group_by_tag, it will be added to the mapped group.
  ansible_group_members = {
    for group in distinct(values(var.ansible_group_by_tag)) :
    group => sort(distinct([
      for name, n in var.nodes : name
      if length([
        for tag in n.tags : tag
        if lookup(var.ansible_group_by_tag, lower(tag), null) == group
      ]) > 0
    ]))
  }

  ansible_inventory = {
    all = merge(
      {
        hosts = local.ansible_hosts
      },
      {
        children = {
          for group, members in local.ansible_group_members :
          group => {
            hosts = {
              for m in members :
              m => {}
            }
          }
          if length(members) > 0
        }
      }
    )
  }
}

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/Ansible/inventory/terraform.generated.yml"
  content         = yamlencode(local.ansible_inventory)
  file_permission = "0644"
}

output "ansible_inventory_file" {
  description = "Chemin vers l'inventaire Ansible généré par Terraform"
  value       = local_file.ansible_inventory.filename
}

output "nodes_by_ip" {
  description = "Map: nom de VM -> IP"
  value       = { for name, n in var.nodes : name => n.ip }
}
