 
variable "proxmox_endpoint" {
  type        = string
  description = "API endpoint Proxmox (https://IP:8006/)"
  default     = "https://192.168.1.200:8006/"
}
 
variable "proxmox_host" {
  type        = string
  description = "ssh endpoint Proxmox"
  default     = "192.168.1.200"
}
 
variable "proxmox_api_token" {
  type        = string
  description = "Proxmox API Token (format user@realm!token=SECRET)"
  sensitive   = true
}
 
variable "proxmox_insecure" {
  type        = bool
  description = "True si certificat auto-signé (lab)"
  default     = true
}
 
variable "node_name" {
  type        = string
  description = "Nom du node Proxmox"
  default     = "pve"
}
 
variable "template_vmid" {
  type        = number
  description = "VMID du template cloud-init"
  default     = 9000
}
 
variable "datastore_vm" {
  type        = string
  description = "Datastore pour disques VM"
  default     = "local-lvm"
}
 
variable "datastore_snippets" {
  type        = string
  description = "Datastore snippets (doit avoir Content=Snippets activé) – typiquement 'local'"
  default     = "local"
}
 
variable "bridge" {
  type        = string
  description = "Bridge réseau (NAT lab)"
  default     = "vmbr1"
}
 
variable "gateway" {
  type        = string
  description = "Gateway du réseau NAT"
  default     = "192.168.156.1"
}
 
variable "cidr_suffix" {
  type        = number
  description = "Suffixe CIDR (24 pour 255.255.255.0)"
  default     = 24
}
 
variable "ssh_public_key" {
  type        = string
  description = "Clé publique SSH pour l'utilisateur ansible"
}
 
variable "ssh_username" {
  type        = string
  description = "Utilisateur SSH sur l'hôte Proxmox (pour upload snippets). En lab: root."
  default     = "root"
}
 
variable "ssh_agent" {
  type        = bool
  description = "Utiliser l'agent SSH du poste"
  default     = true
}
 
variable "nodes" {
  description = "Définition des VMs à créer (équivalent Vagrant nodes[])"
  type = map(object({
    ip   = string
    cpu  = number
    mem  = number
    disk  = number # taille en Go
    bridge = string        # ex: vmbr1
    tags   = list(string)  # ex: ["k3s","master"]
  }))
}
 
###
 
# Active/désactive l'attachement ISO + boot sur ISO
variable "install_mode" {
  type        = bool
  description = "Si true: attache ISO + boot ISO (installation manuelle). Si false: pas d'ISO/boot disque."
  default     = true
}
 
# ISO présent dans Proxmox (storage ISO, typiquement local)
variable "iso_storage" {
  type    = string
  default = "local"
}
 
variable "iso_file" {
  type        = string
  description = "Nom de l'ISO dans <iso_storage>:iso/<iso_file>"
  default     = "ubuntu-24.04.3-desktop-amd64.iso"
}
 
# VMs à créer/installer
variable "install_vms" {
  type = map(object({
    vmid   = number
    name   = string
    tags   = list(string)
 
    cpu    = number
    mem    = number
    disk_gb = number
 
    bridge = string          # ex: vmbr156
    # L'IP est stockée ici pour cohérence/inventaire, mais NE PEUT PAS être appliquée sans cloud-init/autoinstall
    ip      = optional(string)
    prefix  = optional(number)
    gateway = optional(string)
  }))
}