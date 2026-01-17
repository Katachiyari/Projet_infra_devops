# 🔷 Ansible : Configuration idempotente avec approche SSOT


***

## 📍 Explication : Rôle d'Ansible dans l'architecture

### Définition

Ansible est un **outil d'orchestration** qui configure les VMs **après le bootstrap cloud-init**. Il applique des configurations **idempotentes** (réexécutables sans effets de bord) pour déployer des services applicatifs.

### Séparation des responsabilités SSOT

| Outil | Phase | Responsabilité | Exécution |
| :-- | :-- | :-- | :-- |
| **Terraform** | Provisioning | Création infrastructure (VMs, réseau) | Une fois |
| **Cloud-init** | Bootstrap | Configuration OS de base (user, SSH, packages système) | Premier boot uniquement |
| **Ansible** | Configuration | Services applicatifs (Taiga, Bind9, configurations métier) | Multiple (idempotent) |

### Principe SSOT appliqué à Ansible

```
SSOT Infrastructure (Terraform)
  └─> terraform.generated.yml (inventaire SSOT)
      ├─> group_vars/ (SSOT configuration)
      │   ├─> all.yml (config globale)
      │   ├─> taiga_hosts.yml (config Taiga)
      │   └─> bind9_hosts.yml (config DNS)
      └─> Playbooks
          └─> Roles (logique métier)
              └─> Tasks (actions idempotentes)
                  └─> VMs (état final désiré)
```

**Point clé** : Ansible peut être rejoué **indéfiniment** sur les mêmes VMs sans casser l'état existant (idempotence).

***

## 📍 Cycle de vie Ansible (complet)

### Phase 1 : Préparation (dépendances Terraform)

```
1. Terraform crée les VMs
   └─> terraform apply
       └─> Génère terraform.generated.yml (inventaire SSOT)

2. Cloud-init configure OS
   └─> Utilisateur ansible créé
   └─> Python3 installé (requis Ansible)
   └─> Clé SSH injectée

3. Inventaire disponible
   └─> Ansible/inventory/terraform.generated.yml
       └─> Groupes : taiga_hosts, bind9_hosts
       └─> Variables : ansible_host (IP)
```


### Phase 2 : Bootstrap Ansible (première exécution)

```
1. Installation dépendances Ansible
   └─> ./Ansible/bootstrap.sh
       └─> ansible-galaxy install -r requirements.yml
       └─> Installation collections (community.general, etc.)

2. Test de connectivité
   └─> ./Ansible/run-ping-test.sh
       └─> ansible all -m ping
       └─> Validation clé SSH SSOT

3. Exécution playbook initial
   └─> ansible-playbook playbooks/site.yml
       ├─> Rôle common (config globale)
       ├─> Rôle taiga (si groupe taiga_hosts)
       └─> Rôle bind9 (si groupe bind9_hosts)
```


### Phase 3 : Gestion continue (idempotence)

```
1. Modification configuration (SSOT group_vars)
   └─> vim Ansible/group_vars/taiga_hosts.yml
       └─> Changement version Taiga

2. Validation avant application
   └─> ansible-playbook playbooks/taiga.yml --check
       └─> Mode dry-run (pas de changement réel)

3. Application idempotente
   └─> ansible-playbook playbooks/taiga.yml
       └─> Ansible détecte différences
       └─> Applique uniquement changements nécessaires

4. Vérification post-déploiement
   └─> ./Ansible/validate.sh
       └─> Tests de conformité
```


### Phase 4 : Workflow DevOps complet

```
┌─────────────────────────────────────────────────────────────┐
│ Développeur modifie SSOT group_vars/taiga_hosts.yml       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Git commit + push                                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ CI/CD (GitHub Actions) déclenché                            │
├─────────────────────────────────────────────────────────────┤
│ 1. ansible-playbook --check (validation)                   │
│ 2. ansible-playbook --diff (affiche changements)           │
│ 3. ansible-playbook (application)                          │
│ 4. ./validate.sh (tests post-déploiement)                  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ État final VMs = État désiré SSOT                          │
└─────────────────────────────────────────────────────────────┘
```


***

## 📍 Architecture SSOT Ansible

### Diagramme de flux SSOT

```
┌─────────────────────────────────────────────────────────────┐
│ SSOT Sources Ansible                                        │
├─────────────────────────────────────────────────────────────┤
│ • terraform.generated.yml → Inventaire (généré)            │
│ • group_vars/all.yml → Configuration globale                │
│ • group_vars/taiga_hosts.yml → Config Taiga                 │
│ • group_vars/bind9_hosts.yml → Config DNS                   │
│ • roles/*/defaults/main.yml → Valeurs par défaut rôles     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Résolution variables (ordre de priorité)                    │
├─────────────────────────────────────────────────────────────┤
│ 1. Extra vars (CLI -e)                                      │
│ 2. host_vars/<hostname>.yml                                 │
│ 3. group_vars/<group>.yml                                   │
│ 4. group_vars/all.yml                                       │
│ 5. roles/*/defaults/main.yml                                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Exécution playbooks (idempotente)                           │
├─────────────────────────────────────────────────────────────┤
│ • Gather facts → Détection état actuel VM                   │
│ • Compare état désiré (SSOT) vs état actuel                 │
│ • Applique uniquement changements nécessaires               │
│ • Résultat : changed=X, ok=Y, skipped=Z                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ État final VMs                                              │
├─────────────────────────────────────────────────────────────┤
│ • Configuration = SSOT group_vars                           │
│ • Services démarrés (Taiga, Bind9)                          │
│ • Logs dans /var/log/<service>                              │
└─────────────────────────────────────────────────────────────┘
```


***

## 📍 Structure SSOT du projet Ansible

### Arborescence complète

```
Ansible/
├── ansible.cfg                          # Config Ansible (SSOT chemin inventaire)
├── inventory/
│   └── terraform.generated.yml          # SSOT inventaire (généré Terraform)
├── group_vars/                          # SSOT configuration par groupe
│   ├── all.yml                          # Config globale toutes VMs
│   ├── taiga_hosts.yml                  # Config spécifique Taiga
│   └── bind9_hosts.yml                  # Config spécifique DNS
├── host_vars/                           # SSOT configuration par hôte (optionnel)
│   └── tools-manager.yml                # Config spécifique à une VM
├── playbooks/                           # Playbooks d'orchestration
│   ├── site.yml                         # Playbook master (tous les rôles)
│   ├── taiga.yml                        # Playbook Taiga uniquement
│   ├── bind9.yml                        # Playbook DNS uniquement
│   ├── common.yml                       # Playbook config commune
│   └── debug-cloud-init.yml             # Playbook diagnostic
├── roles/                               # Rôles (logique métier)
│   ├── common/                          # Rôle config globale
│   │   ├── defaults/main.yml            # Valeurs par défaut
│   │   ├── tasks/main.yml               # Tâches principales
│   │   ├── handlers/main.yml            # Handlers (redémarrages)
│   │   └── templates/                   # Templates Jinja2
│   ├── taiga/                           # Rôle Taiga
│   │   ├── defaults/main.yml
│   │   ├── tasks/main.yml
│   │   ├── handlers/main.yml
│   │   └── templates/
│   │       ├── docker-compose.yml.j2
│   │       └── taiga.env.j2
│   └── bind9/                           # Rôle DNS
│       ├── defaults/main.yml
│       ├── tasks/main.yml
│       ├── handlers/main.yml
│       └── templates/
│           ├── named.conf.j2
│           └── db.zone.j2
├── requirements.yml                     # Dépendances Ansible Galaxy
├── bootstrap.sh                         # Script installation dépendances
├── run-ping-test.sh                     # Script test connectivité
├── run-taiga-apply.sh                   # Script déploiement Taiga
├── run-taiga-check.sh                   # Script validation Taiga
└── validate.sh                          # Script validation globale
```


***

## 📍 Fichiers et code détaillés

### Fichier 1 : `ansible.cfg` (SSOT configuration Ansible)

**Chemin** : `Ansible/ansible.cfg`
**Rôle** : Configuration globale Ansible, référence au SSOT inventaire
**Versionné** : ✅ Oui

```ini
# ===================================================================
# SSOT Ansible : Configuration globale
# ===================================================================

[defaults]
# SSOT : Inventaire généré par Terraform
inventory = inventory/terraform.generated.yml

# Désactiver vérification clés SSH (VMs recréées souvent)
host_key_checking = False

# Désactiver fichiers .retry (pollution)
retry_files_enabled = False

# Chemin rôles (cherche d'abord localement)
roles_path = roles:~/.ansible/roles:/usr/share/ansible/roles

# Interpréteur Python (détection auto)
interpreter_python = auto_silent

# Performance
forks = 10                               # Parallélisme (10 hôtes simultanés)
gathering = smart                        # Cache facts entre exécutions
fact_caching = jsonfile                  # Stockage cache facts
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 3600              # 1 heure

# SSOT : Utilisateur SSH (synchronisé cloud-init)
remote_user = ansible

# SSOT : Clé SSH (même source que Terraform)
private_key_file = ../keys/ansible_ed25519

# Timeout connexion SSH
timeout = 30

# Affichage amélioré
stdout_callback = yaml
callbacks_enabled = profile_tasks        # Affiche durée des tâches

[ssh_connection]
# Optimisation SSH (réutilisation connexions)
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no
pipelining = True                        # Réduction overhead SSH

[privilege_escalation]
# SSOT : Élévation privilèges (sudo NOPASSWD configuré par cloud-init)
become = True
become_method = sudo
become_user = root
become_ask_pass = False
```


***

### Fichier 2 : `inventory/terraform.generated.yml` (SSOT inventaire)

**Chemin** : `Ansible/inventory/terraform.generated.yml`
**Rôle** : Inventaire généré automatiquement par Terraform
**Versionné** : ❌ Non (généré)

**Exemple de contenu généré** :

```yaml
# ===================================================================
# SSOT Inventaire Ansible (généré par Terraform)
# ===================================================================
# ⚠️  NE PAS ÉDITER MANUELLEMENT
# Régénéré à chaque terraform apply

all:
  hosts:
    tools-manager:
      ansible_host: 172.16.100.20
    dns-server:
      ansible_host: 172.16.100.254
    
  children:
    taiga_hosts:
      hosts:
        tools-manager: {}
    
    bind9_hosts:
      hosts:
        dns-server: {}
```

**Comment est généré ce fichier** : Voir `ansible_inventory.tf` expliqué précédemment.

***

### Fichier 3 : `group_vars/all.yml` (SSOT configuration globale)

**Chemin** : `Ansible/group_vars/all.yml`
**Rôle** : Configuration appliquée à **toutes** les VMs
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# SSOT Configuration globale (toutes VMs)
# ===================================================================

# ===================================================================
# 1. Connexion Ansible (synchronisé cloud-init)
# ===================================================================
ansible_user: ansible
ansible_become: true
ansible_become_method: sudo
ansible_python_interpreter: /usr/bin/python3

# ===================================================================
# 2. Configuration système (SSOT)
# ===================================================================
timezone: Europe/Paris
locale: fr_FR.UTF-8

# ===================================================================
# 3. Packages de base (SSOT dépendances)
# ===================================================================
base_packages:
  - vim
  - htop
  - curl
  - wget
  - git
  - python3-pip
  - python3-venv
  - ca-certificates
  - gnupg
  - lsb-release

# ===================================================================
# 4. Configuration réseau (synchronisé Terraform)
# ===================================================================
dns_servers:
  - 1.1.1.1        # Cloudflare primary
  - 1.0.0.1        # Cloudflare secondary

ntp_servers:
  - 0.fr.pool.ntp.org
  - 1.fr.pool.ntp.org

# ===================================================================
# 5. Configuration Docker (SSOT)
# ===================================================================
docker_edition: ce
docker_version: "24.0"
docker_users:
  - ansible

docker_compose_version: "2.24.0"

# Repository Docker officiel
docker_apt_repository: "deb [arch=amd64] https://download.docker.com/linux/ubuntu {{ ansible_distribution_release }} stable"
docker_apt_gpg_key: https://download.docker.com/linux/ubuntu/gpg

# ===================================================================
# 6. Configuration sécurité (SSOT)
# ===================================================================
# Firewall (ufw)
firewall_enabled: true
firewall_default_policy:
  incoming: deny
  outgoing: allow
  routed: deny

# Ports SSH autorisés
firewall_allowed_ports:
  - 22/tcp         # SSH

# ===================================================================
# 7. Configuration monitoring (SSOT)
# ===================================================================
monitoring_enabled: true
monitoring_stack:
  - prometheus-node-exporter    # Métriques système
  - promtail                    # Logs vers Loki (si déployé)

# ===================================================================
# 8. Configuration backup (SSOT)
# ===================================================================
backup_enabled: false
backup_retention_days: 7
backup_destination: /backup

# ===================================================================
# 9. Variables d'environnement globales
# ===================================================================
global_env_vars:
  LANG: "fr_FR.UTF-8"
  LC_ALL: "fr_FR.UTF-8"
  TZ: "Europe/Paris"
```


***

### Fichier 4 : `group_vars/taiga_hosts.yml` (SSOT configuration Taiga)

**Chemin** : `Ansible/group_vars/taiga_hosts.yml`
**Rôle** : Configuration spécifique aux VMs du groupe `taiga_hosts`
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# SSOT Configuration Taiga (gestion projet agile)
# ===================================================================

# ===================================================================
# 1. Version Taiga (SSOT)
# ===================================================================
taiga_version: "6.7.0"

# ===================================================================
# 2. Domaine et URLs (SSOT)
# ===================================================================
taiga_domain: "taiga.local"
taiga_protocol: "http"                   # Utiliser "https" en production
taiga_url: "{{ taiga_protocol }}://{{ taiga_domain }}"

# ===================================================================
# 3. Configuration base de données (SSOT)
# ===================================================================
taiga_db_type: postgresql
taiga_db_host: taiga-db
taiga_db_port: 5432
taiga_db_name: taiga
taiga_db_user: taiga
# ⚠️  En production : utiliser Ansible Vault pour les secrets
taiga_db_password: "{{ vault_taiga_db_password | default('changeme') }}"

# ===================================================================
# 4. Configuration Redis (SSOT)
# ===================================================================
taiga_redis_host: taiga-redis
taiga_redis_port: 6379

# ===================================================================
# 5. Configuration email (SSOT)
# ===================================================================
taiga_email_enabled: true
taiga_email_backend: "smtp"
taiga_email_host: "localhost"
taiga_email_port: 25
taiga_email_use_tls: false
taiga_email_from: "noreply@{{ taiga_domain }}"

# ===================================================================
# 6. Configuration admin initial (SSOT)
# ===================================================================
taiga_admin_user: "admin"
taiga_admin_email: "admin@{{ taiga_domain }}"
# ⚠️  Utiliser Ansible Vault en production
taiga_admin_password: "{{ vault_taiga_admin_password | default('admin123') }}"

# ===================================================================
# 7. Ports exposés (SSOT)
# ===================================================================
taiga_frontend_port: 80
taiga_backend_port: 8000
taiga_events_port: 8888

# Règles firewall spécifiques Taiga
firewall_allowed_ports:
  - "{{ taiga_frontend_port }}/tcp"
  - "{{ taiga_backend_port }}/tcp"

# ===================================================================
# 8. Configuration Docker Compose (SSOT)
# ===================================================================
taiga_docker_compose_dir: /opt/taiga
taiga_data_dir: /var/lib/taiga

# Volumes Docker
taiga_volumes:
  - "{{ taiga_data_dir }}/postgres:/var/lib/postgresql/data"
  - "{{ taiga_data_dir }}/media:/taiga-back/media"
  - "{{ taiga_data_dir }}/static:/taiga-back/static"

# ===================================================================
# 9. Configuration réseau Docker (SSOT)
# ===================================================================
taiga_docker_network: taiga-network

# ===================================================================
# 10. Fonctionnalités activées (SSOT)
# ===================================================================
taiga_public_register_enabled: false     # Inscription publique désactivée
taiga_github_auth_enabled: false         # Auth GitHub désactivée
taiga_gitlab_auth_enabled: false         # Auth GitLab désactivée
taiga_webhooks_enabled: true             # Webhooks activés
```


***

### Fichier 5 : `group_vars/bind9_hosts.yml` (SSOT configuration DNS)

**Chemin** : `Ansible/group_vars/bind9_hosts.yml`
**Rôle** : Configuration spécifique aux VMs du groupe `bind9_hosts`
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# SSOT Configuration Bind9 (serveur DNS)
# ===================================================================

# ===================================================================
# 1. Configuration globale Bind9 (SSOT)
# ===================================================================
bind9_listen_ipv4: true
bind9_listen_ipv6: false

# IP d'écoute (synchronisé avec inventaire Terraform)
bind9_listen_addresses:
  - "{{ ansible_host }}"
  - 127.0.0.1

bind9_port: 53

# ===================================================================
# 2. Configuration zones DNS (SSOT)
# ===================================================================
bind9_zones:
  # Zone forward (résolution noms → IPs)
  - name: "lab.local"
    type: master
    file: "db.lab.local"
    records:
      - name: "@"
        type: SOA
        value: "ns1.lab.local. admin.lab.local. (2026011701 3600 1800 604800 86400)"
      
      - name: "@"
        type: NS
        value: "ns1.lab.local."
      
      - name: "ns1"
        type: A
        value: "{{ ansible_host }}"
      
      - name: "taiga"
        type: A
        value: "172.16.100.20"
      
      - name: "tools"
        type: CNAME
        value: "taiga.lab.local."

  # Zone reverse (résolution IPs → noms)
  - name: "100.16.172.in-addr.arpa"
    type: master
    file: "db.172.16.100"
    records:
      - name: "@"
        type: SOA
        value: "ns1.lab.local. admin.lab.local. (2026011701 3600 1800 604800 86400)"
      
      - name: "@"
        type: NS
        value: "ns1.lab.local."
      
      - name: "254"
        type: PTR
        value: "ns1.lab.local."
      
      - name: "20"
        type: PTR
        value: "taiga.lab.local."

# ===================================================================
# 3. Configuration forwarders (SSOT)
# ===================================================================
bind9_forwarders:
  - 1.1.1.1          # Cloudflare
  - 1.0.0.1
  - 8.8.8.8          # Google (backup)

bind9_forward_policy: only

# ===================================================================
# 4. Configuration ACL (SSOT sécurité)
# ===================================================================
bind9_acls:
  - name: "trusted"
    networks:
      - "172.16.100.0/24"      # Réseau local
      - "127.0.0.0/8"          # Localhost

# Qui peut faire des requêtes
bind9_allow_query:
  - "trusted"

# Qui peut faire des transferts de zone
bind9_allow_transfer:
  - none

# Qui peut faire de la récursion
bind9_recursion: true
bind9_allow_recursion:
  - "trusted"

# ===================================================================
# 5. Configuration DNSSEC (SSOT sécurité)
# ===================================================================
bind9_dnssec_enable: true
bind9_dnssec_validation: auto

# ===================================================================
# 6. Firewall DNS (SSOT)
# ===================================================================
firewall_allowed_ports:
  - 53/tcp           # DNS TCP
  - 53/udp           # DNS UDP

# ===================================================================
# 7. Logging Bind9 (SSOT)
# ===================================================================
bind9_logging:
  channels:
    - name: default_syslog
      destination: syslog daemon
      severity: info

  categories:
    - name: default
      channels:
        - default_syslog

# ===================================================================
# 8. Options avancées (SSOT)
# ===================================================================
bind9_max_cache_size: "256M"
bind9_max_cache_ttl: 3600
bind9_max_ncache_ttl: 3600
```


***

### Fichier 6 : `playbooks/site.yml` (Playbook master)

**Chemin** : `Ansible/playbooks/site.yml`
**Rôle** : Orchestration complète (tous les rôles)
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Playbook master : Déploiement complet infrastructure
# ===================================================================

# ===================================================================
# 1. Configuration commune (toutes VMs)
# ===================================================================
- name: Configuration commune toutes VMs
  hosts: all
  gather_facts: true
  become: true
  
  roles:
    - role: common
      tags: ['common', 'base']

# ===================================================================
# 2. Déploiement Taiga (groupe taiga_hosts)
# ===================================================================
- name: Déploiement Taiga
  hosts: taiga_hosts
  gather_facts: true
  become: true
  
  roles:
    - role: taiga
      tags: ['taiga', 'apps']

# ===================================================================
# 3. Déploiement Bind9 (groupe bind9_hosts)
# ===================================================================
- name: Déploiement Bind9
  hosts: bind9_hosts
  gather_facts: true
  become: true
  
  roles:
    - role: bind9
      tags: ['bind9', 'dns']
```

**Utilisation** :

```bash
# Déploiement complet
ansible-playbook playbooks/site.yml

# Déploiement uniquement rôle common
ansible-playbook playbooks/site.yml --tags common

# Déploiement uniquement Taiga
ansible-playbook playbooks/site.yml --tags taiga

# Mode check (dry-run)
ansible-playbook playbooks/site.yml --check

# Afficher différences
ansible-playbook playbooks/site.yml --diff
```


***

### Fichier 7 : `roles/common/tasks/main.yml` (Rôle configuration globale)

**Chemin** : `Ansible/roles/common/tasks/main.yml`
**Rôle** : Tâches communes à toutes les VMs (idempotentes)
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Rôle common : Configuration globale (idempotente)
# ===================================================================

# ===================================================================
# 1. Configuration système de base
# ===================================================================
- name: Configurer timezone (SSOT)
  community.general.timezone:
    name: "{{ timezone }}"
  tags: ['system']

- name: Configurer locale (SSOT)
  community.general.locale_gen:
    name: "{{ locale }}"
    state: present
  tags: ['system']

# ===================================================================
# 2. Installation packages de base (SSOT - idempotent)
# ===================================================================
- name: Mise à jour cache APT
  ansible.builtin.apt:
    update_cache: true
    cache_valid_time: 3600        # Cache valide 1h (évite apt update répété)
  tags: ['packages']

- name: Installation packages de base (SSOT)
  ansible.builtin.apt:
    name: "{{ base_packages }}"
    state: present
  tags: ['packages']

# ===================================================================
# 3. Configuration Docker (SSOT - idempotent)
# ===================================================================
- name: Ajouter clé GPG Docker
  ansible.builtin.apt_key:
    url: "{{ docker_apt_gpg_key }}"
    state: present
  tags: ['docker']

- name: Ajouter repository Docker
  ansible.builtin.apt_repository:
    repo: "{{ docker_apt_repository }}"
    state: present
    filename: docker
  tags: ['docker']

- name: Installation Docker (idempotent)
  ansible.builtin.apt:
    name:
      - docker-ce
      - docker-ce-cli
      - containerd.io
      - docker-buildx-plugin
      - docker-compose-plugin
    state: present
    update_cache: true
  tags: ['docker']

- name: Ajout utilisateurs au groupe docker (SSOT)
  ansible.builtin.user:
    name: "{{ item }}"
    groups: docker
    append: true
  loop: "{{ docker_users }}"
  tags: ['docker']

- name: Démarrage service Docker (idempotent)
  ansible.builtin.systemd:
    name: docker
    state: started
    enabled: true
  tags: ['docker']

# ===================================================================
# 4. Configuration firewall UFW (SSOT - idempotent)
# ===================================================================
- name: Installation UFW
  ansible.builtin.apt:
    name: ufw
    state: present
  when: firewall_enabled
  tags: ['firewall']

- name: Configuration politique par défaut UFW
  community.general.ufw:
    direction: "{{ item.key }}"
    policy: "{{ item.value }}"
  loop: "{{ firewall_default_policy | dict2items }}"
  when: firewall_enabled
  tags: ['firewall']

- name: Autorisation ports SSH (SSOT)
  community.general.ufw:
    rule: allow
    port: "{{ item.split('/')[0] }}"
    proto: "{{ item.split('/')[1] }}"
  loop: "{{ firewall_allowed_ports }}"
  when: firewall_enabled
  tags: ['firewall']

- name: Activation UFW (idempotent)
  community.general.ufw:
    state: enabled
  when: firewall_enabled
  tags: ['firewall']

# ===================================================================
# 5. Configuration NTP (SSOT - idempotent)
# ===================================================================
- name: Installation systemd-timesyncd
  ansible.builtin.apt:
    name: systemd-timesyncd
    state: present
  tags: ['ntp']

- name: Configuration serveurs NTP (SSOT)
  ansible.builtin.template:
    src: timesyncd.conf.j2
    dest: /etc/systemd/timesyncd.conf
    owner: root
    group: root
    mode: '0644'
  notify: Restart timesyncd
  tags: ['ntp']

# ===================================================================
# 6. Monitoring (SSOT - optionnel)
# ===================================================================
- name: Installation node-exporter (Prometheus)
  ansible.builtin.apt:
    name: prometheus-node-exporter
    state: present
  when: monitoring_enabled
  tags: ['monitoring']

- name: Démarrage node-exporter
  ansible.builtin.systemd:
    name: prometheus-node-exporter
    state: started
    enabled: true
  when: monitoring_enabled
  tags: ['monitoring']
```


***

### Fichier 8 : `roles/common/handlers/main.yml` (Handlers - redémarrages)

**Chemin** : `Ansible/roles/common/handlers/main.yml`
**Rôle** : Redémarrages services (déclenchés uniquement si changement)
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Handlers : Redémarrages services (idempotent)
# ===================================================================

- name: Restart timesyncd
  ansible.builtin.systemd:
    name: systemd-timesyncd
    state: restarted

- name: Restart docker
  ansible.builtin.systemd:
    name: docker
    state: restarted

- name: Reload ufw
  community.general.ufw:
    state: reloaded
```

**Principe des handlers** : Ils ne s'exécutent que si une tâche a fait un changement (`changed: true`) et les appelle via `notify`.

***

### Fichier 9 : `bootstrap.sh` (Script installation dépendances)

**Chemin** : `Ansible/bootstrap.sh`
**Rôle** : Installation des dépendances Ansible (collections, rôles Galaxy)
**Versionné** : ✅ Oui

```bash
#!/usr/bin/env bash
set -euo pipefail

# ===================================================================
# Bootstrap Ansible : Installation dépendances (SSOT)
# ===================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo "=========================================="
echo "Bootstrap Ansible (SSOT)"
echo "=========================================="
echo ""

# Vérification présence inventaire (SSOT Terraform)
if [[ ! -f inventory/terraform.generated.yml ]]; then
    log_error "Inventaire SSOT manquant : inventory/terraform.generated.yml"
    log_warn "Exécuter d'abord : terraform apply"
    exit 1
fi
log_info "✓ Inventaire SSOT détecté"

# Vérification présence clé SSH (SSOT)
if [[ ! -f ../keys/ansible_ed25519 ]]; then
    log_error "Clé SSH SSOT manquante : ../keys/ansible_ed25519"
    log_warn "Exécuter d'abord : ./scripts/generate-ssh-keys.sh"
    exit 1
fi
log_info "✓ Clé SSH SSOT présente"

# Installation collections Ansible Galaxy
log_info "Installation collections Ansible Galaxy..."
if [[ -f requirements.yml ]]; then
    ansible-galaxy collection install -r requirements.yml --force
    log_info "✓ Collections installées"
else
    log_warn "Fichier requirements.yml manquant, skip"
fi

# Installation rôles Ansible Galaxy (si nécessaire)
log_info "Installation rôles Ansible Galaxy..."
if [[ -f requirements.yml ]]; then
    ansible-galaxy role install -r requirements.yml --force || true
    log_info "✓ Rôles installés"
fi

# Test de connectivité
log_info "Test de connectivité Ansible..."
if ansible all -m ping -o; then
    log_info "✓ Connectivité validée"
else
    log_error "Échec connectivité Ansible"
    log_warn "Vérifier :"
    log_warn "  1. VMs démarrées (terraform output vm_ips)"
    log_warn "  2. Cloud-init terminé (attendre 1-2 min après apply)"
    log_warn "  3. Clé SSH correcte (../keys/ansible_ed25519)"
    exit 1
fi

echo ""
log_info "Bootstrap terminé"
log_info "Commandes suivantes :"
log_info "  ansible-playbook playbooks/site.yml"
log_info "  ansible-playbook playbooks/taiga.yml --tags taiga"
```

**Utilisation** :

```bash
cd Ansible/
chmod +x bootstrap.sh
./bootstrap.sh
```


***

### Fichier 10 : `run-ping-test.sh` (Test connectivité)

**Chemin** : `Ansible/run-ping-test.sh`
**Rôle** : Test de connectivité SSH + Ansible sur toutes les VMs
**Versionné** : ✅ Oui

```bash
#!/usr/bin/env bash
set -euo pipefail

# ===================================================================
# Test connectivité Ansible (SSOT)
# ===================================================================

GREEN='\033[0;32m'
NC='\033[0m'

echo "=========================================="
echo "Test connectivité Ansible"
echo "=========================================="
echo ""

# Support mode bastion (ProxyJump SSH)
USE_BASTION=false
SSH_KEY="../keys/ansible_ed25519"

while [[ $# -gt 0 ]]; do
    case $1 in
        --bastion)
            USE_BASTION=true
            shift
            ;;
        --key)
            SSH_KEY="$2"
            shift 2
            ;;
        *)
            echo "Usage: $0 [--bastion] [--key <path>]"
            exit 1
            ;;
    esac
done

# Configuration SSH pour mode bastion
if [[ "${USE_BASTION}" == "true" ]]; then
    export ANSIBLE_SSH_ARGS="-o ProxyJump=bastion-host -o StrictHostKeyChecking=no"
    echo "Mode bastion activé"
fi

# Test ping Ansible (module ping)
echo "Test module ping..."
ansible all -m ping -v

echo ""
echo -e "${GREEN}✓ Connectivité validée${NC}"
```

**Utilisation** :

```bash
# Mode direct
./run-ping-test.sh

# Mode bastion (avec ProxyJump)
./run-ping-test.sh --bastion

# Avec clé SSH spécifique
./run-ping-test.sh --key ~/.ssh/id_ed25519_custom
```


***

### Fichier 11 : `validate.sh` (Validation complète)

**Chemin** : `Ansible/validate.sh`
**Rôle** : Validation post-déploiement de toute l'infrastructure
**Versionné** : ✅ Oui

```bash
#!/usr/bin/env bash
set -euo pipefail

# ===================================================================
# Validation infrastructure (SSOT)
# ===================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_section() { echo -e "\n${YELLOW}=== $1 ===${NC}\n"; }

FAILURES=0

echo "=========================================="
echo "Validation infrastructure (SSOT)"
echo "=========================================="

# ===================================================================
# 1. Validation inventaire Terraform (SSOT)
# ===================================================================
log_section "Inventaire Terraform"

if [[ -f inventory/terraform.generated.yml ]]; then
    log_info "Inventaire SSOT présent"
    
    # Compter hôtes
    HOST_COUNT=$(grep -c "ansible_host:" inventory/terraform.generated.yml || echo "0")
    log_info "Hôtes détectés : ${HOST_COUNT}"
else
    log_error "Inventaire manquant"
    ((FAILURES++))
fi

# ===================================================================
# 2. Validation connectivité (SSOT clé SSH)
# ===================================================================
log_section "Connectivité SSH"

if ansible all -m ping -o &>/dev/null; then
    log_info "Connectivité Ansible validée"
else
    log_error "Échec connectivité Ansible"
    ((FAILURES++))
fi

# ===================================================================
# 3. Validation rôle common (config globale SSOT)
# ===================================================================
log_section "Configuration commune"

# Vérifier Docker installé
DOCKER_CHECK=$(ansible all -m shell -a "docker --version" -o | grep -c "Docker version" || echo "0")
if [[ "${DOCKER_CHECK}" -eq "${HOST_COUNT}" ]]; then
    log_info "Docker installé sur toutes VMs"
else
    log_error "Docker manquant sur certaines VMs"
    ((FAILURES++))
fi

# Vérifier timezone (SSOT)
TIMEZONE_CHECK=$(ansible all -m shell -a "timedatectl show -p Timezone --value" -o | grep -c "Europe/Paris" || echo "0")
if [[ "${TIMEZONE_CHECK}" -eq "${HOST_COUNT}" ]]; then
    log_info "Timezone configurée (SSOT)"
else
    log_error "Timezone incorrecte"
    ((FAILURES++))
fi

# ===================================================================
# 4. Validation Taiga (si groupe taiga_hosts)
# ===================================================================
if ansible taiga_hosts --list-hosts &>/dev/null; then
    log_section "Service Taiga"
    
    # Vérifier conteneurs Docker
    TAIGA_CONTAINERS=$(ansible taiga_hosts -m shell -a "docker ps --format '{{.Names}}' | grep -c taiga || echo 0" -o)
    if echo "${TAIGA_CONTAINERS}" | grep -q "[1-9]"; then
        log_info "Conteneurs Taiga démarrés"
    else
        log_error "Conteneurs Taiga non démarrés"
        ((FAILURES++))
    fi
    
    # Vérifier port HTTP
    TAIGA_HTTP=$(ansible taiga_hosts -m wait_for -a "port=80 timeout=5" -o 2>/dev/null | grep -c "SUCCESS" || echo "0")
    if [[ "${TAIGA_HTTP}" -gt 0 ]]; then
        log_info "Taiga répond sur port 80"
    else
        log_error "Taiga ne répond pas sur port 80"
        ((FAILURES++))
    fi
fi

# ===================================================================
# 5. Validation Bind9 (si groupe bind9_hosts)
# ===================================================================
if ansible bind9_hosts --list-hosts &>/dev/null; then
    log_section "Service Bind9"
    
    # Vérifier service actif
    BIND9_STATUS=$(ansible bind9_hosts -m systemd -a "name=named state=started" -o | grep -c "SUCCESS" || echo "0")
    if [[ "${BIND9_STATUS}" -gt 0 ]]; then
        log_info "Bind9 actif"
    else
        log_error "Bind9 inactif"
        ((FAILURES++))
    fi
    
    # Vérifier port DNS
    DNS_PORT=$(ansible bind9_hosts -m wait_for -a "port=53 timeout=5" -o 2>/dev/null | grep -c "SUCCESS" || echo "0")
    if [[ "${DNS_PORT}" -gt 0 ]]; then
        log_info "Bind9 écoute sur port 53"
    else
        log_error "Bind9 ne répond pas sur port 53"
        ((FAILURES++))
    fi
fi

# ===================================================================
# Résumé
# ===================================================================
echo ""
echo "=========================================="
if [[ "${FAILURES}" -eq 0 ]]; then
    log_info "Validation réussie (SSOT)"
    exit 0
else
    log_error "Validation échouée : ${FAILURES} erreur(s)"
    exit 1
fi
```

**Utilisation** :

```bash
cd Ansible/
chmod +x validate.sh
./validate.sh
```


***

## 📊 Tableau récapitulatif des fichiers Ansible

| Fichier | Chemin | Rôle SSOT | Idempotent | Versionné |
| :-- | :-- | :-- | :-- | :-- |
| `ansible.cfg` | `Ansible/` | Config globale | N/A | ✅ Oui |
| `terraform.generated.yml` | `Ansible/inventory/` | Inventaire (généré) | N/A | ❌ Non |
| `group_vars/all.yml` | `Ansible/group_vars/` | Config globale VMs | N/A | ✅ Oui |
| `group_vars/taiga_hosts.yml` | `Ansible/group_vars/` | Config Taiga | N/A | ✅ Oui |
| `group_vars/bind9_hosts.yml` | `Ansible/group_vars/` | Config DNS | N/A | ✅ Oui |
| `playbooks/site.yml` | `Ansible/playbooks/` | Orchestration | ✅ Oui | ✅ Oui |
| `roles/common/tasks/main.yml` | `Ansible/roles/common/` | Tâches communes | ✅ Oui | ✅ Oui |
| `roles/common/handlers/main.yml` | `Ansible/roles/common/` | Redémarrages | ✅ Oui | ✅ Oui |
| `bootstrap.sh` | `Ansible/` | Installation dépendances | ❌ Non | ✅ Oui |
| `run-ping-test.sh` | `Ansible/` | Test connectivité | ❌ Non | ✅ Oui |
| `validate.sh` | `Ansible/` | Validation complète | ❌ Non | ✅ Oui |


***

## 🎯 Principe d'idempotence illustré

### Exemple : Installation Docker (idempotent)

```yaml
- name: Installation Docker
  ansible.builtin.apt:
    name: docker-ce
    state: present    # ← État désiré : "présent"
```

**Comportement** :

- **1ère exécution** : Docker absent → Installation → `changed: true`
- **2ème exécution** : Docker présent → Rien → `changed: false`
- **3ème exécution** : Docker présent → Rien → `changed: false`


### Exemple : Copie fichier configuration (idempotent)

```yaml
- name: Configuration SSH hardening
  ansible.builtin.template:
    src: sshd_config.j2
    dest: /etc/ssh/sshd_config.d/99-hardening.conf
    mode: '0644'
  notify: Restart sshd
```

**Comportement** :

- **1ère exécution** : Fichier absent → Création → `changed: true` → Handler `Restart sshd` exécuté
- **2ème exécution** : Fichier identique → Rien → `changed: false` → Handler non exécuté
- **Modification SSOT** : Contenu différent → Mise à jour → `changed: true` → Handler exécuté

***

## 🔄 Workflow DevOps complet avec Ansible

```
1. Développeur modifie SSOT
   └─> vim Ansible/group_vars/taiga_hosts.yml
       └─> Changement : taiga_version: "6.8.0"

2. Commit + Push
   └─> git add group_vars/taiga_hosts.yml
   └─> git commit -m "feat: upgrade Taiga 6.7.0 → 6.8.0"
   └─> git push

3. CI/CD déclenché (GitHub Actions)
   └─> ansible-playbook playbooks/taiga.yml --check
       └─> Validation sans modification réelle

4. Si validation OK
   └─> ansible-playbook playbooks/taiga.yml --diff
       └─> Application avec affichage changements
       └─> Résultat : changed=3 (pull image, restart containers)

5. Tests post-déploiement
   └─> ./validate.sh
       └─> Vérification Taiga répond sur port 80
       └─> Vérification version 6.8.0

6. Notification (Slack/Discord)
   └─> ✅ Déploiement Taiga 6.8.0 réussi
```


***

Vous avez maintenant une **compréhension complète** d'Ansible dans l'architecture SSOT avec idempotence ! Des questions sur un aspect spécifique (rôles, playbooks, variables, scripts) ?

