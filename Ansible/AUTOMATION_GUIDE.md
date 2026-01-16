# Guide d'Automatisation Ansible - Bonnes Pratiques

## 📋 Table des matières

- [Prérequis](#prérequis)
- [Installation](#installation)
- [Configuration](#configuration)
- [Utilisation](#utilisation)
- [Architecture](#architecture)
- [Dépannage](#dépannage)
- [Bonnes Pratiques](#bonnes-pratiques)

---

## Prérequis

### Système
- Linux/macOS ou WSL2 sur Windows
- Python 3.8+
- pip3
- Git
- SSH client
- Ansible 2.9+ (installé via bootstrap)

### Infrastructure
- Terraform (pour générer l'inventaire)
- Accès réseau aux hôtes Proxmox/Terraform
- Clés SSH valides pour les VMs

### Configuration locale
```bash
# Clés SSH générées dans ~/.ssh/
- id_ed25519 ou id_ed25519_common (correspondant à terraform.tfvars)
- id_ed25519.pub

# Fichiers de configuration
- terraform.tfvars (dans le répertoire parent)
- ansible.cfg (dans Ansible/)
- inventory/hosts.yml (fichier de fallback)
```

---

## Installation

### 1. Bootstrap initial

```bash
cd Ansible/
chmod +x bootstrap.sh
./bootstrap.sh
```

Le script bootstrap:
- ✅ Vérifie Python 3 et pip3
- ✅ Installe Ansible si absent
- ✅ Installe les collections Ansible (requirements.yml)
- ✅ Valide la syntaxe des playbooks
- ✅ Vérifie les clés SSH

### 2. Validation manuelle

```bash
# Vérifier l'installation Ansible
ansible --version
ansible-inventory --list

# Tester la connectivité SSH
ssh -v ansible@<host>

# Vérifier les inventaires
ansible-inventory -i inventory/terraform.generated.yml --list
```

---

## Configuration

### Fichiers de configuration

#### `ansible.cfg`
Configuration centrale pour Ansible:
```ini
[defaults]
# Inventaire (Terraform généré en priorité)
inventory = inventory/terraform.generated.yml,inventory/hosts.yml

# Authentification
remote_user = ansible
timeout = 30
interpreter_python = auto_silent

# Logging
log_path = /tmp/ansible.log

# Performance
forks = 5
pipelining = True

[ssh_connection]
ssh_args = -o StrictHostKeyChecking=no \
           -o ControlMaster=auto \
           -o ControlPersist=60s
```

#### `terraform.tfvars`
Doit contenir la clé SSH publique correspondant à votre clé privée:
```terraform
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... vm-common-key"
```

#### Inventaire YAML
Structure standard Ansible:
```yaml
all:
  children:
    taiga_hosts:
      hosts:
        tools-manager:
          ansible_host: 172.16.100.20
    bind9_hosts:
      hosts:
        bind9dns:
          ansible_host: 172.16.100.254
  vars:
    ansible_user: ansible
```

---

## Utilisation

### Commandes de base

#### 1. Test de connectivité ping
```bash
./run-ping-test.sh
```

Options:
```bash
# Avec bastion/jump host
./run-ping-test.sh --bastion

# Avec clé SSH spécifique
./run-ping-test.sh --key ~/.ssh/id_ed25519_common

# Verbose/debug
./run-ping-test.sh --verbose
LOG_LEVEL=DEBUG ./run-ping-test.sh

# Aide
./run-ping-test.sh --help
```

**Output example:**
```
[2026-01-16 10:30:45] [INFO] Starting Ansible connectivity test
[2026-01-16 10:30:45] [INFO] Using inventory: inventory/terraform.generated.yml
[2026-01-16 10:30:46] [INFO] Inventory contains 8 hosts
[2026-01-16 10:30:47] [INFO] All hosts passed connectivity check
[2026-01-16 10:30:48] [SUCCESS] Connectivity test completed successfully
```

#### 2. Vérification Taiga
```bash
# Check (dry-run)
./run-taiga-check.sh

# Apply (deploy)
./run-taiga-apply.sh
```

### Commandes Ansible directes

```bash
# Inventaire
ansible-inventory --list | jq .

# Adhoc commands
ansible all -m ping
ansible taiga_hosts -m setup  # Facts gathering
ansible all -m command -a "uptime"

# Playbooks
ansible-playbook playbooks/ping-test.yml -vv
ansible-playbook playbooks/taiga.yml --check  # Dry-run

# Debugging
ansible all -vvvv -m ping  # Very verbose
ANSIBLE_DEBUG=1 ansible-playbook ...
```

---

## Architecture

### Arborescence
```
Ansible/
├── ansible.cfg              # Configuration Ansible
├── bootstrap.sh             # Installation + validation
├── run-ping-test.sh         # Test de connectivité
├── run-taiga-apply.sh       # Déploiement Taiga
├── run-taiga-check.sh       # Vérification Taiga
│
├── lib/
│   └── ssh-preflight.sh     # Setup SSH + agent
│
├── inventory/
│   ├── hosts.yml            # Inventaire statique (fallback)
│   ├── terraform.generated.yml  # Généré par Terraform
│   ├── group_vars/
│   │   ├── all.yml          # Variables pour tous les hôtes
│   │   ├── taiga_hosts.yml
│   │   └── taiga_hosts.vault.yml  # Secrets Vault
│   └── host_vars/
│       └── bind9dns.yml     # Variables pour bind9dns
│
├── playbooks/
│   ├── ping-test.yml        # Test ping/pong
│   ├── taiga.yml            # Déploiement Taiga
│   └── bind9-docker.yml     # DNS via Docker
│
└── roles/
    ├── bind9_docker/        # Role custom DNS
    ├── systemli.bind9/      # Role Bind9
    └── taiga/               # Role Taiga
```

### Flux d'exécution

```
run-ping-test.sh
    ├─> Parse arguments (--bastion, --key, --verbose)
    ├─> Load lib/ssh-preflight.sh
    ├─> Check prerequisites (ansible-playbook, ssh-keygen, etc.)
    ├─> Validate inventory
    ├─> SSH preflight:
    │   ├─> Extract Terraform public key
    │   ├─> Find matching private key (~/.ssh/id_ed25519_common)
    │   ├─> Start ssh-agent
    │   ├─> Load key into agent
    │   └─> Validate connectivity (ansible wait_for_connection)
    └─> Run playbook (playbooks/ping-test.yml)
        ├─> Wait for SSH ready (120s timeout)
        ├─> Execute ping module
        └─> Display results (SUCCESS/FAILED)
```

---

## Gestion des clés SSH

### Configuration automatique

Le script `ssh-preflight.sh` détecte automatiquement la clé SSH:

1. **Extrait** la clé publique de `terraform.tfvars`
2. **Cherche** les clés privées locales dans cet ordre:
   - `~/.ssh/id_ed25519_common` ⭐ (priorité - pour VMs)
   - `~/.ssh/id_ed25519` (clé personnelle)
   - `~/.ssh/id_rsa` (fallback RSA)
3. **Compare** type+base64 pour trouver une correspondance
4. **Charge** la clé dans `ssh-agent`

### Création de clés

```bash
# Clé sans passphrase (pour automation)
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_common -N ""

# Clé avec passphrase (sécurisé)
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "your_email@example.com"
```

### Correspondance terraform.tfvars

```bash
# Extraire votre clé publique
ssh-keygen -y -f ~/.ssh/id_ed25519_common

# Copier dans terraform.tfvars
ssh_public_key = "ssh-ed25519 AAAAC3... vm-common-key"
```

---

## Dépannage

### Problem: "No matching private key found"

```bash
# 1. Vérifier les clés présentes
ls -la ~/.ssh/id_ed25519*

# 2. Extraire la clé publique
ssh-keygen -y -f ~/.ssh/id_ed25519_common

# 3. Vérifier terraform.tfvars
grep ssh_public_key ../terraform.tfvars

# 4. Créer la clé manquante si nécessaire
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_common -N ""
```

### Problem: "Permission denied (publickey)"

```bash
# 1. Vérifier les permissions clé
stat ~/.ssh/id_ed25519_common
# Doit être: -rw------- (600)

chmod 600 ~/.ssh/id_ed25519_common

# 2. Tester SSH direct
ssh -vvv -i ~/.ssh/id_ed25519_common ansible@172.16.100.254

# 3. Vérifier que la clé est dans l'hôte
cat ~/.ssh/id_ed25519_common.pub
```

### Problem: "SSH agent refused operation"

```bash
# 1. Tuer agent zombie
pkill -f ssh-agent
pkill -f ssh-add

# 2. Redémarrer
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519_common

# 3. Vérifier
ssh-add -l
```

### Problem: "REMOTE HOST IDENTIFICATION HAS CHANGED"

```bash
# Le script nettoie automatiquement known_hosts
# Manuel si nécessaire:
ssh-keygen -R 172.16.100.254
ssh-keygen -R tools-manager
```

### Problem: Playbook timeout

```bash
# Augmenter timeout (ansible.cfg)
timeout = 60

# Vérifier la connectivité
./run-ping-test.sh

# Logs détaillés
LOG_LEVEL=DEBUG ./run-ping-test.sh -vvvv
tail -f /tmp/ansible.log
```

### Enable debug logging

```bash
# Via environment variable
LOG_LEVEL=DEBUG ./run-ping-test.sh
ANSIBLE_DEBUG=1 ansible-playbook playbooks/ping-test.yml

# Via command line
./run-ping-test.sh --verbose

# Check logs
tail -f /tmp/ansible.log
```

---

## Bonnes Pratiques

### 1. Gestion des secrets (Vault)

```bash
# Créer fichier secret
ansible-vault create inventory/group_vars/taiga_hosts.vault.yml

# Éditer
ansible-vault edit inventory/group_vars/taiga_hosts.vault.yml

# Exécution
ansible-playbook playbooks/taiga.yml --ask-vault-pass
# Ou
export ANSIBLE_VAULT_PASSWORD_FILE=~/.vault_pass
ansible-playbook playbooks/taiga.yml
```

### 2. Idempotence des playbooks

Les playbooks doivent être idempotents:
```yaml
---
- name: Ensure package installed
  apt:
    name: nginx
    state: present  # ✓ Idempotent
    # ❌ Avoid: command: apt-get install nginx

- name: Ensure service running
  service:
    name: nginx
    state: started  # ✓ Idempotent
    enabled: yes
```

### 3. Organisation des variables

```yaml
# group_vars/all.yml - Toutes les hôtes
# group_vars/taiga_hosts.yml - Groupe spécifique
# host_vars/bind9dns.yml - Hôte spécifique
```

### 4. Stratégie de déploiement

```bash
# 1. Test syntaxe
ansible-playbook --syntax-check playbooks/taiga.yml

# 2. Dry-run (check mode)
ansible-playbook playbooks/taiga.yml --check

# 3. Exécution sur subset
ansible-playbook playbooks/taiga.yml --limit taiga_hosts[0]

# 4. Déploiement complet
ansible-playbook playbooks/taiga.yml
```

### 5. Performance

```ini
# ansible.cfg
[defaults]
forks = 5               # Paralléliser 5 connexions
pipelining = True       # Réduire SSH roundtrips
fact_caching = jsonfile # Cacher les facts
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 86400
```

### 6. Logs et audit

```bash
# Logs centralisés
tail -f /tmp/ansible.log

# Sauvegarder résultats
ansible-playbook playbooks/taiga.yml \
  -e 'ansible_log_file=/tmp/taiga_deploy.log'

# Retry files
ls -la retry_files/
```

---

## Référence externe

- 🔗 [Ansible Official Docs](https://docs.ansible.com/)
- 🔗 [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- 🔗 [SSH Best Practices](https://man.openbsd.org/ssh)
- 🔗 [Bash Best Practices](https://www.gnu.org/software/bash/manual/)
- 🔗 [Python venv Guide](https://docs.python.org/3/library/venv.html)

---

## Support et contribution

Pour les issues ou améliorations:
1. Vérifier les logs: `LOG_LEVEL=DEBUG ./run-ping-test.sh`
2. Tester la connectivité SSH directe
3. Valider l'inventaire: `ansible-inventory --list`
4. Consulter la documentation officielle

---

**Last Updated:** 2026-01-16  
**Maintained by:** Infrastructure Team
