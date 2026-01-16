variable "proxmox_endpoint" {
  type        = string
  description = "API endpoint Proxmox (ex: https://10.250.250.4:8006/)"
}

variable "proxmox_api_token" {
  type        = string
  description = "Token API Proxmox au format user@realm!token=SECRET"
  sensitive   = true
}

variable "proxmox_insecure" {
  type        = bool
  description = "True si certificat auto-signé"
  default     = true
}

variable "node_name" {
  type        = string
  description = "Nom du node Proxmox (ex: pve4)"
}

variable "template_vmid" {
  type        = number
  description = "VMID du template cloud-init (ex: 9000)"
}

variable "datastore_vm" {
  type        = string
  description = "Datastore disques VM (ex: local-lvm)"
}

variable "datastore_snippets" {
  type        = string
  description = "Datastore snippets (ex: jdk_snippets) avec Content=Snippets activé"
}

variable "gateway" {
  type        = string
  description = "Gateway IPv4"
}

variable "cidr_suffix" {
  type        = number
  description = "Suffixe CIDR (24 par défaut)"
  default     = 24
}

variable "ssh_public_key" {
  type        = string
  description = "Clé publique SSH pour l'utilisateur ansible (1 ligne ssh-ed25519 ...)"
}

variable "ssh_username" {
  type        = string
  description = "Utilisateur SSH sur le node Proxmox pour upload snippets"
  default     = "root"
}

variable "ssh_agent" {
  type        = bool
  description = "Utiliser ssh-agent"
  default     = true
}

variable "nodes" {
  description = "VMs à créer"
  type = map(object({
    ip     = string
    cpu    = number
    mem    = number
    disk   = number
    bridge = string
    tags   = list(string)
  }))
}

variable "ansible_group_by_tag" {
  type        = map(string)
  description = "Map de tags Proxmox (en minuscules) vers des groupes Ansible (ex: tools -> taiga_hosts)."
  default = {
    tools = "taiga_hosts"
    dns   = "bind9dns"
    bind9 = "bind9dns"
  }
}
