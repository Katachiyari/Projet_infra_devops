proxmox_endpoint  = "https://10.250.250.4:8006/"
proxmox_api_token = "terraform-jdk@pve4!jdk-token=c4a17231-fab8-4cd6-801e-bc0dd0251b1c"
proxmox_insecure  = true

node_name     = "pve4"
template_vmid = 9000

datastore_vm       = "local-lvm"
datastore_snippets = "jdk_snippets"

gateway     = "172.16.100.1"
cidr_suffix = 24

ssh_username   = "root"
ssh_agent      = true
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE30vg7EchnxPkkVvAnbi0Ey55NGWRiUNE1ClsUvCj7d vm-common-key"

nodes = {
  bind9dns = {
    ip     = "172.16.100.254"
    cpu    = 2
    mem    = 1024
    disk   = 20
    bridge = "vmbr23"
    tags   = ["JDK", "DNS", "prod", "bind9"]
  }

  git-lab = {
    ip     = "172.16.100.40"
    cpu    = 4
    mem    = 8192
    disk   = 30
    bridge = "vmbr23"
    tags   = ["JDK", "gitlab", "prod"]
  }

  harbor = {
    ip     = "172.16.100.50"
    cpu    = 2
    mem    = 4096
    disk   = 50
    bridge = "vmbr23"
    tags   = ["JDK", "registry", "prod"]
  }

  k3s-manager = {
    ip     = "172.16.100.250"
    cpu    = 4
    mem    = 8192
    disk   = 60
    bridge = "vmbr23"
    tags   = ["JDK", "k3s", "manager", "prod"]
  }

  k3s-worker-0 = {
    ip     = "172.16.100.251"
    cpu    = 2
    mem    = 4096
    disk   = 40
    bridge = "vmbr23"
    tags   = ["JDK", "k3s", "worker", "prod"]
  }

  k3s-worker-1 = {
    ip     = "172.16.100.252"
    cpu    = 2
    mem    = 4096
    disk   = 40
    bridge = "vmbr23"
    tags   = ["JDK", "k3s", "worker", "prod"]
  }

  reverse-proxy = {
    ip     = "172.16.100.253"
    cpu    = 2
    mem    = 4096
    disk   = 20
    bridge = "vmbr23"
    tags   = ["JDK", "reverse-proxy", "nginx", "prod"]
  }

  tools-manager = {
    ip     = "172.16.100.20"
    cpu    = 2
    mem    = 4096
    disk   = 60
    bridge = "vmbr23"
    tags   = ["JDK", "tools", "ansible", "dev"]
  }

  dev-host1 = {
    ip     = "172.16.100.21"
    cpu    = 1
    mem    = 1024
    disk   = 20
    bridge = "vmbr23"
    tags   = ["JDK", "dev", "terraform", "app"]
  }
}
proxmox_tags = {
  JDK           = "JDK related VM"
  DNS           = "DNS Server"
  gitlab        = "GitLab Server"
  registry      = "Container Registry"
  k3s           = "K3s Kubernetes Node"
  manager       = "K3s Manager Node"
  worker        = "K3s Worker Node"
  reverse-proxy = "Reverse Proxy Server"
  tools         = "Tools and Management Server"
  dev           = "Development Environment"
  prod          = "Production Environment"
  terraform     = "Terraform Managed VM"
  ansible       = "Ansible Managed VM"
  app           = "Application Server"
}