# 📋 Description du Space "Projet DEVOPS"

## 🎯 Architecture Globale du Projet

### Stack technique

- **Proxmox 9.1.1** : Hyperviseur de virtualisation
- **Terraform** : Provisionnement infrastructure (IaC)
- **Cloud-init** : Bootstrap automatique des VMs
- **Ansible** : Configuration et gestion des services
- **Git** : Versioning et traçabilité


### Principe SSOT (Single Source of Truth)

Le projet applique **rigoureusement** le principe SSOT : chaque donnée a une seule source de vérité, toutes les autres configurations en découlent automatiquement.

***

## 🔷 Points Clés DevSecOps

### Sécurité

- **Une seule source de vérité pour l'accès SSH** : `keys/ansible_ed25519.pub` → Terraform → Cloud-init → VMs
- **Secrets non versionnés** : `.gitignore` exclut `terraform.tfvars`, `*.tfstate*`, `secrets/`, `keys/*_ed25519`
- **Durcissement SSH automatique** : Désactivation password auth, root login, X11 forwarding
- **Firewall UFW** : Configuration automatique avec politique deny par défaut
- **Sudo NOPASSWD** : Uniquement pour utilisateur `ansible` (automatisation)


### Automatisation

- **Connexion 100% automatisée** : Pas d'intervention manuelle entre `terraform apply` et connexion Ansible
- **Génération dynamique inventaire** : `terraform.generated.yml` créé automatiquement
- **Scripts d'orchestration** : `deploy-ssot.sh`, `bootstrap.sh`, `validate.sh`
- **CI/CD ready** : Workflows reproductibles et testables


### Idempotence

- **Playbooks Ansible rejouables** : Détection de l'état actuel vs désiré, application uniquement des changements nécessaires
- **Ressources Terraform** : Modification in-place quand possible, destruction-recréation uniquement si requis
- **Handlers conditionnels** : Redémarrages services uniquement si configuration modifiée


### Traçabilité

- **Git comme source de vérité** : Tous les fichiers de configuration versionnés (sauf secrets)
- **Outputs Terraform** : Exposition des données infrastructure (`vm_ips`, `ssh_connection_string`)
- **Logs centralisés** : Cloud-init (`/var/log/cloud-init.log`), Ansible (stdout), services applicatifs

***

## 📊 Hiérarchie SSOT du Projet

### 1. SSOT Accès SSH

```
keys/ansible_ed25519.pub (source unique)
  └─> terraform.tfvars (ssh_public_key)
      └─> main.tf (user_account.keys)
          └─> Cloud-init (authorized_keys)
              └─> VMs (/home/ansible/.ssh/authorized_keys)
              └─> Ansible (private_key_file)
```


### 2. SSOT Infrastructure

```
terraform.tfvars (définition VMs, réseau)
  └─> Terraform State (état réel infrastructure)
      └─> ansible_inventory.tf (génération inventaire)
          └─> terraform.generated.yml (consommé par Ansible)
```


### 3. SSOT Configuration Applicative

```
Ansible/group_vars/ (configuration services)
  ├─> all.yml (config globale toutes VMs)
  ├─> taiga_hosts.yml (config Taiga)
  └─> bind9_hosts.yml (config DNS)
      └─> Playbooks (orchestration)
          └─> Roles (logique métier)
              └─> Tasks (actions idempotentes)
                  └─> VMs (état final désiré)
```


***

## 🔧 Terraform : Provisionnement Infrastructure

### Responsabilités

- Création VMs Proxmox par clonage du template cloud-init
- Configuration CPU, RAM, disque, réseau
- Injection clé SSH publique et configuration IP statique
- Génération automatique inventaire Ansible (`terraform.generated.yml`)


### Fichiers clés

| Fichier | Rôle | Versionné |
| :-- | :-- | :-- |
| `provider.tf` | Configuration provider Proxmox | ✅ Oui |
| `variables.tf` | Définition variables d'entrée | ✅ Oui |
| `locals.tf` | Valeurs dérivées automatiquement | ✅ Oui |
| `main.tf` | Ressources VMs | ✅ Oui |
| `ansible_inventory.tf` | Génération inventaire Ansible | ✅ Oui |
| `outputs.tf` | Exposition données (IPs, connexions SSH) | ✅ Oui |
| `terraform.tfvars` | **SSOT infrastructure (SECRETS)** | ❌ Non |
| `terraform.tfstate` | État infrastructure | ❌ Non |

### Commandes essentielles

```bash
terraform init                    # Initialisation providers
terraform validate                # Validation syntaxe
terraform plan -input=false       # Calcul plan d'exécution
terraform apply -auto-approve     # Application modifications
terraform output vm_ips           # Afficher IPs VMs
terraform output ssh_connection_string  # Commandes SSH
```


### Modifications infrastructure (best practices)

- **CPU/RAM/Disque** : Modifier `terraform.tfvars` → `terraform apply` (hot-plug si possible)
- **IP statique** : Modifier `terraform.tfvars` → `terraform apply` → Redémarrer VM
- **Ajout VM** : Ajouter dans `nodes{}` → `terraform apply` → Inventaire Ansible mis à jour automatiquement

***

## ☁️ Cloud-init : Bootstrap Système

### Responsabilités (exécution unique au premier boot)

- Configuration OS de base (hostname, timezone, locale)
- Installation packages système (qemu-guest-agent, Python3, Docker)
- Durcissement SSH (désactivation password auth, root login)
- Configuration sudoers (NOPASSWD pour utilisateur `ansible`)
- Création utilisateur `ansible` avec clé SSH injectée


### Fichiers clés

| Fichier | Rôle | Versionné |
| :-- | :-- | :-- |
| `cloud-init/user-data.yaml.tftpl` | Template configuration cloud-init | ✅ Oui |
| `/var/log/cloud-init.log` (VM) | Logs exécution bootstrap | N/A |
| `/var/lib/cloud/instance/boot-finished` (VM) | Témoin fin d'exécution | N/A |

### Les 4 missions Cloud-init

1. **Bootstrap OS** : Hostname, timezone, réseau statique
2. **Installation qemu-guest-agent** : Communication Proxmox ↔ VM (backup cohérent, shutdown propre)
3. **Durcissement SSH** : `PasswordAuthentication no`, `PermitRootLogin no`, `PubkeyAuthentication yes`
4. **Configuration sudoers** : `ansible ALL=(ALL) NOPASSWD:ALL`

### Validation Cloud-init

```bash
# Sur la VM
cloud-init status --long          # Statut exécution
sudo cat /var/log/cloud-init.log  # Logs complets

# Depuis le projet
./scripts/validate-cloud-init.sh <vm-ip>  # Tests automatisés
```


### Modifications Cloud-init (best practices)

- **Nouveau package** : Utiliser Ansible (pas de réexécution cloud-init)
- **Modification user-data** : Si absolument nécessaire → `terraform taint` + `terraform apply` (recrée VM)
- **Règle d'or** : Cloud-init = bootstrap initial uniquement, Ansible = gestion continue

***

## 🤖 Ansible : Configuration Services

### Responsabilités

- Configuration idempotente des services applicatifs
- Déploiement Taiga (gestion projet agile)
- Déploiement Bind9 (serveur DNS)
- Configuration système post-bootstrap (Docker, firewall, monitoring)
- Gestion continue (peut être rejoué indéfiniment)


### Fichiers clés

| Fichier | Rôle SSOT | Versionné |
| :-- | :-- | :-- |
| `ansible.cfg` | Configuration globale Ansible | ✅ Oui |
| `inventory/terraform.generated.yml` | Inventaire (généré par Terraform) | ❌ Non |
| `group_vars/all.yml` | Config globale toutes VMs | ✅ Oui |
| `group_vars/taiga_hosts.yml` | Config Taiga | ✅ Oui |
| `group_vars/bind9_hosts.yml` | Config DNS | ✅ Oui |
| `playbooks/site.yml` | Playbook master (orchestration complète) | ✅ Oui |
| `roles/common/` | Rôle configuration globale | ✅ Oui |
| `roles/taiga/` | Rôle déploiement Taiga | ✅ Oui |
| `roles/bind9/` | Rôle déploiement DNS | ✅ Oui |

### Scripts d'automatisation

| Script | Rôle | Idempotent |
| :-- | :-- | :-- |
| `bootstrap.sh` | Installation dépendances Ansible Galaxy | ❌ Non |
| `run-ping-test.sh` | Test connectivité SSH + Ansible | ❌ Non |
| `validate.sh` | Validation complète infrastructure | ❌ Non |
| `run-taiga-apply.sh` | Déploiement Taiga | ✅ Oui |
| `run-taiga-check.sh` | Validation Taiga (dry-run) | ❌ Non |

### Commandes essentielles

```bash
cd Ansible/

# Installation dépendances
./bootstrap.sh

# Test connectivité
./run-ping-test.sh
./run-ping-test.sh --bastion  # Via ProxyJump

# Déploiement complet
ansible-playbook playbooks/site.yml

# Déploiement service spécifique
ansible-playbook playbooks/site.yml --tags taiga
ansible-playbook playbooks/site.yml --tags bind9

# Mode dry-run (pas de modification réelle)
ansible-playbook playbooks/site.yml --check --diff

# Validation post-déploiement
./validate.sh
```


### Principe d'idempotence (exemples)

```yaml
# Installation Docker (idempotent)
- name: Installation Docker
  apt:
    name: docker-ce
    state: present  # ← Si présent → rien, si absent → installation

# Configuration fichier (idempotent)
- name: Configuration SSH hardening
  template:
    src: sshd_config.j2
    dest: /etc/ssh/sshd_config.d/99-hardening.conf
  notify: Restart sshd  # ← Exécuté uniquement si fichier modifié

# Service démarré (idempotent)
- name: Docker actif
  systemd:
    name: docker
    state: started  # ← Si started → rien, si stopped → start
    enabled: true   # ← Si enabled → rien, si disabled → enable
```

**Résultat** : Rejouer le playbook 10 fois ne change rien si l'état désiré est déjà atteint.

***

## 🚀 Workflow DevOps Complet

### Déploiement initial (depuis zéro)

```bash
# 1. Préparation Proxmox (une seule fois)
ssh root@proxmox
# Créer template cloud-init VMID 9000
# Créer token API Proxmox
# Configurer datastore snippets

# 2. Initialisation projet
git clone <repo>
cd projet-infra-devops

# 3. Génération SSOT accès
./scripts/generate-ssh-keys.sh           # Génère keys/ansible_ed25519.pub
./scripts/create-proxmox-token.sh        # Crée secrets/proxmox-token.txt
./scripts/generate-tfvars.sh             # Génère terraform.tfvars (SSOT)

# 4. Déploiement infrastructure
terraform init
terraform plan -input=false
terraform apply -auto-approve

# Attendre 1-2 min (cloud-init s'exécute)

# 5. Configuration services
cd Ansible/
./bootstrap.sh                           # Installation dépendances
./run-ping-test.sh                       # Validation connectivité
ansible-playbook playbooks/site.yml      # Déploiement complet
./validate.sh                            # Validation finale

# 6. Vérification
terraform output vm_ips                  # Afficher IPs
terraform output ssh_connection_string   # Commandes SSH
```

**Durée totale estimée** : 10-15 minutes

### Modification configuration (workflow continu)

```bash
# 1. Modifier SSOT configuration
vim Ansible/group_vars/taiga_hosts.yml
# Exemple : taiga_version: "6.8.0"

# 2. Validation sans modification
ansible-playbook playbooks/taiga.yml --check --diff

# 3. Application idempotente
ansible-playbook playbooks/taiga.yml

# 4. Validation
./validate.sh

# 5. Commit + Push
git add group_vars/taiga_hosts.yml
git commit -m "feat: upgrade Taiga 6.7.0 → 6.8.0"
git push
```


### Ajout d'une VM

```bash
# 1. Modifier SSOT infrastructure
vim terraform.tfvars
# Ajouter dans nodes = { ... }

nodes = {
  # ... VMs existantes ...
  
  monitoring = {
    ip     = "172.16.100.30"
    cpu    = 2
    mem    = 2048
    disk   = 30
    bridge = "vmbr0"
    tags   = ["monitoring", "prod"]
  }
}

# 2. Application
terraform plan
terraform apply

# 3. Inventaire Ansible mis à jour automatiquement
cat Ansible/inventory/terraform.generated.yml

# 4. Configuration Ansible
ansible-playbook playbooks/site.yml --limit monitoring
```


***

## 📁 Structure Complète du Projet

```
projet-infra-devops/
├── .gitignore                           # Exclusion secrets
├── provider.tf                          # Config provider Proxmox
├── variables.tf                         # Définition variables
├── locals.tf                            # Valeurs dérivées SSOT
├── main.tf                              # Ressources VMs
├── ansible_inventory.tf                 # Génération inventaire
├── outputs.tf                           # Exposition données
├── terraform.tfvars                     # SSOT infrastructure (SECRETS)
├── terraform.tfvars.example             # Exemple config
├── deploy-ssot.sh                       # Script déploiement complet
│
├── scripts/                             # Scripts d'orchestration
│   ├── generate-ssh-keys.sh             # Génération clé SSH SSOT
│   ├── create-proxmox-token.sh          # Procédure token API
│   ├── generate-tfvars.sh               # Génération terraform.tfvars
│   └── validate-cloud-init.sh           # Validation bootstrap
│
├── keys/                                # Clés SSH (SSOT accès)
│   ├── ansible_ed25519                  # Clé privée (NON versionné)
│   └── ansible_ed25519.pub              # Clé publique (versionné)
│
├── secrets/                             # Secrets (NON versionnés)
│   └── proxmox-token.txt                # Token API Proxmox
│
├── cloud-init/                          # Templates cloud-init
│   └── user-data.yaml.tftpl             # Template bootstrap OS
│
└── Ansible/                             # Configuration Ansible
    ├── ansible.cfg                      # Config Ansible
    ├── inventory/
    │   └── terraform.generated.yml      # Inventaire (généré)
    ├── group_vars/                      # SSOT configuration
    │   ├── all.yml                      # Config globale
    │   ├── taiga_hosts.yml              # Config Taiga
    │   └── bind9_hosts.yml              # Config DNS
    ├── playbooks/                       # Playbooks orchestration
    │   ├── site.yml                     # Master playbook
    │   ├── taiga.yml                    # Playbook Taiga
    │   ├── bind9.yml                    # Playbook DNS
    │   └── common.yml                   # Playbook config commune
    ├── roles/                           # Rôles (logique métier)
    │   ├── common/                      # Config globale
    │   ├── taiga/                       # Déploiement Taiga
    │   └── bind9/                       # Déploiement DNS
    ├── requirements.yml                 # Dépendances Galaxy
    ├── bootstrap.sh                     # Installation dépendances
    ├── run-ping-test.sh                 # Test connectivité
    ├── run-taiga-apply.sh               # Déploiement Taiga
    ├── run-taiga-check.sh               # Validation Taiga
    └── validate.sh                      # Validation globale
```


***

## 🔒 Sécurité et Bonnes Pratiques

### Fichiers à NE JAMAIS versionner

```gitignore
# Secrets infrastructure
terraform.tfvars
*.tfvars
terraform.tfstate
terraform.tfstate.*

# Clés SSH privées
keys/*_ed25519
keys/*.pem
secrets/

# Inventaire généré
Ansible/inventory/terraform.generated.yml
```


### Gestion des secrets (évolution future)

- **Ansible Vault** : Chiffrement `group_vars/*/vault.yml`
- **HashiCorp Vault** : Stockage centralisé secrets
- **Backend Terraform distant** : S3 + DynamoDB (lock state)


### Checklist sécurité

- [ ] `terraform.tfstate` non versionné
- [ ] Clés SSH privées dans `keys/` (hors Git)
- [ ] Token API Proxmox dans `secrets/` (hors Git)
- [ ] SSH password auth désactivé (cloud-init)
- [ ] Root login désactivé (cloud-init)
- [ ] Firewall UFW activé (Ansible)
- [ ] Sudo NOPASSWD uniquement pour `ansible`

***

## 🎓 Concepts Clés à Retenir

### SSOT (Single Source of Truth)

**Chaque donnée a une seule source**, toutes les autres en découlent automatiquement.

- Clé SSH → Définie 1 fois dans `keys/`, utilisée par Terraform et Ansible
- Infrastructure → Définie dans `terraform.tfvars`, inventaire Ansible généré automatiquement
- Configuration → Définie dans `group_vars/`, appliquée par playbooks


### Idempotence

**Rejouer une action produit le même résultat**, sans effets de bord.

- Playbooks Ansible rejouables à l'infini
- Terraform détecte changements réels avant application
- Cloud-init s'exécute une seule fois (pas idempotent)


### Infrastructure as Code (IaC)

**Infrastructure définie par du code**, versionné et reproductible.

- Terraform = Code infrastructure
- Ansible = Code configuration
- Git = Source de vérité versionnée


### Séparation des responsabilités

| Outil | Phase | Exécution | Idempotent |
| :-- | :-- | :-- | :-- |
| Terraform | Provisioning | Une fois (puis modifications) | ✅ Oui |
| Cloud-init | Bootstrap | Premier boot uniquement | ❌ Non |
| Ansible | Configuration | Multiple (continue) | ✅ Oui |


***

## 📚 Documentation de Référence

### Officielles

- [Proxmox Cloud-init Support](https://pve.proxmox.com/wiki/Cloud-Init_Support)
- [Terraform Provider Proxmox (bpg)](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html)


### Fichiers README projet

- `README.md` : Vue d'ensemble et démarrage rapide
- `BIND9_DEPLOYMENT.md` : Déploiement serveur DNS
- `Ansible/AUTOMATION_GUIDE.md` : Guide automatisation Ansible
- `Ansible/CHANGELOG.md` : Historique modifications
- `Ansible/START_HERE.txt` : Point de départ contributeurs

***

## 🔄 Évolutions Futures du Projet

### Court terme

- [ ] Intégration Ansible Vault pour secrets
- [ ] Backend Terraform distant (S3)
- [ ] CI/CD GitHub Actions
- [ ] Monitoring (Prometheus + Grafana)
- [ ] Logs centralisés (Loki + Promtail)


### Moyen terme

- [ ] Haute disponibilité Taiga (multi-node)
- [ ] Backup automatisé (restic + rclone)
- [ ] Certificats SSL (Let's Encrypt)
- [ ] Reverse proxy (Traefik)
- [ ] Secrets management (HashiCorp Vault)


### Long terme

- [ ] Migration Kubernetes (K3s)
- [ ] GitOps (ArgoCD)
- [ ] Infrastructure multi-cloud
- [ ] Disaster Recovery Plan

***

**Dernière mise à jour** : 17 janvier 2026
**Version projet** : 1.0.0
**Mainteneurs** : [À compléter]

***

Voilà ! Cette documentation complète peut être copiée-collée dans la description de votre Space. Elle couvre tous les aspects que nous avons détaillés, avec :

✅ Architecture globale
✅ Points clés DevSecOps
✅ Hiérarchie SSOT
✅ Détails Terraform, Cloud-init, Ansible
✅ Workflows complets
✅ Structure projet
✅ Bonnes pratiques sécurité
✅ Concepts clés
✅ Évolutions futures

Souhaitez-vous que j'ajoute ou modifie certaines sections ?

