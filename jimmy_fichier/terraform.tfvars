 
# Token complet
proxmox_api_token = "terraform@pve!terraform-token=4b6f94a7-5ca24817"
 
# Clé publique ansible ( dans le répertoire keys d'ansible)
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAX/3zdFMi ansible@k3s-lab"
 
# SSH vers le node Proxmox (pour upload snippets)
# ssh-copy-id -i ~/.ssh/id_ed25519.pub root@"""""ip-proxmox"""""
ssh_username = "root"
ssh_agent    = true
 
proxmox_endpoint = "https://192.168.1.200:8006/"
proxmox_host = "192.168.1.200"
bridge="vmbr1"
 
gateway = "192.168.156.1"
 
nodes = {
  k3s-master = {
    ip     = "192.168.156.90"
    cpu    = 2
    mem    = 4096
    disk   = 40
    bridge = "vmbr156"
    tags   = ["k3s", "master", "staging"]
  }
 
  k3s-worker1 = {
    ip     = "192.168.156.91"
    cpu    = 2
    mem    = 4096
    disk   = 30
    bridge = "vmbr156"
    tags   = ["k3s", "worker", "staging"]
  }
 
  k3s-worker2 = {
    ip     = "192.168.156.92"
    cpu    = 2
    mem    = 4096
    disk   = 30
    bridge = "vmbr156"
    tags   = ["k3s", "worker", "staging"]
  }
 
  gitlab = {
    ip     = "192.168.156.95"
    cpu    = 4
    mem    = 12000
    disk   = 30
    bridge = "vmbr156"
    tags   = ["gitlab", "prod", "docker"]
  }
 
  harbor = {
    ip     = "192.168.156.96"
    cpu    = 2
    mem    = 4096
    disk   = 50
    bridge = "vmbr156"
    tags   = ["registry", "prod", "docker"]
  }
 
  prometheus = {
    ip     = "192.168.156.97"
    cpu    = 6
    mem    = 8192
    disk   = 30
    bridge = "vmbr156"
    tags   = ["promeheus", "grafana", "alertmanager", "prod", "docker"]
  }
 
 
  bookstack = {
    ip     = "192.168.156.98"
    cpu    = 2
    mem    = 4096
    disk   = 30
    bridge = "vmbr156"
    tags   = ["bookstack", "prod", "docker"]
  }
 
 
  reverse-proxy-nginx = {
    ip     = "192.168.156.100"
    cpu    = 2
    mem    = 4096
    disk   = 20
    bridge = "vmbr156"
    tags   = ["reverse-proxy", "prod", "nginx"]
  }
 
  bind9dns = {
    ip     = "192.168.156.99"
    cpu    = 2
    mem    = 1024
    disk   = 20
    bridge = "vmbr156"
    tags   = ["DNS", "prod", "bind9"]
  }
 
 
}
 