Je dois créer en partant de 0, un projet a peut prêt identique.
Par quoi je commence ?

Parfait ! Je vais vous guider **pas à pas** pour créer votre projet depuis zéro, avec explication, cycle de vie et tableau des fichiers.

***

# 🚀 Création d'un projet Terraform + Ansible + Proxmox depuis zéro


***

## 📍 Phase 1 : Préparation de l'environnement Proxmox

### Explication

Avant Terraform, vous devez créer un **template cloud-init** sur Proxmox. C'est l'image de base que Terraform clonera pour créer les VMs.[^1][^2][^3]

### Cycle de vie

```
1. Téléchargement image Ubuntu cloud → Image QCOW2 stockée sur Proxmox
2. Création VM template (VMID 9000) → Template disponible pour clonage
3. Configuration cloud-init drive → Lecteur IDE2 activé
4. Conversion en template → Template verrouillé (non démarrable)
```


### Commandes à exécuter

**Étape 1.1 : Connexion SSH à Proxmox**

```bash
ssh root@<ip-proxmox>
```

**Étape 1.2 : Téléchargement de l'image Ubuntu 24.04 LTS **[^3][^4]

```bash
wget https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img \
  -O /var/lib/vz/template/iso/ubuntu-24.04-cloudimg-amd64.img
```

**Étape 1.3 : Création de la VM template **[^4][^5]

```bash
# Création VM vide (VMID 9000)
qm create 9000 \
  --name ubuntu-2404-cloudinit-template \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0

# Import du disque cloud-init
qm importdisk 9000 \
  /var/lib/vz/template/iso/ubuntu-24.04-cloudimg-amd64.img \
  local-lvm

# Attachement du disque comme SCSI0
qm set 9000 \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:vm-9000-disk-0

# Ajout du lecteur cloud-init (IDE2)
qm set 9000 --ide2 local-lvm:cloudinit

# Configuration du boot
qm set 9000 \
  --boot order=scsi0 \
  --bootdisk scsi0

# Console série (requis pour cloud-init)
qm set 9000 \
  --serial0 socket \
  --vga serial0

# Activation qemu-guest-agent
qm set 9000 --agent enabled=1

# Conversion en template
qm template 9000
```

**Étape 1.4 : Création d'un token API Proxmox **[^6][^7]

```bash
# Dans l'interface Proxmox Web UI :
# Datacenter → Permissions → API Tokens → Add
# User: root@pam
# Token ID: terraform
# Privilege Separation: Décoché (unchecked)
# 
# Copier le token généré : root@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**Étape 1.5 : Configuration du datastore snippets **[^8]

```bash
# Vérifier les datastores disponibles
pvesm status

# Activer le content type 'snippets' sur un datastore
pvesm set local --content vztmpl,iso,snippets

# Créer le dossier snippets si inexistant
mkdir -p /var/lib/vz/snippets
```


### Tableau des fichiers

| Fichier/Ressource | Localisation | Rôle |
| :-- | :-- | :-- |
| Image cloud-init | `/var/lib/vz/template/iso/ubuntu-24.04-cloudimg-amd64.img` | Image de base Ubuntu |
| Template VM | Proxmox VMID 9000 | Template clonable |
| Token API | Proxmox UI → API Tokens | Authentification Terraform |
| Datastore snippets | `/var/lib/vz/snippets/` | Stockage des fichiers cloud-init |


***

## 📍 Phase 2 : Structure du projet Terraform

### Explication

Création de l'arborescence du projet avec séparation des responsabilités (provider, variables, ressources, inventaire).[^9][^6]

### Cycle de vie

```
1. Création dossiers → Structure projet vide
2. Initialisation Git → Version control activé
3. Configuration .gitignore → Secrets exclus du versioning
4. Création fichiers Terraform → Infrastructure as Code
```


### Commandes à exécuter

**Étape 2.1 : Création de l'arborescence **[^9]

```bash
# Création du projet
mkdir -p ~/projet-infra-devops
cd ~/projet-infra-devops

# Structure Terraform
mkdir -p cloud-init
mkdir -p Ansible/{inventory,playbooks,roles}
mkdir -p keys

# Initialisation Git
git init
```

**Étape 2.2 : Création du `.gitignore`**

```bash
cat > .gitignore << 'EOF'
# Terraform
.terraform/
*.tfstate
*.tfstate.*
crash.log
*.tfstate.backup

# Secrets
terraform.tfvars
*.tfvars
*.tfvars.json

# Clés SSH
keys/*.pem
keys/*_rsa
keys/*_ed25519

# Ansible generated
Ansible/inventory/terraform.generated.yml

# Backups
*.bak
*.BACKUP.*

# OS
.DS_Store
EOF
```

**Étape 2.3 : Génération de la clé SSH pour Ansible**

```bash
# Génération clé ED25519 (plus sécurisé que RSA)
ssh-keygen -t ed25519 -C "ansible@proxmox" -f keys/ansible_ed25519 -N ""

# Permissions sécurisées
chmod 600 keys/ansible_ed25519
chmod 644 keys/ansible_ed25519.pub
```


### Tableau des fichiers

| Fichier | Chemin | Rôle |
| :-- | :-- | :-- |
| `.gitignore` | Racine | Exclusion secrets du versioning |
| `keys/ansible_ed25519` | `keys/` | Clé privée SSH (NON versionnée) |
| `keys/ansible_ed25519.pub` | `keys/` | Clé publique SSH (versionnée) |
| `cloud-init/` | Racine | Templates cloud-init |
| `Ansible/` | Racine | Configuration Ansible |


***

## 📍 Phase 3 : Configuration Terraform

### Explication

Création des fichiers Terraform pour définir l'infrastructure (provider, variables, ressources VMs, génération inventaire Ansible).

### Cycle de vie

```
1. Définition provider → Connexion API Proxmox
2. Déclaration variables → Inputs paramétrables
3. Création ressources → VMs à provisionner
4. Génération outputs → Inventaire Ansible automatique
```


### Commandes à exécuter

**Étape 3.1 : Fichier `provider.tf`**

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

**Étape 3.2 : Fichier `variables.tf`**

```bash
cat > variables.tf << 'EOF'
variable "proxmox_endpoint" {
  type        = string
  description = "URL API Proxmox (ex: https://10.250.250.4:8006/)"
}

variable "proxmox_api_token" {
  type        = string
  description = "Token API format user@realm!token=SECRET"
  sensitive   = true
}

variable "proxmox_insecure" {
  type        = bool
  description = "Accepter certificat auto-signé"
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

variable "gateway" {
  type        = string
  description = "Gateway IPv4 réseau"
}

variable "cidr_suffix" {
  type        = number
  description = "Suffixe CIDR (ex: 24 pour /24)"
  default     = 24
}

variable "ssh_public_key" {
  type        = string
  description = "Clé publique SSH pour user ansible"
}

variable "nodes" {
  description = "Map des VMs à créer"
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
  description = "Mapping tags → groupes Ansible"
  default = {
    tools = "taiga_hosts"
    dns   = "bind9_hosts"
  }
}
EOF
```

**Étape 3.3 : Fichier `main.tf`**

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
        address = format("%s/%d", each.value.ip, var.cidr_suffix)
        gateway = var.gateway
      }
    }

    user_account {
      username = "ansible"
      keys     = [var.ssh_public_key]
    }
  }

  agent {
    enabled = true
  }
}
EOF
```

**Étape 3.4 : Fichier `ansible_inventory.tf`**

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

output "ansible_inventory_file" {
  value = local_file.ansible_inventory.filename
}

output "nodes_by_ip" {
  value = { for name, n in var.nodes : name => n.ip }
}
EOF
```

**Étape 3.5 : Fichier `terraform.tfvars.example`**

```bash
cat > terraform.tfvars.example << 'EOF'
# ⚠️ COPIER CE FICHIER VERS terraform.tfvars (non versionné)

proxmox_endpoint  = "https://<ip-proxmox>:8006/"
proxmox_api_token = "root@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
proxmox_insecure  = true

node_name     = "pve4"
template_vmid = 9000
datastore_vm  = "local-lvm"

gateway     = "172.16.100.1"
cidr_suffix = 24

ssh_public_key = "CONTENU_DU_FICHIER keys/ansible_ed25519.pub"

ansible_group_by_tag = {
  tools = "taiga_hosts"
  dns   = "bind9_hosts"
}

nodes = {
  tools-manager = {
    ip     = "172.16.100.20"
    cpu    = 2
    mem    = 4096
    disk   = 60
    bridge = "vmbr0"
    tags   = ["tools", "ansible"]
  }

  dns-server = {
    ip     = "172.16.100.254"
    cpu    = 2
    mem    = 1024
    disk   = 20
    bridge = "vmbr0"
    tags   = ["dns", "prod"]
  }
}
EOF
```

**Étape 3.6 : Création de votre fichier `terraform.tfvars` (SECRETS)**

```bash
# Copier le fichier exemple
cp terraform.tfvars.example terraform.tfvars

# Éditer avec vos vraies valeurs
nano terraform.tfvars

# Remplacer :
# - <ip-proxmox> par l'IP de votre Proxmox
# - Le token API par celui généré en Phase 1
# - ssh_public_key par le contenu de keys/ansible_ed25519.pub
```


### Tableau des fichiers

| Fichier | Chemin | Rôle | Versionné |
| :-- | :-- | :-- | :-- |
| `provider.tf` | Racine | Configuration providers Terraform | ✅ Oui |
| `variables.tf` | Racine | Définition des variables d'entrée | ✅ Oui |
| `main.tf` | Racine | Ressources VMs Proxmox | ✅ Oui |
| `ansible_inventory.tf` | Racine | Génération inventaire Ansible | ✅ Oui |
| `terraform.tfvars.example` | Racine | Exemple de configuration | ✅ Oui |
| `terraform.tfvars` | Racine | Configuration réelle (SECRETS) | ❌ Non |


***

## 📍 Phase 4 : Template cloud-init (optionnel avancé)

### Explication

Création d'un template cloud-init personnalisé pour le durcissement SSH et l'installation de packages spécifiques.

### Cycle de vie

```
1. Création template .tftpl → Template avec variables Terraform
2. Upload snippet sur Proxmox → Fichier accessible par VMs
3. Référence dans main.tf → Terraform lie le snippet à la VM
4. Injection au boot → Cloud-init exécute le snippet
```


### Commandes à exécuter

**Étape 4.1 : Fichier `cloud-init/user-data.yaml.tftpl`**

```bash
cat > cloud-init/user-data.yaml.tftpl << 'EOF'
#cloud-config
hostname: ${hostname}
manage_etc_hosts: true

users:
  - name: ansible
    groups: [adm, sudo]
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - ${ssh_public_key}

package_update: true
package_upgrade: true

packages:
  - qemu-guest-agent
  - sudo
  - python3
  - python3-pip

write_files:
  - path: /etc/ssh/sshd_config.d/99-hardening.conf
    permissions: "0644"
    content: |
      PasswordAuthentication no
      PubkeyAuthentication yes
      PermitRootLogin no
      X11Forwarding no

runcmd:
  - [ systemctl, enable, --now, qemu-guest-agent ]
  - [ systemctl, restart, ssh ]
  - [ chown, -R, 'ansible:ansible', '/home/ansible' ]
EOF
```

**Note :** Cette étape est **optionnelle**. Le template Proxmox créé en Phase 1 suffit pour un démarrage rapide. Le snippet personnalisé ajoute du durcissement SSH.

### Tableau des fichiers

| Fichier | Chemin | Rôle | Versionné |
| :-- | :-- | :-- | :-- |
| `user-data.yaml.tftpl` | `cloud-init/` | Template cloud-init personnalisé | ✅ Oui |


***

## 📍 Phase 5 : Configuration Ansible

### Explication

Préparation de la structure Ansible pour orchestrer les configurations post-déploiement des VMs.

### Cycle de vie

```
1. Création ansible.cfg → Configuration globale Ansible
2. Création playbooks → Tâches d'orchestration
3. Création roles → Logique métier réutilisable
4. Exécution playbooks → Configuration VMs
```


### Commandes à exécuter

**Étape 5.1 : Fichier `Ansible/ansible.cfg`**

```bash
cat > Ansible/ansible.cfg << 'EOF'
[defaults]
inventory = inventory/terraform.generated.yml
host_key_checking = False
retry_files_enabled = False
roles_path = roles
interpreter_python = auto_silent

# Performance
forks = 10
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 3600

# SSH
remote_user = ansible
private_key_file = ../keys/ansible_ed25519
timeout = 30

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
EOF
```

**Étape 5.2 : Script de test de connectivité `Ansible/run-ping-test.sh`**

```bash
cat > Ansible/run-ping-test.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

ansible all -m ping -v
EOF

chmod +x Ansible/run-ping-test.sh
```

**Étape 5.3 : Playbook de test `Ansible/playbooks/test.yml`**

```bash
mkdir -p Ansible/playbooks

cat > Ansible/playbooks/test.yml << 'EOF'
---
- name: Test connectivité et gather facts
  hosts: all
  gather_facts: true
  
  tasks:
    - name: Afficher OS et version
      ansible.builtin.debug:
        msg: "{{ ansible_distribution }} {{ ansible_distribution_version }}"
    
    - name: Vérifier qemu-guest-agent
      ansible.builtin.systemd:
        name: qemu-guest-agent
        state: started
        enabled: true
EOF
```


### Tableau des fichiers

| Fichier | Chemin | Rôle | Versionné |
| :-- | :-- | :-- | :-- |
| `ansible.cfg` | `Ansible/` | Configuration globale Ansible | ✅ Oui |
| `run-ping-test.sh` | `Ansible/` | Script test connectivité | ✅ Oui |
| `playbooks/test.yml` | `Ansible/playbooks/` | Playbook de test | ✅ Oui |
| `inventory/terraform.generated.yml` | `Ansible/inventory/` | Inventaire généré (auto) | ❌ Non |


***

## 📍 Phase 6 : Déploiement et validation

### Explication

Initialisation Terraform, création des VMs et validation de la connectivité Ansible.

### Cycle de vie

```
1. terraform init → Téléchargement providers
2. terraform plan → Calcul du plan d'exécution
3. terraform apply → Création des VMs sur Proxmox
4. Cloud-init boot → Configuration automatique des VMs
5. ansible ping → Validation connectivité SSH
```


### Commandes à exécuter

**Étape 6.1 : Initialisation Terraform**

```bash
terraform init
```

**Sortie attendue :**

```
Initializing provider plugins...
- Installing bpg/proxmox v0.92.0...
- Installing hashicorp/local v2.4.0...

Terraform has been successfully initialized!
```

**Étape 6.2 : Validation de la configuration**

```bash
terraform validate
```

**Étape 6.3 : Plan d'exécution**

```bash
terraform plan -input=false
```

**Sortie attendue :**

```
Plan: 3 to add, 0 to change, 0 to destroy.
  + proxmox_virtual_environment_vm.vm["tools-manager"]
  + proxmox_virtual_environment_vm.vm["dns-server"]
  + local_file.ansible_inventory
```

**Étape 6.4 : Application (création des VMs)**

```bash
terraform apply -auto-approve
```

**Durée estimée :** 2-3 minutes

**Étape 6.5 : Vérification de l'inventaire Ansible**

```bash
cat Ansible/inventory/terraform.generated.yml
```

**Sortie attendue :**

```yaml
all:
  children:
    bind9_hosts:
      hosts:
        dns-server: {}
    taiga_hosts:
      hosts:
        tools-manager: {}
  hosts:
    dns-server:
      ansible_host: 172.16.100.254
    tools-manager:
      ansible_host: 172.16.100.20
```

**Étape 6.6 : Test de connectivité SSH**

```bash
# Test direct
ssh -i keys/ansible_ed25519 ansible@172.16.100.20

# Test via Ansible
cd Ansible/
./run-ping-test.sh
```

**Sortie attendue :**

```
tools-manager | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
dns-server | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

**Étape 6.7 : Exécution du playbook de test**

```bash
ansible-playbook playbooks/test.yml
```


### Tableau des fichiers générés

| Fichier | Chemin | Rôle | Généré par |
| :-- | :-- | :-- | :-- |
| `.terraform.lock.hcl` | Racine | Verrouillage versions providers | `terraform init` |
| `terraform.tfstate` | Racine | État actuel infrastructure | `terraform apply` |
| `terraform.generated.yml` | `Ansible/inventory/` | Inventaire Ansible | `terraform apply` |


***

## 📍 Phase 7 : Versioning Git (finalisation)

### Explication

Commit initial du projet avec exclusion des secrets.

### Cycle de vie

```
1. git add → Staging fichiers versionnables
2. git commit → Création commit initial
3. git remote add → Lien vers dépôt distant
4. git push → Synchronisation avec GitHub
```


### Commandes à exécuter

```bash
# Ajout de tous les fichiers versionnables
git add .

# Commit initial
git commit -m "feat: infrastructure initiale Terraform + Ansible + Proxmox

- Template cloud-init Ubuntu 24.04
- Provisionnement automatisé Proxmox
- Génération inventaire Ansible
- Durcissement SSH
- Configuration qemu-guest-agent"

# Lien vers dépôt distant (remplacer par votre URL)
git remote add origin git@github.com:VotreUsername/projet-infra-devops.git

# Push initial
git push -u origin main
```


### Vérification de sécurité

```bash
# Vérifier qu'aucun secret n'est versionné
git log --all --full-history -- terraform.tfvars
# Doit retourner vide

git log --all --full-history -- keys/ansible_ed25519
# Doit retourner vide
```


***

## 📊 Récapitulatif : ordre des étapes

| Phase | Outil | Durée | Sortie |
| :-- | :-- | :-- | :-- |
| 1. Préparation Proxmox | CLI Proxmox | 10 min | Template VMID 9000 + Token API |
| 2. Structure projet | Bash + Git | 5 min | Arborescence + .gitignore |
| 3. Configuration Terraform | HCL | 15 min | Fichiers `*.tf` + `terraform.tfvars` |
| 4. Template cloud-init | YAML | 5 min | `user-data.yaml.tftpl` (optionnel) |
| 5. Configuration Ansible | YAML + Bash | 10 min | `ansible.cfg` + playbooks |
| 6. Déploiement | Terraform + Ansible | 5 min | VMs opérationnelles |
| 7. Versioning Git | Git | 3 min | Projet sur GitHub |

**Durée totale estimée :** 53 minutes

***

## 📁 Tableau complet des fichiers du projet

| Fichier | Chemin | Versionné | Rôle |
| :-- | :-- | :-- | :-- |
| `.gitignore` | Racine | ✅ | Exclusion secrets |
| `provider.tf` | Racine | ✅ | Config provider Proxmox |
| `variables.tf` | Racine | ✅ | Définition variables |
| `main.tf` | Racine | ✅ | Ressources VMs |
| `ansible_inventory.tf` | Racine | ✅ | Génération inventaire |
| `terraform.tfvars.example` | Racine | ✅ | Exemple config |
| `terraform.tfvars` | Racine | ❌ | Config réelle (SECRETS) |
| `terraform.tfstate` | Racine | ❌ | État infrastructure |
| `.terraform.lock.hcl` | Racine | ✅ | Lock versions providers |
| `user-data.yaml.tftpl` | `cloud-init/` | ✅ | Template cloud-init |
| `ansible_ed25519` | `keys/` | ❌ | Clé privée SSH |
| `ansible_ed25519.pub` | `keys/` | ✅ | Clé publique SSH |
| `ansible.cfg` | `Ansible/` | ✅ | Config Ansible |
| `terraform.generated.yml` | `Ansible/inventory/` | ❌ | Inventaire auto-généré |
| `run-ping-test.sh` | `Ansible/` | ✅ | Test connectivité |
| `test.yml` | `Ansible/playbooks/` | ✅ | Playbook test |


***

Vous avez maintenant **tous les éléments** pour créer votre projet depuis zéro. Par quelle phase souhaitez-vous commencer ?
<span style="display:none">[^10][^11][^12][^13][^14][^15]</span>

<div align="center">⁂</div>

[^1]: https://www.bejean.eu/2023/03/24/creer-des-templates-de-vm-avec-cloud-init

[^2]: https://www.youtube.com/watch?v=kAhIQvMqG8c

[^3]: https://dev.to/minerninja/create-an-ubuntu-cloud-init-template-on-proxmox-the-command-line-guide-5b61

[^4]: https://marcinmitruk.link/posts/proxmox-cloud-ubuntu-template-creation/

[^5]: https://austinsnerdythings.com/2021/08/30/how-to-create-a-proxmox-ubuntu-cloud-init-image/

[^6]: https://readyspace.com.au/proxmox-terraform-provider/

[^7]: https://spacelift.io/blog/terraform-proxmox-provider

[^8]: https://pve.proxmox.com/wiki/Cloud-Init_Support

[^9]: https://graphite.com/guides/in-depth-guide-terraform-project-structures

[^10]: https://www.reddit.com/r/Proxmox/comments/12emrrc/i_made_a_guide_for_setting_up_a_ubuntu_cloudinit/

[^11]: https://forum.proxmox.com/threads/cloud-init-template-creation-script.127015/

[^12]: https://www.thomas-krenn.com/en/wiki/Cloud_Init_Templates_in_Proxmox_VE_-_Quickstart

[^13]: https://ettoreciarcia.com/publication/18-proxmox-and-terraform/

[^14]: https://austinsnerdythings.com/2021/09/01/how-to-deploy-vms-in-proxmox-with-terraform/

[^15]: https://www.reddit.com/r/selfhosted/comments/ygsajk/i_created_a_guide_showing_how_to_create_a_proxmox/

