# 🔷 Cloud-init : Bootstrap système avec approche SSOT


***

## 📍 Explication : Rôle de Cloud-init

### Définition

Cloud-init est un **outil d'initialisation** qui s'exécute **au premier boot** d'une VM pour configurer automatiquement le système d'exploitation. Il lit des fichiers de configuration (user-data, meta-data) fournis par l'hyperviseur (Proxmox).[^1][^2]

### Les 4 missions de Cloud-init dans le projet

| Mission | Objectif SSOT | Fichier de contrôle |
| :-- | :-- | :-- |
| **Bootstrap OS** | Configuration système de base (hostname, timezone, locale) | `user-data.yaml.tftpl` |
| **Installation qemu-guest-agent** | Communication Proxmox ↔ VM | Section `packages` |
| **Durcissement SSH** | Sécurisation accès (désactivation password auth) | Section `write_files` |
| **Configuration sudoers** | Droits sudo pour utilisateur `ansible` | Section `users` |

### Principe SSOT appliqué à Cloud-init

```
SSOT Source (Terraform)
  └─> cloud-init/user-data.yaml.tftpl (template)
      └─> Terraform génère user-data final
          └─> Proxmox injecte dans VM
              └─> Cloud-init exécute au boot
                  └─> Configuration OS finale
```

**Point clé** : Cloud-init ne s'exécute qu'**une seule fois**. Après, c'est Ansible qui gère les modifications.

***

## 📍 Cycle de vie Cloud-init (complet)

### Phase 1 : Préparation (avant boot)

```
1. Template Proxmox (VMID 9000)
   └─> Contient image Ubuntu avec cloud-init préinstallé
   └─> Lecteur cloud-init (IDE2) vide

2. Terraform clone le template
   └─> Crée nouvelle VM (VMID auto)
   
3. Terraform génère user-data
   └─> Lit cloud-init/user-data.yaml.tftpl
   └─> Interpole variables (hostname, ssh_public_key)
   └─> Envoie à Proxmox via API

4. Proxmox écrit sur ISO cloud-init
   └─> Monte ISO sur IDE2 de la VM
   └─> Contient user-data + meta-data
```


### Phase 2 : Premier boot (exécution cloud-init)

```
Étape 1 : init-local (avant réseau)
  └─> Détection datasource (Proxmox/NoCloud)
  └─> Lecture /dev/sr0 (ISO cloud-init)
  └─> Parsing user-data.yaml

Étape 2 : init (avec réseau)
  └─> Configuration réseau (IP statique)
  └─> Résolution DNS
  └─> apt update

Étape 3 : modules-config
  └─> Création utilisateur ansible (section users)
  └─> Installation packages (qemu-guest-agent, python3)
  └─> Écriture fichiers (sshd_config hardening)

Étape 4 : modules-final
  └─> Exécution runcmd (systemctl enable qemu-guest-agent)
  └─> Redémarrage SSH
  └─> Création /var/lib/cloud/instance/boot-finished

Étape 5 : Finalisation
  └─> Cloud-init se désactive
  └─> Logs dans /var/log/cloud-init.log
```


### Phase 3 : Post-boot (état final)

```
Résultat final sur la VM :
  ├─> Utilisateur ansible créé avec clé SSH
  ├─> qemu-guest-agent actif
  ├─> SSH durci (no password auth)
  ├─> Sudoers configuré (NOPASSWD pour ansible)
  └─> Cloud-init désactivé (pas de réexécution)
```


***

## 📍 Architecture SSOT Cloud-init

### Diagramme de flux SSOT

```
┌─────────────────────────────────────────────────────────────┐
│ SSOT Sources                                                │
├─────────────────────────────────────────────────────────────┤
│ • keys/ansible_ed25519.pub → Clé SSH                       │
│ • terraform.tfvars → hostname, IP                           │
│ • cloud-init/user-data.yaml.tftpl → Template configuration │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Génération (Terraform)                                      │
├─────────────────────────────────────────────────────────────┤
│ templatefile("cloud-init/user-data.yaml.tftpl", {          │
│   hostname = each.key                                       │
│   ssh_public_key = var.ssh_public_key                       │
│ })                                                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Injection (Proxmox API)                                     │
├─────────────────────────────────────────────────────────────┤
│ • ISO cloud-init monté sur IDE2                             │
│ • Contient user-data généré                                 │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Exécution (Cloud-init dans VM)                              │
├─────────────────────────────────────────────────────────────┤
│ • Lecture /dev/sr0                                          │
│ • Parsing YAML                                              │
│ • Application configuration                                 │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ État Final VM                                               │
├─────────────────────────────────────────────────────────────┤
│ • /home/ansible/.ssh/authorized_keys → Clé SSH injectée    │
│ • /etc/ssh/sshd_config.d/99-hardening.conf → SSH durci     │
│ • systemctl status qemu-guest-agent → Active               │
│ • sudo ansible ALL → NOPASSWD configuré                    │
└─────────────────────────────────────────────────────────────┘
```


***

## 📍 Fichiers et code détaillés

### Fichier 1 : `cloud-init/user-data.yaml.tftpl` (SSOT Template)

**Chemin** : `cloud-init/user-data.yaml.tftpl`
**Rôle** : Template maître de configuration cloud-init
**Versionné** : ✅ Oui

```yaml
#cloud-config
# ===================================================================
# SSOT Cloud-init : Bootstrap système automatique
# ===================================================================
# Généré par Terraform depuis cloud-init/user-data.yaml.tftpl
# Variables interpolées : ${hostname}, ${ssh_public_key}

hostname: ${hostname}
manage_etc_hosts: true

# ===================================================================
# 1. Création utilisateur (SSOT accès)
# ===================================================================
users:
  - name: ansible
    groups: [adm, sudo]
    shell: /bin/bash
    # SSOT : Droits sudo sans mot de passe pour automatisation
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    # SSOT : Clé SSH injectée depuis keys/ansible_ed25519.pub
    ssh_authorized_keys:
      - ${ssh_public_key}
    lock_passwd: true  # Désactive mot de passe
    
# ===================================================================
# 2. Installation packages (SSOT dépendances)
# ===================================================================
package_update: true
package_upgrade: true

packages:
  - qemu-guest-agent    # Communication Proxmox ↔ VM
  - sudo                # Élévation privilèges
  - python3             # Requis pour Ansible
  - python3-pip         # Installation modules Python
  - vim                 # Éditeur
  - curl                # Outils réseau
  - wget
  - git

# ===================================================================
# 3. Durcissement SSH (SSOT sécurité)
# ===================================================================
write_files:
  - path: /etc/ssh/sshd_config.d/99-hardening.conf
    permissions: "0644"
    owner: root:root
    content: |
      # SSOT : Configuration SSH sécurisée
      # Désactivation authentification par mot de passe
      PasswordAuthentication no
      ChallengeResponseAuthentication no
      
      # Autorisation uniquement par clé publique
      PubkeyAuthentication yes
      
      # Désactivation login root (utiliser ansible)
      PermitRootLogin no
      
      # Désactivation X11 (inutile sur serveur)
      X11Forwarding no
      
      # Limitation tentatives authentification
      MaxAuthTries 3
      
      # Timeout connexion inactive
      ClientAliveInterval 300
      ClientAliveCountMax 2

  # Configuration timezone (SSOT)
  - path: /etc/timezone
    content: |
      Europe/Paris
    permissions: "0644"

# ===================================================================
# 4. Commandes post-installation (SSOT bootstrap)
# ===================================================================
runcmd:
  # Activation qemu-guest-agent (communication Proxmox)
  - [ systemctl, enable, --now, qemu-guest-agent ]
  
  # Redémarrage SSH pour appliquer hardening
  - [ systemctl, restart, ssh ]
  
  # Fix permissions répertoire home ansible
  - [ chown, -R, 'ansible:ansible', '/home/ansible' ]
  - [ chmod, 700, '/home/ansible/.ssh' ]
  - [ chmod, 600, '/home/ansible/.ssh/authorized_keys' ]
  
  # Configuration timezone
  - [ timedatectl, set-timezone, Europe/Paris ]
  
  # Désactivation swap (best practice Kubernetes si applicable)
  - [ swapoff, -a ]
  
  # Nettoyage cache APT
  - [ apt-get, clean ]

# ===================================================================
# 5. Configuration finale cloud-init
# ===================================================================
# Désactiver cloud-init après premier boot (idempotence)
cloud_final_modules:
  - scripts-user
  - ssh-authkey-fingerprints
  - keys-to-console
  - final-message

# Message de fin dans les logs
final_message: |
  ===================================================================
  Cloud-init bootstrap terminé (SSOT)
  Système : $DISTRIB_DESCRIPTION
  Hostname : ${hostname}
  Durée : $UPTIME secondes
  ===================================================================
```

**Explication des sections** :


| Section | Rôle SSOT | Impact sur la VM |
| :-- | :-- | :-- |
| `hostname` | Définition nom machine | `/etc/hostname` |
| `users` | Création utilisateur ansible | `/home/ansible/`, `/etc/sudoers.d/90-cloud-init-users` |
| `packages` | Installation dépendances | `apt install` exécuté |
| `write_files` | Injection configs | Fichiers créés dans `/etc/` |
| `runcmd` | Commandes post-install | Exécutées dans l'ordre |


***

### Fichier 2 : `main.tf` (Intégration Terraform)

**Chemin** : `main.tf`
**Rôle** : Utilisation du template cloud-init
**Versionné** : ✅ Oui

**Extrait pertinent** :

```hcl
resource "proxmox_virtual_environment_vm" "vm" {
  for_each  = var.nodes
  name      = each.key
  node_name = var.node_name
  tags      = sort(distinct([for t in each.value.tags : lower(t)]))

  clone {
    vm_id = var.template_vmid
  }

  # ... (cpu, memory, disk, network)

  # ===================================================================
  # SSOT Cloud-init : Génération user-data depuis template
  # ===================================================================
  initialization {
    # Configuration réseau (SSOT depuis terraform.tfvars)
    ip_config {
      ipv4 {
        address = format("%s/%d", each.value.ip, var.cidr_suffix)
        gateway = var.gateway
      }
    }

    # Configuration DNS (SSOT local)
    dns {
      servers = ["1.1.1.1", "1.0.0.1"]
    }

    # Injection utilisateur + clé SSH (SSOT accès)
    user_account {
      username = "ansible"
      keys     = [var.ssh_public_key]
    }

    # Optionnel : Utilisation template personnalisé
    # user_data_file_id = proxmox_virtual_environment_file.cloud_init[each.key].id
  }

  agent {
    enabled = true  # Active qemu-guest-agent
  }
}

# ===================================================================
# Ressource optionnelle : Upload snippet cloud-init personnalisé
# ===================================================================
# Si vous voulez utiliser user-data.yaml.tftpl au lieu de l'injection simple
resource "proxmox_virtual_environment_file" "cloud_init" {
  for_each = var.nodes

  content_type = "snippets"
  datastore_id = "local"  # Ou votre datastore snippets
  node_name    = var.node_name

  source_raw {
    data = templatefile("${path.module}/cloud-init/user-data.yaml.tftpl", {
      hostname       = each.key
      ssh_public_key = var.ssh_public_key
    })
    file_name = "user-data-${each.key}.yaml"
  }
}
```

**Note importante** : Le provider `bpg/proxmox` a **deux méthodes** pour cloud-init :

1. **Méthode simple** (utilisée actuellement) : `user_account` injecte directement user + clé SSH
2. **Méthode avancée** : `user_data_file_id` utilise un snippet personnalisé pour plus de contrôle

***

### Fichier 3 : `scripts/validate-cloud-init.sh` (Validation SSOT)

**Chemin** : `scripts/validate-cloud-init.sh`
**Rôle** : Vérifier le bootstrap cloud-init après déploiement
**Versionné** : ✅ Oui

```bash
#!/usr/bin/env bash
set -euo pipefail

# ===================================================================
# Validation SSOT Cloud-init post-déploiement
# ===================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_check() { echo -e "${YELLOW}[?]${NC} $1"; }

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <vm-ip>"
    exit 1
fi

VM_IP="$1"
SSH_KEY="../keys/ansible_ed25519"
SSH_CMD="ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no ansible@${VM_IP}"

echo "=========================================="
echo "Validation Cloud-init SSOT : ${VM_IP}"
echo "=========================================="
echo ""

# Test 1 : Connectivité SSH
log_check "Test connectivité SSH..."
if ${SSH_CMD} "echo 'SSH OK'" &>/dev/null; then
    log_info "SSH opérationnel (clé SSOT fonctionnelle)"
else
    log_error "Échec connexion SSH"
    exit 1
fi

# Test 2 : Utilisateur ansible
log_check "Vérification utilisateur ansible..."
USER_CHECK=$(${SSH_CMD} "id -un")
if [[ "${USER_CHECK}" == "ansible" ]]; then
    log_info "Utilisateur ansible créé par cloud-init"
else
    log_error "Utilisateur incorrect : ${USER_CHECK}"
    exit 1
fi

# Test 3 : Droits sudo NOPASSWD
log_check "Vérification droits sudo..."
if ${SSH_CMD} "sudo -n true" 2>/dev/null; then
    log_info "Sudo NOPASSWD configuré (cloud-init section users)"
else
    log_error "Sudo NOPASSWD non configuré"
    exit 1
fi

# Test 4 : qemu-guest-agent
log_check "Vérification qemu-guest-agent..."
QEMU_STATUS=$(${SSH_CMD} "systemctl is-active qemu-guest-agent")
if [[ "${QEMU_STATUS}" == "active" ]]; then
    log_info "qemu-guest-agent actif (cloud-init packages)"
else
    log_error "qemu-guest-agent inactif : ${QEMU_STATUS}"
    exit 1
fi

# Test 5 : Durcissement SSH
log_check "Vérification durcissement SSH..."
PASSWORD_AUTH=$(${SSH_CMD} "sudo sshd -T | grep '^passwordauthentication'")
if [[ "${PASSWORD_AUTH}" == *"no"* ]]; then
    log_info "PasswordAuthentication désactivé (cloud-init write_files)"
else
    log_error "PasswordAuthentication encore activé"
    exit 1
fi

ROOT_LOGIN=$(${SSH_CMD} "sudo sshd -T | grep '^permitrootlogin'")
if [[ "${ROOT_LOGIN}" == *"no"* ]]; then
    log_info "PermitRootLogin désactivé (cloud-init write_files)"
else
    log_error "PermitRootLogin encore activé"
    exit 1
fi

# Test 6 : Python3 (requis Ansible)
log_check "Vérification Python3..."
PYTHON_VERSION=$(${SSH_CMD} "python3 --version")
if [[ "${PYTHON_VERSION}" == Python* ]]; then
    log_info "Python3 installé : ${PYTHON_VERSION}"
else
    log_error "Python3 manquant"
    exit 1
fi

# Test 7 : Cloud-init finalisé
log_check "Vérification statut cloud-init..."
if ${SSH_CMD} "test -f /var/lib/cloud/instance/boot-finished"; then
    BOOT_TIME=$(${SSH_CMD} "cat /var/lib/cloud/instance/boot-finished")
    log_info "Cloud-init terminé : ${BOOT_TIME}"
else
    log_error "Cloud-init pas encore terminé"
    exit 1
fi

# Test 8 : Hostname
log_check "Vérification hostname..."
HOSTNAME_SET=$(${SSH_CMD} "hostname")
log_info "Hostname configuré : ${HOSTNAME_SET}"

echo ""
echo "=========================================="
log_info "Validation SSOT réussie pour ${VM_IP}"
echo "=========================================="
```

**Utilisation** :

```bash
chmod +x scripts/validate-cloud-init.sh

# Tester une VM spécifique
./scripts/validate-cloud-init.sh 172.16.100.20

# Tester toutes les VMs
terraform output -json vm_ips | jq -r '.[]' | while read ip; do
    ./scripts/validate-cloud-init.sh "$ip"
done
```


***

### Fichier 4 : `Ansible/playbooks/debug-cloud-init.yml` (Diagnostic)

**Chemin** : `Ansible/playbooks/debug-cloud-init.yml`
**Rôle** : Playbook Ansible pour inspecter l'état cloud-init
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Playbook de diagnostic Cloud-init (SSOT)
# ===================================================================
- name: Diagnostic configuration Cloud-init
  hosts: all
  gather_facts: true
  become: true

  tasks:
    # ===================================================================
    # 1. Vérification statut cloud-init
    # ===================================================================
    - name: Récupérer statut cloud-init
      ansible.builtin.command: cloud-init status --long
      register: cloud_init_status
      changed_when: false

    - name: Afficher statut cloud-init
      ansible.builtin.debug:
        msg: "{{ cloud_init_status.stdout_lines }}"

    # ===================================================================
    # 2. Vérification logs cloud-init
    # ===================================================================
    - name: Récupérer dernières lignes log cloud-init
      ansible.builtin.shell: tail -n 50 /var/log/cloud-init.log
      register: cloud_init_logs
      changed_when: false

    - name: Afficher logs cloud-init
      ansible.builtin.debug:
        msg: "{{ cloud_init_logs.stdout_lines }}"

    # ===================================================================
    # 3. Vérification user-data utilisé
    # ===================================================================
    - name: Lire user-data cloud-init
      ansible.builtin.slurp:
        src: /var/lib/cloud/instance/user-data.txt
      register: user_data_content

    - name: Afficher user-data décodé
      ansible.builtin.debug:
        msg: "{{ user_data_content.content | b64decode }}"

    # ===================================================================
    # 4. Vérification packages installés par cloud-init
    # ===================================================================
    - name: Lister packages installés (qemu-guest-agent)
      ansible.builtin.package_facts:
        manager: apt

    - name: Vérifier présence qemu-guest-agent
      ansible.builtin.assert:
        that:
          - "'qemu-guest-agent' in ansible_facts.packages"
        fail_msg: "qemu-guest-agent non installé par cloud-init"
        success_msg: "qemu-guest-agent installé (SSOT cloud-init packages)"

    # ===================================================================
    # 5. Vérification configuration SSH
    # ===================================================================
    - name: Lire configuration SSH hardening
      ansible.builtin.slurp:
        src: /etc/ssh/sshd_config.d/99-hardening.conf
      register: ssh_hardening
      failed_when: false

    - name: Afficher config SSH hardening
      ansible.builtin.debug:
        msg: "{{ ssh_hardening.content | b64decode }}"
      when: ssh_hardening.content is defined

    # ===================================================================
    # 6. Vérification utilisateur ansible
    # ===================================================================
    - name: Récupérer infos utilisateur ansible
      ansible.builtin.user:
        name: ansible
        state: present
      check_mode: true
      register: ansible_user

    - name: Afficher infos utilisateur
      ansible.builtin.debug:
        msg:
          - "User: {{ ansible_user.name }}"
          - "Shell: {{ ansible_user.shell }}"
          - "Groups: {{ ansible_user.groups }}"

    # ===================================================================
    # 7. Vérification clé SSH injectée
    # ===================================================================
    - name: Lire authorized_keys
      ansible.builtin.slurp:
        src: /home/ansible/.ssh/authorized_keys
      register: authorized_keys

    - name: Afficher clé SSH (SSOT)
      ansible.builtin.debug:
        msg: "{{ authorized_keys.content | b64decode }}"

    # ===================================================================
    # 8. Résumé cloud-init
    # ===================================================================
    - name: Générer résumé cloud-init
      ansible.builtin.debug:
        msg:
          - "==============================================="
          - "Résumé Cloud-init SSOT"
          - "==============================================="
          - "Hostname: {{ ansible_hostname }}"
          - "OS: {{ ansible_distribution }} {{ ansible_distribution_version }}"
          - "Cloud-init: {{ 'Terminé' if cloud_init_status.rc == 0 else 'En erreur' }}"
          - "qemu-guest-agent: {{ 'Installé' if 'qemu-guest-agent' in ansible_facts.packages else 'Manquant' }}"
          - "SSH hardening: {{ 'Configuré' if ssh_hardening.content is defined else 'Manquant' }}"
          - "==============================================="
```

**Utilisation** :

```bash
cd Ansible/
ansible-playbook playbooks/debug-cloud-init.yml
```


***

## 📊 Tableau récapitulatif des fichiers Cloud-init

| Fichier | Chemin | Rôle SSOT | Type | Versionné |
| :-- | :-- | :-- | :-- | :-- |
| `user-data.yaml.tftpl` | `cloud-init/` | Template maître | Template Terraform | ✅ Oui |
| `main.tf` | Racine | Génération user-data | Terraform HCL | ✅ Oui |
| `terraform.tfvars` | Racine | Variables source (hostname, clé SSH) | Variables Terraform | ❌ Non |
| `validate-cloud-init.sh` | `scripts/` | Validation post-boot | Script Bash | ✅ Oui |
| `debug-cloud-init.yml` | `Ansible/playbooks/` | Diagnostic état | Playbook Ansible | ✅ Oui |
| `/var/log/cloud-init.log` | VM (généré) | Logs exécution | Log système | N/A |
| `/var/lib/cloud/instance/user-data.txt` | VM (généré) | User-data appliqué | Fichier cloud-init | N/A |
| `/etc/ssh/sshd_config.d/99-hardening.conf` | VM (généré) | Config SSH | Fichier conf | N/A |


***

## 📍 Détail des 4 missions Cloud-init

### Mission 1 : Bootstrap système

**Fichier** : Section `hostname`, `manage_etc_hosts`

```yaml
hostname: ${hostname}
manage_etc_hosts: true
```

**Résultat sur la VM** :

- `/etc/hostname` → Contient le nom de la VM
- `/etc/hosts` → Ajout de `127.0.1.1 <hostname>`

**Validation** :

```bash
ssh ansible@<vm-ip> "hostname"
# Sortie attendue : tools-manager (ou nom de votre VM)
```


***

### Mission 2 : Installation qemu-guest-agent

**Fichier** : Sections `packages` + `runcmd`

```yaml
packages:
  - qemu-guest-agent

runcmd:
  - [ systemctl, enable, --now, qemu-guest-agent ]
```

**Cycle d'exécution** :

1. Cloud-init lance `apt update`
2. Cloud-init lance `apt install -y qemu-guest-agent`
3. Commande `systemctl enable --now` démarre le service

**Résultat sur la VM** :

- Package installé : `/usr/bin/qemu-ga`
- Service actif : `systemctl status qemu-guest-agent`
- Socket de communication : `/dev/virtio-ports/org.qemu.guest_agent.0`

**Validation Proxmox** :

```bash
# Depuis le node Proxmox
qm agent <vmid> ping
# Sortie attendue : {"return":{}}

qm agent <vmid> get-osinfo
# Sortie : infos OS récupérées depuis la VM
```

**Validation Ansible** :

```bash
ansible all -m systemd -a "name=qemu-guest-agent state=started"
```


***

### Mission 3 : Durcissement SSH

**Fichier** : Section `write_files`

```yaml
write_files:
  - path: /etc/ssh/sshd_config.d/99-hardening.conf
    permissions: "0644"
    content: |
      PasswordAuthentication no
      PubkeyAuthentication yes
      PermitRootLogin no
      X11Forwarding no
      MaxAuthTries 3
```

**Cycle d'exécution** :

1. Cloud-init crée le fichier `/etc/ssh/sshd_config.d/99-hardening.conf`
2. Commande `systemctl restart ssh` applique la nouvelle config

**Résultat sur la VM** :

- Authentification par password désactivée
- Seule la clé publique fonctionne
- Login root impossible
- X11 désactivé (inutile sur serveur)

**Test de sécurité** :

```bash
# Test 1 : Tentative connexion avec password (doit échouer)
ssh ansible@<vm-ip>
# Résultat attendu : Permission denied (publickey)

# Test 2 : Connexion avec clé (doit réussir)
ssh -i keys/ansible_ed25519 ansible@<vm-ip>
# Résultat attendu : Connexion réussie

# Test 3 : Tentative login root (doit échouer)
ssh -i keys/ansible_ed25519 root@<vm-ip>
# Résultat attendu : Permission denied
```

**Validation configuration** :

```bash
ssh -i keys/ansible_ed25519 ansible@<vm-ip> "sudo sshd -T | grep -E '(password|root|pubkey)'"
# Sortie attendue :
# passwordauthentication no
# permitrootlogin no
# pubkeyauthentication yes
```


***

### Mission 4 : Configuration sudoers

**Fichier** : Section `users`

```yaml
users:
  - name: ansible
    groups: [adm, sudo]
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    lock_passwd: true
```

**Cycle d'exécution** :

1. Cloud-init crée l'utilisateur `ansible`
2. Ajout au groupe `sudo`
3. Écriture dans `/etc/sudoers.d/90-cloud-init-users` :

```
ansible ALL=(ALL) NOPASSWD:ALL
```


**Résultat sur la VM** :

- Utilisateur `ansible` peut exécuter `sudo` sans password
- Requis pour Ansible (automatisation)

**Validation** :

```bash
# Test sudo sans password
ssh -i keys/ansible_ed25519 ansible@<vm-ip> "sudo -n whoami"
# Sortie attendue : root

# Vérifier fichier sudoers
ssh -i keys/ansible_ed25519 ansible@<vm-ip> "sudo cat /etc/sudoers.d/90-cloud-init-users"
# Sortie attendue :
# ansible ALL=(ALL) NOPASSWD:ALL
```


***

## 📍 Commandes utiles pour déboguer Cloud-init

### Sur la VM (après connexion SSH)

```bash
# Statut cloud-init
cloud-init status --long

# Logs complets
sudo cat /var/log/cloud-init.log

# User-data utilisé
sudo cat /var/lib/cloud/instance/user-data.txt

# Réexécuter cloud-init (test uniquement)
sudo cloud-init clean
sudo cloud-init init
sudo reboot
```


### Depuis Terraform

```bash
# Afficher user-data généré
terraform console
> templatefile("cloud-init/user-data.yaml.tftpl", {
    hostname = "test-vm"
    ssh_public_key = file("keys/ansible_ed25519.pub")
  })
```


***

## 🎯 Checklist de validation SSOT Cloud-init

| Étape | Commande | Résultat attendu |
| :-- | :-- | :-- |
| 1. Connexion SSH | `ssh -i keys/ansible_ed25519 ansible@<ip>` | Connexion réussie |
| 2. Sudo NOPASSWD | `ssh ... "sudo -n true"` | Pas d'erreur |
| 3. qemu-guest-agent | `ssh ... "systemctl is-active qemu-guest-agent"` | `active` |
| 4. SSH hardening | `ssh ... "sudo sshd -T \| grep passwordauth"` | `no` |
| 5. Python3 | `ssh ... "python3 --version"` | Version Python |
| 6. Hostname | `ssh ... "hostname"` | Nom de la VM |
| 7. Cloud-init terminé | `ssh ... "cloud-init status"` | `done` |

Vous avez maintenant une **compréhension complète** du rôle de Cloud-init dans l'architecture SSOT ! Des questions sur un aspect particulier ?

<div align="center">⁂</div>

[^1]: https://pve.proxmox.com/wiki/Cloud-Init_Support

[^2]: https://www.virtualizationhowto.com/2025/10/proxmox-cloud-init-made-easy-automating-vm-provisioning-like-the-cloud/

