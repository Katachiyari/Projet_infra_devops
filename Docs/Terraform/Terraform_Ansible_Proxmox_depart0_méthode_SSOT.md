# 🎯 Création projet avec méthode SSOT (Single Source of Truth)

## Principe SSOT appliqué au projet

**SSOT = Une seule source de vérité pour chaque donnée**[^1]

Au lieu de dupliquer les informations, chaque donnée a **un seul point de définition** et toutes les autres configurations en découlent automatiquement.

***

## 📍 Phase 0 : Architecture SSOT du projet

### Explication

Dans votre architecture, le **SSOT est réparti** selon le type de donnée :


| Donnée | SSOT | Consommateurs |
| :-- | :-- | :-- |
| Infrastructure (VMs, réseau) | `terraform.tfvars` | Terraform → Proxmox |
| Inventaire hôtes | Terraform State | Ansible (via `terraform.generated.yml`) |
| Clé SSH | `keys/ansible_ed25519.pub` | Terraform → Cloud-init → VMs |
| Configuration services | Ansible `group_vars/` | Playbooks → VMs |
| Secrets | Vault externe (optionnel) | Terraform + Ansible |

### Cycle de vie SSOT

```
1. terraform.tfvars (SSOT infrastructure)
   └─> Terraform State
       └─> ansible_inventory.tf
           └─> Ansible inventory
               └─> Playbooks

2. keys/ansible_ed25519.pub (SSOT accès SSH)
   └─> terraform.tfvars (ssh_public_key)
       └─> main.tf (user_account.keys)
           └─> Cloud-init
               └─> /home/ansible/.ssh/authorized_keys

3. group_vars/all.yml (SSOT config globale)
   └─> Playbooks
       └─> Roles
           └─> Tasks
```


***

## 📍 Phase 1 : SSOT - Infrastructure (Proxmox + Template)

### Modifications par rapport à la version classique

**Ajout d'un fichier de variables d'environnement** pour éviter la duplication des informations Proxmox.

### Commandes à exécuter

**Étape 1.1 : Création du template (identique Phase 1 précédente)**

```bash
ssh root@<ip-proxmox>

# Téléchargement image
wget https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img \
  -O /var/lib/vz/template/iso/ubuntu-24.04-cloudimg-amd64.img

# Création template VMID 9000
qm create 9000 --name ubuntu-2404-cloudinit-template --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9000 /var/lib/vz/template/iso/ubuntu-24.04-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot order=scsi0 --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1
qm template 9000
```

**Étape 1.2 : Script SSOT pour la création du token API**

```bash
# Créer un script pour documenter la création du token
cat > scripts/create-proxmox-token.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "=== Création Token API Proxmox (SSOT) ==="
echo ""
echo "1. Connexion à l'interface Proxmox : https://<ip-proxmox>:8006"
echo "2. Datacenter → Permissions → API Tokens → Add"
echo "3. Paramètres SSOT :"
echo "   - User: root@pam"
echo "   - Token ID: terraform"
echo "   - Privilege Separation: DÉCOCHÉ"
echo ""
echo "4. COPIER le token généré dans : secrets/proxmox-token.txt"
echo ""
read -p "Appuyer sur Entrée après création du token..."

# Vérifier existence du fichier
if [[ ! -f secrets/proxmox-token.txt ]]; then
    echo "❌ Fichier secrets/proxmox-token.txt manquant"
    exit 1
fi

echo "✅ Token API configuré"
EOF

chmod +x scripts/create-proxmox-token.sh
mkdir -p secrets
```


### Tableau des fichiers SSOT

| Fichier | Chemin | Rôle SSOT | Versionné |
| :-- | :-- | :-- | :-- |
| Template VMID 9000 | Proxmox | SSOT image de base | N/A |
| `secrets/proxmox-token.txt` | `secrets/` | SSOT authentification API | ❌ Non |
| `create-proxmox-token.sh` | `scripts/` | Procédure création token | ✅ Oui |


***

## 📍 Phase 2 : SSOT - Clés SSH

### Explication

La clé SSH est le **SSOT de l'accès** aux VMs. Elle est générée une seule fois et référencée partout.

### Cycle de vie SSOT

```
1. Génération clé → keys/ansible_ed25519.pub (SSOT)
2. Lecture par script → Injection automatique dans terraform.tfvars
3. Terraform lit → Passe à cloud-init
4. Cloud-init écrit → /home/ansible/.ssh/authorized_keys
5. Ansible utilise → keys/ansible_ed25519 (même source)
```


### Commandes à exécuter

**Étape 2.1 : Script de génération SSOT des clés**

```bash
cat > scripts/generate-ssh-keys.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

KEYS_DIR="keys"
KEY_NAME="ansible_ed25519"
KEY_PATH="${KEYS_DIR}/${KEY_NAME}"

echo "=== Génération Clé SSH SSOT ==="

if [[ -f "${KEY_PATH}" ]]; then
    echo "⚠️  Clé existante détectée : ${KEY_PATH}"
    read -p "Régénérer ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "✅ Conservation de la clé existante"
        exit 0
    fi
fi

mkdir -p "${KEYS_DIR}"

ssh-keygen -t ed25519 \
  -C "ansible@proxmox-$(date +%Y%m%d)" \
  -f "${KEY_PATH}" \
  -N ""

chmod 600 "${KEY_PATH}"
chmod 644 "${KEY_PATH}.pub"

echo ""
echo "✅ Clé SSH générée (SSOT) :"
echo "   Privée : ${KEY_PATH}"
echo "   Publique : ${KEY_PATH}.pub"
echo ""
echo "📋 Contenu à copier dans terraform.tfvars :"
cat "${KEY_PATH}.pub"
EOF

chmod +x scripts/generate-ssh-keys.sh
```

**Étape 2.2 : Exécution**

```bash
./scripts/generate-ssh-keys.sh
```


### Tableau des fichiers SSOT

| Fichier | Chemin | Rôle SSOT | Versionné |
| :-- | :-- | :-- | :-- |
| `ansible_ed25519.pub` | `keys/` | SSOT accès SSH (public) | ✅ Oui |
| `ansible_ed25519` | `keys/` | Clé privée (dérivée du SSOT) | ❌ Non |
| `generate-ssh-keys.sh` | `scripts/` | Procédure génération | ✅ Oui |


***

## 📍 Phase 3 : SSOT - Configuration Terraform

### Explication

**Amélioration SSOT :** Utilisation de `locals` pour dériver les valeurs et éviter la répétition.

### Cycle de vie SSOT

```
terraform.tfvars (SSOT variables)
  └─> variables.tf (typage)
      └─> locals.tf (valeurs dérivées)
          └─> main.tf (utilisation)
              └─> outputs.tf (exposition)
```


### Commandes à exécuter

**Étape 3.1 : Fichier `.gitignore` SSOT**

```bash
cat > .gitignore << 'EOF'
# Terraform
.terraform/
*.tfstate
*.tfstate.*
crash.log

# SSOT Secrets (ne JAMAIS versionner)
terraform.tfvars
*.tfvars
!terraform.tfvars.example
secrets/
keys/*_ed25519
keys/*.pem

# Ansible generated (dérivé du SSOT Terraform)
Ansible/inventory/terraform.generated.yml
Ansible/inventory/*.generated.yml

# Cache
*.retry
.DS_Store
*.bak
EOF
```

**Étape 3.2 : `provider.tf` (identique)**

```bash
cat > provider.tf << 'EOF'
terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.92.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure
}
EOF
```

**Étape 3.3 : `variables.tf` (identique)**

```bash
cat > variables.tf << 'EOF'
variable "proxmox_endpoint" {
  type        = string
  description = "URL API Proxmox"
}

variable "proxmox_api_token" {
  type        = string
  description = "Token API Proxmox"
  sensitive   = true
}

variable "proxmox_insecure" {
  type    = bool
  default = true
}

variable "node_name" {
  type        = string
  description = "Node Proxmox"
}

variable "template_vmid" {
  type        = number
  description = "VMID template cloud-init"
}

variable "datastore_vm" {
  type = string
}

variable "gateway" {
  type = string
}

variable "cidr_suffix" {
  type    = number
  default = 24
}

variable "ssh_public_key" {
  type        = string
  description = "SSOT : Clé publique SSH"
}

variable "nodes" {
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
  type    = map(string)
  default = {
    tools = "taiga_hosts"
    dns   = "bind9_hosts"
  }
}
EOF
```

**Étape 3.4 : `locals.tf` (NOUVEAUTÉ SSOT) - Valeurs dérivées**

```bash
cat > locals.tf << 'EOF'
# ===================================================================
# SSOT : Valeurs dérivées automatiquement depuis var.nodes
# ===================================================================

locals {
  # Liste de tous les noms de VMs
  all_vm_names = keys(var.nodes)
  
  # Liste de toutes les IPs
  all_vm_ips = [for vm in var.nodes : vm.ip]
  
  # Map nom → IP (utilisé par outputs)
  vm_name_to_ip = {
    for name, config in var.nodes :
    name => config.ip
  }
  
  # Tags uniques utilisés dans le projet
  all_tags_used = distinct(flatten([
    for vm in var.nodes : vm.tags
  ]))
  
  # Détection automatique du bridge le plus utilisé
  most_used_bridge = element(
    [for bridge, count in {
      for bridge in distinct([for vm in var.nodes : vm.bridge]) :
      bridge => length([
        for vm in var.nodes : vm.bridge if vm.bridge == bridge
      ])
    } : bridge],
    0
  )
  
  # Configuration réseau dérivée
  network_config = {
    gateway     = var.gateway
    cidr        = var.cidr_suffix
    dns_servers = ["1.1.1.1", "1.0.0.1"] # Cloudflare DNS par défaut
  }
}
EOF
```

**Étape 3.5 : `main.tf` avec utilisation des locals**

```bash
cat > main.tf << 'EOF'
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
        address = format("%s/%d", each.value.ip, local.network_config.cidr)
        gateway = local.network_config.gateway
      }
    }

    # SSOT : Une seule source pour la clé SSH
    user_account {
      username = "ansible"
      keys     = [var.ssh_public_key]
    }
    
    dns {
      servers = local.network_config.dns_servers
    }
  }

  agent {
    enabled = true
  }
}
EOF
```

**Étape 3.6 : `ansible_inventory.tf` (identique)**

```bash
cat > ansible_inventory.tf << 'EOF'
locals {
  ansible_hosts = {
    for name, n in var.nodes :
    name => {
      ansible_host = n.ip
    }
  }

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
EOF
```

**Étape 3.7 : `outputs.tf` (NOUVEAUTÉ SSOT) - Exposition des valeurs dérivées**

```bash
cat > outputs.tf << 'EOF'
# ===================================================================
# Outputs SSOT : Exposition des données pour consommation externe
# ===================================================================

output "ansible_inventory_file" {
  description = "Chemin inventaire Ansible généré"
  value       = local_file.ansible_inventory.filename
}

output "vm_ips" {
  description = "Map des VMs et leurs IPs (SSOT dérivé)"
  value       = local.vm_name_to_ip
}

output "all_tags_used" {
  description = "Liste des tags utilisés dans le projet"
  value       = local.all_tags_used
}

output "network_summary" {
  description = "Résumé configuration réseau (SSOT)"
  value = {
    gateway     = local.network_config.gateway
    cidr_suffix = local.network_config.cidr
    dns_servers = local.network_config.dns_servers
  }
}

output "ssh_connection_string" {
  description = "Commandes SSH pour connexion (SSOT dérivé)"
  value = {
    for name, ip in local.vm_name_to_ip :
    name => "ssh -i keys/ansible_ed25519 ansible@${ip}"
  }
}
EOF
```

**Étape 3.8 : Script SSOT de génération `terraform.tfvars`**

```bash
cat > scripts/generate-tfvars.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "=== Génération terraform.tfvars (SSOT) ==="

# Vérifications SSOT
if [[ ! -f keys/ansible_ed25519.pub ]]; then
    echo "❌ Clé SSH manquante. Exécuter : ./scripts/generate-ssh-keys.sh"
    exit 1
fi

if [[ ! -f secrets/proxmox-token.txt ]]; then
    echo "❌ Token Proxmox manquant. Exécuter : ./scripts/create-proxmox-token.sh"
    exit 1
fi

SSH_PUBLIC_KEY=$(cat keys/ansible_ed25519.pub)
PROXMOX_TOKEN=$(cat secrets/proxmox-token.txt)

read -p "IP Proxmox (ex: 10.250.250.4) : " PROXMOX_IP
read -p "Node name (ex: pve4) : " NODE_NAME
read -p "Gateway (ex: 172.16.100.1) : " GATEWAY

cat > terraform.tfvars << TFVARS
# ===================================================================
# SSOT : Configuration infrastructure Proxmox
# ===================================================================
# ⚠️  FICHIER GÉNÉRÉ - NE PAS ÉDITER MANUELLEMENT
# Régénérer avec : ./scripts/generate-tfvars.sh

proxmox_endpoint  = "https://${PROXMOX_IP}:8006/"
proxmox_api_token = "${PROXMOX_TOKEN}"
proxmox_insecure  = true

node_name     = "${NODE_NAME}"
template_vmid = 9000
datastore_vm  = "local-lvm"

gateway     = "${GATEWAY}"
cidr_suffix = 24

# SSOT : Clé SSH depuis keys/ansible_ed25519.pub
ssh_public_key = "${SSH_PUBLIC_KEY}"

ansible_group_by_tag = {
  tools = "taiga_hosts"
  dns   = "bind9_hosts"
}

# ===================================================================
# SSOT : Définition des VMs
# ===================================================================
nodes = {
  tools-manager = {
    ip     = "${GATEWAY%.*}.20"
    cpu    = 2
    mem    = 4096
    disk   = 60
    bridge = "vmbr0"
    tags   = ["tools", "ansible"]
  }

  dns-server = {
    ip     = "${GATEWAY%.*}.254"
    cpu    = 2
    mem    = 1024
    disk   = 20
    bridge = "vmbr0"
    tags   = ["dns", "prod"]
  }
}
TFVARS

echo ""
echo "✅ Fichier terraform.tfvars généré depuis les SSOT"
echo "   - Clé SSH : keys/ansible_ed25519.pub"
echo "   - Token API : secrets/proxmox-token.txt"
EOF

chmod +x scripts/generate-tfvars.sh
```


### Tableau des fichiers SSOT Terraform

| Fichier | Chemin | Rôle SSOT | Versionné |
| :-- | :-- | :-- | :-- |
| `terraform.tfvars` | Racine | SSOT infrastructure | ❌ Non |
| `variables.tf` | Racine | Définition types | ✅ Oui |
| `locals.tf` | Racine | Valeurs dérivées SSOT | ✅ Oui |
| `main.tf` | Racine | Ressources (consomme SSOT) | ✅ Oui |
| `outputs.tf` | Racine | Exposition SSOT | ✅ Oui |
| `generate-tfvars.sh` | `scripts/` | Générateur SSOT | ✅ Oui |


***

## 📍 Phase 4 : SSOT - Configuration Ansible

### Explication

Ansible utilise le **SSOT Terraform** (inventaire généré) et ajoute son propre **SSOT pour la configuration applicative** via `group_vars/`.

### Cycle de vie SSOT

```
terraform.tfvars (SSOT infra)
  └─> Terraform State
      └─> terraform.generated.yml (inventaire SSOT)
          ├─> group_vars/all.yml (SSOT config globale)
          ├─> group_vars/taiga_hosts.yml (SSOT config Taiga)
          └─> group_vars/bind9_hosts.yml (SSOT config DNS)
              └─> Playbooks
                  └─> Roles
                      └─> Tasks
```


### Commandes à exécuter

**Étape 4.1 : Structure SSOT Ansible**

```bash
mkdir -p Ansible/{inventory,group_vars,host_vars,playbooks,roles}
```

**Étape 4.2 : `Ansible/ansible.cfg` avec référence SSOT**

```bash
cat > Ansible/ansible.cfg << 'EOF'
[defaults]
# SSOT : Inventaire généré par Terraform
inventory = inventory/terraform.generated.yml

host_key_checking = False
retry_files_enabled = False
roles_path = roles
interpreter_python = auto_silent

# SSOT : Clé SSH dérivée du même source
remote_user = ansible
private_key_file = ../keys/ansible_ed25519

forks = 10
gathering = smart
timeout = 30

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
EOF
```

**Étape 4.3 : `Ansible/group_vars/all.yml` (SSOT config globale)**

```bash
cat > Ansible/group_vars/all.yml << 'EOF'
---
# ===================================================================
# SSOT : Configuration globale pour toutes les VMs
# ===================================================================

# Utilisateur Ansible (synchronisé avec cloud-init)
ansible_user: ansible
ansible_become: true
ansible_become_method: sudo

# Timezone (single source)
timezone: Europe/Paris

# Packages de base (SSOT)
base_packages:
  - vim
  - htop
  - curl
  - wget
  - git
  - python3-pip
  - qemu-guest-agent

# Configuration SSH (dérivée du durcissement cloud-init)
ssh_hardening:
  password_auth: false
  root_login: false
  pubkey_auth: true
  x11_forwarding: false

# DNS (synchronisé avec Terraform locals)
dns_servers:
  - 1.1.1.1
  - 1.0.0.1

# NTP
ntp_servers:
  - 0.fr.pool.ntp.org
  - 1.fr.pool.ntp.org
EOF
```

**Étape 4.4 : `Ansible/group_vars/taiga_hosts.yml` (SSOT Taiga)**

```bash
cat > Ansible/group_vars/taiga_hosts.yml << 'EOF'
---
# ===================================================================
# SSOT : Configuration spécifique Taiga
# ===================================================================

taiga_version: "6.7.0"
taiga_domain: "taiga.local"

taiga_db:
  name: taiga
  user: taiga
  # Le mot de passe doit être dans un vault (prochain niveau SSOT)

taiga_email:
  backend: smtp
  host: localhost
  port: 25
EOF
```

**Étape 4.5 : Script de validation SSOT**

```bash
cat > Ansible/validate-ssot.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "=== Validation SSOT Ansible ==="

# Vérifier existence inventaire généré
if [[ ! -f inventory/terraform.generated.yml ]]; then
    echo "❌ Inventaire manquant : inventory/terraform.generated.yml"
    echo "   Exécuter d'abord : terraform apply"
    exit 1
fi

# Vérifier cohérence avec Terraform
echo "✓ Inventaire Terraform détecté"

# Vérifier clé SSH (SSOT)
if [[ ! -f ../keys/ansible_ed25519 ]]; then
    echo "❌ Clé SSH SSOT manquante : ../keys/ansible_ed25519"
    exit 1
fi
echo "✓ Clé SSH SSOT présente"

# Vérifier group_vars
if [[ ! -f group_vars/all.yml ]]; then
    echo "❌ SSOT config globale manquante : group_vars/all.yml"
    exit 1
fi
echo "✓ SSOT config globale présent"

# Test de connectivité
echo ""
echo "Test de connectivité Ansible..."
ansible all -m ping

echo ""
echo "✅ Validation SSOT réussie"
EOF

chmod +x Ansible/validate-ssot.sh
```


### Tableau des fichiers SSOT Ansible

| Fichier | Chemin | Rôle SSOT | Versionné |
| :-- | :-- | :-- | :-- |
| `terraform.generated.yml` | `Ansible/inventory/` | SSOT inventaire (généré) | ❌ Non |
| `group_vars/all.yml` | `Ansible/group_vars/` | SSOT config globale | ✅ Oui |
| `group_vars/taiga_hosts.yml` | `Ansible/group_vars/` | SSOT config Taiga | ✅ Oui |
| `ansible.cfg` | `Ansible/` | Référence SSOT | ✅ Oui |
| `validate-ssot.sh` | `Ansible/` | Validation SSOT | ✅ Oui |


***

## 📍 Phase 5 : Script d'orchestration SSOT (Master Script)

### Explication

Un script maître qui orchestre toutes les étapes en respectant le principe SSOT.

### Commandes à exécuter

```bash
cat > deploy-ssot.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# ===================================================================
# Script d'orchestration SSOT - Déploiement complet
# ===================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Étape 1 : Génération clés SSH (SSOT accès)
if [[ ! -f keys/ansible_ed25519 ]]; then
    log_info "Génération clé SSH SSOT..."
    ./scripts/generate-ssh-keys.sh
else
    log_info "✓ Clé SSH SSOT existante"
fi

# Étape 2 : Génération terraform.tfvars (SSOT infrastructure)
if [[ ! -f terraform.tfvars ]]; then
    log_info "Génération terraform.tfvars SSOT..."
    ./scripts/generate-tfvars.sh
else
    log_info "✓ terraform.tfvars SSOT existant"
fi

# Étape 3 : Initialisation Terraform
log_info "Initialisation Terraform..."
terraform init

# Étape 4 : Validation configuration
log_info "Validation configuration Terraform..."
terraform validate

# Étape 5 : Plan d'exécution
log_info "Calcul du plan Terraform..."
terraform plan -out=tfplan

# Étape 6 : Confirmation utilisateur
read -p "Appliquer le plan ? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warn "Déploiement annulé"
    rm -f tfplan
    exit 0
fi

# Étape 7 : Création infrastructure
log_info "Création infrastructure Proxmox..."
terraform apply tfplan
rm -f tfplan

# Étape 8 : Attente démarrage VMs
log_info "Attente boot complet VMs (cloud-init)..."
sleep 30

# Étape 9 : Validation inventaire Ansible
log_info "Validation inventaire Ansible (SSOT dérivé)..."
cd Ansible
./validate-ssot.sh

# Étape 10 : Test connectivité
log_info "Test connectivité Ansible..."
./run-ping-test.sh

log_info "✅ Déploiement SSOT terminé"
echo ""
echo "Commandes utiles :"
echo "  - Connexions SSH : terraform output ssh_connection_string"
echo "  - IPs VMs       : terraform output vm_ips"
echo "  - Résumé réseau : terraform output network_summary"
EOF

chmod +x deploy-ssot.sh
```


### Tableau du workflow SSOT

| Étape | Script | SSOT Source | SSOT Généré |
| :-- | :-- | :-- | :-- |
| 1 | `generate-ssh-keys.sh` | - | `keys/ansible_ed25519.pub` |
| 2 | `generate-tfvars.sh` | `keys/*.pub`, `secrets/token` | `terraform.tfvars` |
| 3 | `terraform init` | - | `.terraform/` |
| 4 | `terraform apply` | `terraform.tfvars` | `terraform.tfstate`, `terraform.generated.yml` |
| 5 | `validate-ssot.sh` | `terraform.generated.yml` | - |
| 6 | Playbooks Ansible | `group_vars/*.yml` | Configuration VMs |


***

## 📍 Phase 6 : Documentation SSOT

### Commandes à exécuter

```bash
cat > README.md << 'EOF'
# Projet Infrastructure DevOps - Architecture SSOT

## Principe SSOT (Single Source of Truth)

Ce projet applique rigoureusement le principe **SSOT** : chaque donnée a une seule source de vérité.

### Hiérarchie SSOT

```

1. SSOT Accès
└─> keys/ansible_ed25519.pub
└─> terraform.tfvars (ssh_public_key)
└─> Terraform (main.tf)
└─> Cloud-init
└─> VMs (/home/ansible/.ssh/authorized_keys)
2. SSOT Infrastructure
└─> terraform.tfvars
└─> Terraform State
└─> Ansible inventory (terraform.generated.yml)
3. SSOT Configuration
└─> Ansible/group_vars/all.yml
└─> Playbooks
└─> Roles
└─> VMs (config applicative)
```

## Démarrage (workflow SSOT)

```bash
# Déploiement complet automatisé
./deploy-ssot.sh
```


## Modifications (respect du SSOT)

### Modifier infrastructure (VMs)

```bash
# SSOT : terraform.tfvars
vim terraform.tfvars

terraform plan
terraform apply
```


### Modifier configuration applicative

```bash
# SSOT : group_vars/
vim Ansible/group_vars/all.yml

cd Ansible/
ansible-playbook playbooks/configure.yml
```


### Régénérer clé SSH (rotation SSOT)

```bash
./scripts/generate-ssh-keys.sh
./scripts/generate-tfvars.sh  # Met à jour le SSOT
terraform apply
```


## Validation SSOT

```bash
# Vérifier cohérence SSOT Ansible
cd Ansible/
./validate-ssot.sh

# Vérifier cohérence SSOT Terraform
terraform validate
terraform plan
```


## Fichiers SSOT (NE PAS VERSIONNER)

- `terraform.tfvars` → Généré depuis scripts
- `keys/ansible_ed25519` → Clé privée
- `secrets/` → Tokens et secrets
- `Ansible/inventory/terraform.generated.yml` → Généré par Terraform


## Fichiers sources SSOT (versionnés)

- `group_vars/*.yml` → Configuration applicative
- `variables.tf` → Schéma infrastructure
- `locals.tf` → Valeurs dérivées
- `scripts/*.sh` → Générateurs SSOT
EOF

```

***

## 📊 Tableau récapitulatif SSOT complet

| SSOT | Fichier source | Consommateurs | Générés automatiquement |
|------|----------------|---------------|-------------------------|
| **Accès SSH** | `keys/ansible_ed25519.pub` | Terraform, Ansible | `terraform.tfvars` |
| **Infrastructure** | `terraform.tfvars` | Terraform | `terraform.tfstate`, `terraform.generated.yml` |
| **Config globale** | `group_vars/all.yml` | Playbooks | - |
| **Config Taiga** | `group_vars/taiga_hosts.yml` | Rôle Taiga | - |
| **Config DNS** | `group_vars/bind9_hosts.yml` | Rôle Bind9 | - |
| **Réseau** | `locals.tf` | `main.tf`, `outputs.tf` | `network_summary` |

***

## 🎯 Avantages SSOT dans ce projet

1. **Pas de duplication** : Clé SSH définie 1 fois, utilisée partout
2. **Cohérence garantie** : Inventaire Ansible = État Terraform
3. **Traçabilité** : Chaque valeur a une origine claire
4. **Automatisation** : Scripts génèrent les fichiers dérivés
5. **Idempotence** : Rejouer les scripts produit le même résultat
6. **Sécurité** : Secrets centralisés dans `secrets/` (non versionnés)

Vous avez maintenant une architecture **SSOT complète et rigoureuse** ! Quelle phase souhaitez-vous approfondir ?


<div align="center">⁂</div>

[^1]: https://graphite.com/guides/in-depth-guide-terraform-project-structures```

