# 🏗️ Terraform et Proxmox

Ce chapitre décrit comment Terraform pilote Proxmox pour créer les VMs, de manière déclarative et reproductible.

---

## 1️⃣ Pré-requis côté Proxmox

Avant de lancer Terraform, il faut :

- Un cluster Proxmox fonctionnel (ici, le node `pve4`).
- Un **template cloud-init** prêt à être cloné (ID `9000`).
- Un **datastore** pour les disques (ex. `local-lvm`).
- Un **API token** dédié à Terraform, par exemple :
  - User : `terraform-jdk@pve4`
  - Token ID : `jdk-token`
  - Permission suffisantes sur le node et le datastore.

L'API Proxmox est accessible via HTTPS, par exemple :

- `https://10.250.250.4:8006/`

---

## 2️⃣ Provider Terraform Proxmox

Le provider est configuré dans [provider.tf](../provider.tf) :

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.92.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure
}
```

Points importants ✅ :

- Authentification par **API token**, pas par login/mot de passe.
- `insecure = true` peut être utile en lab si le certificat n'est pas signé.

Les valeurs réelles (`proxmox_endpoint`, `proxmox_api_token`, etc.) sont fournies via :

- [variables.tf](../../variables.tf) (déclaration)
- `terraform.tfvars` (valeurs locales, non versionnées)

---

## 3️⃣ Variables et définition des VMs

Les variables clés sont définies dans [variables.tf](../../variables.tf) :

- 🔐 `proxmox_api_token` : token API Proxmox.
- 🌐 `proxmox_endpoint` : URL HTTPs de l'API.
- 💾 `datastore_vm` : datastore pour les disques (ex. `local-lvm`).
- 🌉 `gateway`, `cidr_suffix` : informations réseau.
- 🔑 `ssh_public_key` : clé publique injectée pour l'utilisateur `ansible`.
- 🧱 `nodes` : map des VMs à créer, par exemple :

```hcl
nodes = {
  bind9dns = {
    ip     = "172.16.100.254"
    cpu    = 2
    mem    = 1024
    disk   = 20
    bridge = "vmbr23"
    tags   = ["DNS", "prod", "bind9"]
  }
  # ... autres VMs ...
}
```

Les valeurs concrètes sont fournies dans `terraform.tfvars` (copié depuis `terraform.tfvars.example`).

---

## 4️⃣ Ressource principale : création des VMs

La définition des VMs se trouve dans [main.tf](../../main.tf) :

- Utilisation de `for_each` sur `var.nodes`.
- Clonage du template `9000`.
- Configuration des ressources (CPU, RAM, disque).
- Configuration réseau (bridge + IP statique).
- Initialisation (cloud-init) pour créer l'utilisateur `ansible` et injecter la clé SSH.

Extrait simplifié :

```hcl
resource "proxmox_virtual_environment_vm" "vm" {
  for_each  = var.nodes
  name      = each.key
  node_name = var.node_name

  clone {
    vm_id = var.template_vmid
  }

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
```

🔍 À retenir :

- `initialization.ip_config` pilote le réseau (IP + gateway) via cloud-init.
- `initialization.user_account` crée l'utilisateur `ansible` et remplit son `authorized_keys`.
- Le bloc `agent` active le Qemu Guest Agent côté Proxmox (le service doit aussi être installé/démarré dans la VM elle-même).

---

## 5️⃣ Génération de l'inventaire Ansible

Terraform génère un inventaire Ansible dans [Ansible/inventory/terraform.generated.yml](../../Ansible/inventory/terraform.generated.yml) à l'aide d'une ressource de type `local_file` (définie dans [main.tf](../../main.tf) ou un fichier associé).

Cet inventaire :

- Contient les noms de VMs en cohérence avec `each.key` (ex. `git-lab`, `k3s-manager`, etc.).
- Associe chaque hôte à son IP (`ansible_host`), issue de la variable `nodes`.
- Est référencé automatiquement dans [Ansible/ansible.cfg](../../Ansible/ansible.cfg).

Résultat : aucun inventaire à maintenir à la main ✅.

---

## 6️⃣ Cycle de vie Terraform classique

Dans le répertoire racine du projet :

```bash
cd /home/admin1/Documents/Projet_infra_devops

# 1. Initialisation des plugins et providers
terraform init

# 2. Vérification du plan (sans appliquer)
terraform plan -auto-approve=false

# 3. Création / mise à jour de l'infra
terraform apply -auto-approve

# 4. Destruction complète si besoin
terraform destroy -auto-approve
```

Bonnes pratiques 💡 :

- Ne jamais versionner `terraform.tfstate` ou `terraform.tfvars`.
- Toujours vérifier le `plan` avant un `apply` en production.
- En cas de changement de clé SSH, **détruire et recréer** les VMs si nécessaire pour forcer la réinitialisation cloud-init.

---

## 7️⃣ Enchaînement avec la suite

Une fois les VMs créées par Terraform :

1. Elles bootent avec **cloud-init** qui applique la configuration réseau et crée l'utilisateur `ansible`.
2. Terraform a généré l'inventaire Ansible.
3. Tu peux enchaîner avec 👉 [03-cloud-init-et-ssh.md](03-cloud-init-et-ssh.md) pour les détails sur SSH et cloud-init, puis 👉 [04-ansible-et-test-de-connectivite.md](04-ansible-et-test-de-connectivite.md) pour le ping/pong.
