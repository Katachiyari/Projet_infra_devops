# 🔷 Gestion Utilisateurs et Groupes Proxmox


***

## 📍 Explication : Système d'authentification Proxmox

### Définition

Proxmox VE utilise un **système d'authentification multi-domaines** (realms) permettant de gérer les accès à l'hyperviseur via API, WebUI et CLI. Les permissions sont contrôlées par un système de **rôles** (roles) et de **pools** de ressources.

### Comparaison des realms d'authentification

| Realm | Type | Stockage | Usage | Gestion API |
| :-- | :-- | :-- | :-- | :-- |
| **pam** | Linux PAM | `/etc/passwd` | Admin système local | ❌ Non |
| **pve** | Proxmox VE | `/etc/pve/user.cfg` | Utilisateurs Proxmox | ✅ Oui |
| **LDAP** | LDAP/AD | Serveur externe | Entreprise (SSO) | ⚠️ Readonly |
| **AD** | Active Directory | Serveur Windows | Entreprise (SSO) | ⚠️ Readonly |

### Rôle dans l'architecture SSOT

```
┌─────────────────────────────────────────────────────────────┐
│ SSOT Authentification Proxmox                               │
├─────────────────────────────────────────────────────────────┤
│ • Terraform gère utilisateurs API (token, permissions)     │
│ • Ansible configure groupes et ACLs                         │
│ • LDAP/AD comme source externe (optionnel)                  │
│ • Backup automatique /etc/pve/user.cfg                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Hiérarchie des Permissions                                  │
├─────────────────────────────────────────────────────────────┤
│ Users → Groups → Roles → Pools → Resources (VMs/Storage)   │
└─────────────────────────────────────────────────────────────┘
```


***

## 📍 Cycle de vie : Gestion utilisateurs Proxmox

### Phase 1 : Création utilisateurs/groupes (Bootstrap)

```
1. Utilisateur root@pam (existant)
   └─> Accès complet Proxmox
   └─> Utilisé pour bootstrap initial

2. Création utilisateur terraform (API)
   └─> Realm: pve (Proxmox natif)
   └─> Token API avec permissions limitées
   └─> Stocké dans secrets/proxmox-token.txt

3. Création groupes fonctionnels (SSOT)
   └─> admins_group (administration complète)
   └─> devops_group (gestion VMs)
   └─> monitoring_group (lecture seule)
   └─> backup_group (gestion backups)

4. Création utilisateurs métier (SSOT)
   └─> john@pve → admins_group
   └─> alice@pve → devops_group
   └─> bob@pve → monitoring_group
```


### Phase 2 : Attribution permissions (ACLs)

```
1. Définition rôles Proxmox (builtin)
   ├─> Administrator (tous droits)
   ├─> PVEAdmin (admin sans users)
   ├─> PVEVMAdmin (gestion VMs)
   ├─> PVEVMUser (utilisation VMs)
   ├─> PVEAuditor (lecture seule)
   └─> PVEPoolAdmin (admin pools)

2. Création rôles personnalisés (optionnel)
   └─> DevOpsRole (permissions spécifiques)
       ├─> VM.Allocate (créer VMs)
       ├─> VM.Config.* (modifier config)
       ├─> Datastore.Allocate (utiliser storage)
       └─> Pool.Allocate (créer pools)

3. Attribution ACLs (SSOT)
   └─> Path: /vms → Group: devops_group → Role: PVEVMAdmin
   └─> Path: /storage/local-lvm → Group: devops_group → Role: Datastore.Allocate
   └─> Path: /pool/production → User: alice@pve → Role: PVEPoolAdmin
```


### Phase 3 : Gestion pools de ressources

```
1. Création pools (SSOT)
   ├─> production (VMs prod)
   ├─> development (VMs dev)
   ├─> staging (VMs test)
   └─> backup (VMs backup)

2. Attribution VMs aux pools
   └─> terraform apply
       └─> Ressource proxmox_virtual_environment_vm
           └─> pool_id = "production"

3. Permissions pool-based
   └─> Group devops_group peut gérer pool production
   └─> User alice@pve peut créer VMs dans pool development
```


### Phase 4 : Automatisation via Terraform/Ansible

```
1. Terraform gère (idempotent)
   ├─> Création pools
   ├─> Attribution VMs aux pools
   └─> Tokens API

2. Ansible gère (idempotent)
   ├─> Création utilisateurs pve
   ├─> Création groupes
   ├─> Attribution ACLs
   └─> Synchronisation LDAP (si activé)

3. Backup automatique
   └─> Cron: backup /etc/pve/user.cfg
   └─> Git: versioning permissions
```


***

## 📍 Architecture SSOT : Permissions Proxmox

### Diagramme de flux SSOT

```
┌─────────────────────────────────────────────────────────────┐
│ SSOT Sources Permissions                                    │
├─────────────────────────────────────────────────────────────┤
│ • docs/proxmox-rbac.md → Documentation permissions          │
│ • group_vars/proxmox_host.yml → Config utilisateurs        │
│ • terraform.tfvars → Pools et assignments                   │
│ • secrets/proxmox-users.vault → Passwords chiffrés         │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Création Utilisateurs/Groupes (Ansible)                     │
├─────────────────────────────────────────────────────────────┤
│ pveum user add alice@pve --groups devops_group             │
│ pveum group add devops_group                                │
│ pveum acl modify /vms --group devops_group --role PVEVMAdmin│
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Création Pools (Terraform)                                  │
├─────────────────────────────────────────────────────────────┤
│ resource "proxmox_virtual_environment_pool" "production" {  │
│   pool_id = "production"                                    │
│   comment = "VMs Production"                                │
│ }                                                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Attribution VMs (Terraform)                                 │
├─────────────────────────────────────────────────────────────┤
│ resource "proxmox_virtual_environment_vm" "vm" {            │
│   pool_id = proxmox_virtual_environment_pool.production.id │
│ }                                                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ État Final Proxmox                                          │
├─────────────────────────────────────────────────────────────┤
│ • Utilisateurs créés dans realm pve                         │
│ • Groupes avec membres assignés                             │
│ • ACLs appliquées sur chemins                               │
│ • VMs dans pools avec permissions                           │
└─────────────────────────────────────────────────────────────┘
```


### Matrice de permissions (exemple)

```
┌──────────────┬──────────────┬──────────────┬──────────────┐
│ User/Group   │ Path         │ Role         │ Propagate    │
├──────────────┼──────────────┼──────────────┼──────────────┤
│ @admins      │ /            │ Administrator│ Yes          │
│ @devops      │ /vms         │ PVEVMAdmin   │ Yes          │
│ @devops      │ /storage/*   │ Datastore.   │ Yes          │
│              │              │ Allocate     │              │
│ alice@pve    │ /pool/prod   │ PVEPoolAdmin │ No           │
│ @monitoring  │ /            │ PVEAuditor   │ Yes          │
│ terraform@pve│ /            │ PVEAdmin     │ Yes          │
└──────────────┴──────────────┴──────────────┴──────────────┘
```


***

## 📍 Fichiers et code détaillés

### Fichier 1 : `docs/proxmox-rbac.md` (SSOT documentation permissions)

**Chemin** : `docs/proxmox-rbac.md`
**Rôle** : Documentation architecture RBAC Proxmox (SSOT)
**Versionné** : ✅ Oui

```markdown
# Architecture RBAC Proxmox (SSOT)

## Vue d'ensemble

L'infrastructure utilise un **modèle RBAC** (Role-Based Access Control) pour sécuriser l'accès aux ressources Proxmox.

---

## Realms d'authentification

### pve (Proxmox VE)

**Usage** : Utilisateurs natifs Proxmox (recommandé pour automatisation)

| Utilisateur | Groupe | Rôle | Usage |
|-------------|--------|------|-------|
| `terraform@pve` | - | Administrator | Provisionnement infra via API |
| `ansible@pve` | @automation | PVEAdmin | Configuration VMs |
| `john@pve` | @admins | Administrator | Administration complète |
| `alice@pve` | @devops | PVEVMAdmin | Gestion VMs production |
| `bob@pve` | @monitoring | PVEAuditor | Lecture seule (monitoring) |

### pam (Linux PAM)

**Usage** : Administrateurs système locaux uniquement

| Utilisateur | Accès |
|-------------|-------|
| `root@pam` | Shell SSH + WebUI (bootstrap uniquement) |

---

## Groupes fonctionnels (SSOT)

### @admins
**Rôle** : Administration complète Proxmox  
**Permissions** : Administrator sur `/`  
**Membres** : john@pve, root@pam

### @devops
**Rôle** : Gestion VMs et pools  
**Permissions** :
- PVEVMAdmin sur `/vms`
- Datastore.Allocate sur `/storage/local-lvm`
- Pool.Allocate sur `/pool/production`

**Membres** : alice@pve, charlie@pve

### @monitoring
**Rôle** : Lecture seule (métriques, logs)  
**Permissions** : PVEAuditor sur `/`  
**Membres** : bob@pve, prometheus@pve

### @automation
**Rôle** : Automatisation CI/CD  
**Permissions** :
- PVEAdmin sur `/` (sans gestion users)
- VM.Allocate sur `/vms`

**Membres** : ansible@pve, gitlab-runner@pve

---

## Rôles builtin Proxmox

| Rôle | Permissions | Usage |
|------|-------------|-------|
| **Administrator** | Tous privilèges | Admin système |
| **PVEAdmin** | Admin sans users | Automatisation |
| **PVEVMAdmin** | Gestion complète VMs | DevOps |
| **PVEVMUser** | Utilisation VMs (start/stop) | Utilisateurs finaux |
| **PVEAuditor** | Lecture seule | Monitoring |
| **PVEPoolAdmin** | Gestion pools | Chef de projet |
| **PVEDatastoreAdmin** | Gestion datastores | Admin stockage |

---

## Pools de ressources (SSOT)

### production
**VMs** : tools-manager, gitlab-server, dns-server  
**Permissions** :
- @devops → PVEVMAdmin
- alice@pve → PVEPoolAdmin

### development
**VMs** : dev-*  
**Permissions** :
- @devops → PVEVMAdmin (create/modify/delete)

### staging
**VMs** : staging-*  
**Permissions** :
- @devops → PVEVMAdmin

### backup
**VMs** : backup-server, pbs-*  
**Permissions** :
- @automation → PVEDatastoreAdmin

---

## ACLs détaillées

```bash
# Groupe admins : accès complet
pveum acl modify / --group admins --role Administrator

# Groupe devops : gestion VMs
pveum acl modify /vms --group devops --role PVEVMAdmin

# Groupe devops : accès storage
pveum acl modify /storage/local-lvm --group devops --role Datastore.Allocate

# Groupe monitoring : lecture seule globale
pveum acl modify / --group monitoring --role PVEAuditor

# User alice : admin pool production
pveum acl modify /pool/production --user alice@pve --role PVEPoolAdmin

# User terraform : admin sans users
pveum acl modify / --user terraform@pve --role PVEAdmin
```


---

## Tokens API (SSOT)

### terraform-token

**User** : terraform@pve
**Permissions** : PVEAdmin sur `/`
**Privilege Separation** : ✅ Yes
**Usage** : Provisionnement infrastructure

**Configuration** :

```hcl
# provider.tf
provider "proxmox" {
  endpoint = var.proxmox_endpoint
  api_token = "${var.proxmox_user}!${var.proxmox_token_id}=${var.proxmox_token_secret}"
}
```


### ansible-token

**User** : ansible@pve
**Permissions** : PVEAdmin sur `/vms`
**Privilege Separation** : ✅ Yes
**Usage** : Configuration post-déploiement

---

## Synchronisation LDAP (optionnel)

### Configuration LDAP

**Serveur** : ldap://ldap.lab.local
**Base DN** : dc=lab,dc=local
**Bind DN** : cn=proxmox,ou=services,dc=lab,dc=local
**Sync Groups** : ✅ Yes

### Groupes synchronisés

- `cn=proxmox-admins,ou=groups,dc=lab,dc=local` → @admins
- `cn=proxmox-devops,ou=groups,dc=lab,dc=local` → @devops
- `cn=proxmox-monitoring,ou=groups,dc=lab,dc=local` → @monitoring

**Commande sync** :

```bash
pveum realm sync ldap --scope both
```


---

## Matrice de décision

| Action | @admins | @devops | @monitoring | @automation |
| :-- | :-- | :-- | :-- | :-- |
| Créer VM | ✅ | ✅ | ❌ | ✅ |
| Supprimer VM | ✅ | ✅ | ❌ | ✅ |
| Modifier config VM | ✅ | ✅ | ❌ | ✅ |
| Start/Stop VM | ✅ | ✅ | ❌ | ✅ |
| Créer utilisateur | ✅ | ❌ | ❌ | ❌ |
| Créer pool | ✅ | ⚠️ (avec ACL) | ❌ | ❌ |
| Gérer storage | ✅ | ⚠️ (allocate) | ❌ | ⚠️ (backup) |
| Voir logs | ✅ | ✅ | ✅ | ✅ |
| Backup VMs | ✅ | ❌ | ❌ | ✅ |
| Modifier réseau | ✅ | ❌ | ❌ | ❌ |


---

## Audit et Conformité

### Logs audit

**Path** : `/var/log/pveproxy/access.log`
**Rotation** : 30 jours
**Monitoring** : Envoi vers Loki

### Commandes audit

```bash
# Lister utilisateurs
pveum user list

# Lister groupes
pveum group list

# Lister ACLs
pveum acl list

# Historique connexions
journalctl -u pveproxy | grep "successful auth"
```


### Backup configuration

**Path** : `/etc/pve/user.cfg`
**Backup** : Quotidien (ansible-playbook playbooks/backup-proxmox-config.yml)
**Git** : Versioning dans repo infra (chiffré)

---

## Procédure création utilisateur

```bash
# 1. Créer utilisateur
pveum user add newuser@pve --comment "Nouvel utilisateur" --email newuser@lab.local

# 2. Définir mot de passe
pveum passwd newuser@pve

# 3. Ajouter au groupe
pveum user modify newuser@pve --groups devops

# 4. (Optionnel) ACL spécifique
pveum acl modify /pool/production --user newuser@pve --role PVEVMUser

# 5. Vérifier permissions
pveum user permissions newuser@pve
```

```

***

### Fichier 2 : `group_vars/proxmox_host.yml` (SSOT config utilisateurs)

**Chemin** : `Ansible/group_vars/proxmox_host.yml`  
**Rôle** : Configuration SSOT utilisateurs/groupes Proxmox  
**Versionné** : ✅ Oui (passwords dans Vault)

```yaml
---
# ===================================================================
# SSOT Configuration Utilisateurs/Groupes Proxmox
# ===================================================================

# ===================================================================
# 1. Configuration connexion Proxmox (SSOT)
# ===================================================================
proxmox_api_host: "{{ proxmox_endpoint | regex_replace('^https?://', '') | regex_replace(':.*$', '') }}"
proxmox_api_user: "root@pam"
proxmox_api_password: "{{ vault_proxmox_root_password }}"
proxmox_validate_certs: false

# ===================================================================
# 2. Groupes Proxmox (SSOT)
# ===================================================================
proxmox_groups:
  - name: admins
    comment: "Administrateurs Proxmox (accès complet)"
  
  - name: devops
    comment: "Équipe DevOps (gestion VMs)"
  
  - name: monitoring
    comment: "Monitoring et audit (lecture seule)"
  
  - name: automation
    comment: "Automatisation CI/CD (bots)"

# ===================================================================
# 3. Utilisateurs Proxmox (SSOT)
# ===================================================================
proxmox_users:
  # Administrateurs
  - username: john@pve
    password: "{{ vault_proxmox_john_password }}"
    email: john@lab.local
    firstname: John
    lastname: Doe
    groups: [admins]
    comment: "Administrateur principal"
    enable: true
  
  # DevOps
  - username: alice@pve
    password: "{{ vault_proxmox_alice_password }}"
    email: alice@lab.local
    firstname: Alice
    lastname: Smith
    groups: [devops]
    comment: "DevOps Engineer"
    enable: true
  
  - username: charlie@pve
    password: "{{ vault_proxmox_charlie_password }}"
    email: charlie@lab.local
    firstname: Charlie
    lastname: Brown
    groups: [devops]
    comment: "DevOps Engineer"
    enable: true
  
  # Monitoring
  - username: bob@pve
    password: "{{ vault_proxmox_bob_password }}"
    email: bob@lab.local
    firstname: Bob
    lastname: Monitor
    groups: [monitoring]
    comment: "Monitoring (lecture seule)"
    enable: true
  
  # Automation
  - username: terraform@pve
    password: "{{ vault_proxmox_terraform_password }}"
    email: automation@lab.local
    groups: [automation]
    comment: "Terraform automation user"
    enable: true
  
  - username: ansible@pve
    password: "{{ vault_proxmox_ansible_password }}"
    email: automation@lab.local
    groups: [automation]
    comment: "Ansible automation user"
    enable: true

# ===================================================================
# 4. ACLs Proxmox (SSOT)
# ===================================================================
proxmox_acls:
  # Groupe admins : accès complet
  - path: /
    type: group
    ugid: admins
    role: Administrator
    propagate: true
  
  # Groupe devops : gestion VMs
  - path: /vms
    type: group
    ugid: devops
    role: PVEVMAdmin
    propagate: true
  
  # Groupe devops : accès storage
  - path: /storage/local-lvm
    type: group
    ugid: devops
    role: Datastore.Allocate
    propagate: true
  
  # Groupe monitoring : lecture seule
  - path: /
    type: group
    ugid: monitoring
    role: PVEAuditor
    propagate: true
  
  # Groupe automation : admin sans users
  - path: /
    type: group
    ugid: automation
    role: PVEAdmin
    propagate: true
  
  # User alice : admin pool production
  - path: /pool/production
    type: user
    ugid: alice@pve
    role: PVEPoolAdmin
    propagate: false

# ===================================================================
# 5. Tokens API (SSOT)
# ===================================================================
proxmox_api_tokens:
  - user: terraform@pve
    token_id: terraform-token
    comment: "Terraform provisioning"
    expire: 0                    # Jamais
    privsep: true                # Privilege separation (sécurité)
  
  - user: ansible@pve
    token_id: ansible-token
    comment: "Ansible configuration"
    expire: 0
    privsep: true

# ===================================================================
# 6. Configuration LDAP (optionnel)
# ===================================================================
proxmox_ldap_enabled: false

proxmox_ldap_config:
  realm: ldap
  server1: ldap.lab.local
  port: 389
  base_dn: dc=lab,dc=local
  bind_dn: cn=proxmox,ou=services,dc=lab,dc=local
  bind_password: "{{ vault_ldap_bind_password }}"
  user_attr: uid
  sync_groups: true
  verify: false

# Mapping groupes LDAP → Proxmox
proxmox_ldap_group_mapping:
  - ldap_group: proxmox-admins
    proxmox_group: admins
  
  - ldap_group: proxmox-devops
    proxmox_group: devops
  
  - ldap_group: proxmox-monitoring
    proxmox_group: monitoring

# ===================================================================
# 7. Politique mots de passe (SSOT)
# ===================================================================
proxmox_password_policy:
  min_length: 12
  require_uppercase: true
  require_lowercase: true
  require_numbers: true
  require_special: true
  expiration_days: 90

# ===================================================================
# 8. Audit et logs (SSOT)
# ===================================================================
proxmox_audit_enabled: true
proxmox_audit_log_path: /var/log/pveproxy/access.log
proxmox_audit_retention_days: 90

# Envoi logs vers serveur central
proxmox_syslog_server: "172.16.100.40:514"
proxmox_syslog_protocol: tcp
```


***

### Fichier 3 : `secrets/proxmox-users.vault` (Passwords chiffrés)

**Chemin** : `Ansible/group_vars/secrets/proxmox-users.vault`
**Rôle** : Passwords Ansible Vault (SSOT secrets)
**Versionné** : ✅ Oui (chiffré)

```yaml
---
# ===================================================================
# Passwords utilisateurs Proxmox (Ansible Vault)
# ===================================================================
# Chiffrer : ansible-vault encrypt secrets/proxmox-users.vault
# Éditer : ansible-vault edit secrets/proxmox-users.vault

vault_proxmox_root_password: "SuperSecureRootPass123!"
vault_proxmox_john_password: "JohnAdm!nP@ss2024"
vault_proxmox_alice_password: "Al1ceDevOps#Secure"
vault_proxmox_charlie_password: "Ch@rl1eDevOpsPass"
vault_proxmox_bob_password: "B0bM0nit0r!ngPass"
vault_proxmox_terraform_password: "Terr@f0rmT0ken!2024"
vault_proxmox_ansible_password: "Ans!bleAut0Pass2024"

# LDAP
vault_ldap_bind_password: "LdapB!ndP@ssword123"
```

**Commandes Ansible Vault** :

```bash
# Créer vault chiffré
ansible-vault create group_vars/secrets/proxmox-users.vault

# Éditer vault
ansible-vault edit group_vars/secrets/proxmox-users.vault

# Chiffrer fichier existant
ansible-vault encrypt group_vars/secrets/proxmox-users.vault

# Déchiffrer temporairement
ansible-vault decrypt group_vars/secrets/proxmox-users.vault

# Utiliser avec playbook
ansible-playbook playbooks/proxmox-users.yml --ask-vault-pass
```


***

### Fichier 4 : `roles/proxmox_users/tasks/main.yml` (Gestion utilisateurs)

**Chemin** : `Ansible/roles/proxmox_users/tasks/main.yml`
**Rôle** : Création utilisateurs/groupes Proxmox (idempotent)
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Rôle proxmox_users : Gestion utilisateurs Proxmox (idempotent)
# ===================================================================

# ===================================================================
# 1. Création groupes Proxmox (idempotent)
# ===================================================================
- name: Créer groupes Proxmox (SSOT)
  community.general.proxmox_group:
    api_host: "{{ proxmox_api_host }}"
    api_user: "{{ proxmox_api_user }}"
    api_password: "{{ proxmox_api_password }}"
    validate_certs: "{{ proxmox_validate_certs }}"
    name: "{{ item.name }}"
    comment: "{{ item.comment }}"
    state: present
  loop: "{{ proxmox_groups }}"
  no_log: true  # Ne pas logger passwords
  tags: ['proxmox', 'groups']

# ===================================================================
# 2. Création utilisateurs Proxmox (idempotent)
# ===================================================================
- name: Créer utilisateurs Proxmox (SSOT)
  community.general.proxmox_user:
    api_host: "{{ proxmox_api_host }}"
    api_user: "{{ proxmox_api_user }}"
    api_password: "{{ proxmox_api_password }}"
    validate_certs: "{{ proxmox_validate_certs }}"
    userid: "{{ item.username }}"
    password: "{{ item.password }}"
    email: "{{ item.email | default(omit) }}"
    firstname: "{{ item.firstname | default(omit) }}"
    lastname: "{{ item.lastname | default(omit) }}"
    groups: "{{ item.groups | default([]) }}"
    comment: "{{ item.comment | default(omit) }}"
    enable: "{{ item.enable | default(true) }}"
    state: present
  loop: "{{ proxmox_users }}"
  no_log: true
  tags: ['proxmox', 'users']

# ===================================================================
# 3. Configuration ACLs (idempotent)
# ===================================================================
- name: Configurer ACLs Proxmox (SSOT)
  ansible.builtin.command:
    cmd: >
      pveum acl modify {{ item.path }}
      --{{ item.type }} {{ item.ugid }}
      --role {{ item.role }}
      {{ '--propagate' if item.propagate else '--no-propagate' }}
  loop: "{{ proxmox_acls }}"
  register: acl_result
  changed_when: false  # pveum acl modify est idempotent
  tags: ['proxmox', 'acls']

# ===================================================================
# 4. Création tokens API (idempotent)
# ===================================================================
- name: Créer tokens API Proxmox (SSOT)
  ansible.builtin.shell: |
    set -o pipefail
    pveum user token add {{ item.user }} {{ item.token_id }} \
      --comment "{{ item.comment }}" \
      --expire {{ item.expire }} \
      {{ '--privsep 1' if item.privsep else '' }} \
      --output-format json || \
    pveum user token list {{ item.user }} --output-format json | \
    jq -r '.[] | select(.tokenid=="{{ item.token_id }}") | .value'
  args:
    executable: /bin/bash
  loop: "{{ proxmox_api_tokens }}"
  register: token_creation
  changed_when: "'value' in token_creation.stdout"
  no_log: true
  tags: ['proxmox', 'tokens']

- name: Sauvegarder tokens générés (SSOT)
  ansible.builtin.copy:
    content: |
      # Tokens API Proxmox (généré le {{ ansible_date_time.iso8601 }})
      {% for item in token_creation.results %}
      {% if 'value' in item.stdout %}
      {{ proxmox_api_tokens[loop.index0].user }}!{{ proxmox_api_tokens[loop.index0].token_id }}={{ (item.stdout | from_json).value }}
      {% endif %}
      {% endfor %}
    dest: "{{ playbook_dir }}/../secrets/proxmox-tokens-generated.txt"
    mode: '0600'
  delegate_to: localhost
  when: token_creation.changed
  tags: ['proxmox', 'tokens']

# ===================================================================
# 5. Configuration LDAP (optionnel)
# ===================================================================
- name: Configurer realm LDAP
  ansible.builtin.command:
    cmd: >
      pveum realm add {{ proxmox_ldap_config.realm }}
      --type ldap
      --server1 {{ proxmox_ldap_config.server1 }}
      --port {{ proxmox_ldap_config.port }}
      --base_dn {{ proxmox_ldap_config.base_dn }}
      --bind_dn {{ proxmox_ldap_config.bind_dn }}
      --bind_password {{ proxmox_ldap_config.bind_password }}
      --user_attr {{ proxmox_ldap_config.user_attr }}
      {{ '--verify 0' if not proxmox_ldap_config.verify else '' }}
  when: proxmox_ldap_enabled
  no_log: true
  register: ldap_config
  changed_when: "'already exists' not in ldap_config.stderr"
  failed_when: ldap_config.rc != 0 and 'already exists' not in ldap_config.stderr
  tags: ['proxmox', 'ldap']

- name: Synchroniser groupes LDAP
  ansible.builtin.command:
    cmd: pveum realm sync {{ proxmox_ldap_config.realm }} --scope both
  when: 
    - proxmox_ldap_enabled
    - proxmox_ldap_config.sync_groups
  changed_when: false
  tags: ['proxmox', 'ldap']

# ===================================================================
# 6. Audit et vérification
# ===================================================================
- name: Lister utilisateurs créés
  ansible.builtin.command:
    cmd: pveum user list --output-format json
  register: users_list
  changed_when: false
  tags: ['proxmox', 'audit']

- name: Afficher résumé utilisateurs
  ansible.builtin.debug:
    msg:
      - "=========================================="
      - "Utilisateurs Proxmox créés (SSOT)"
      - "=========================================="
      - "{{ (users_list.stdout | from_json) | map(attribute='userid') | list }}"
  tags: ['proxmox', 'audit']

- name: Lister ACLs configurées
  ansible.builtin.command:
    cmd: pveum acl list
  register: acls_list
  changed_when: false
  tags: ['proxmox', 'audit']

- name: Afficher ACLs
  ansible.builtin.debug:
    var: acls_list.stdout_lines
  tags: ['proxmox', 'audit']
```


***

### Fichier 5 : `terraform.tfvars` (Pools SSOT)

**Chemin** : `terraform.tfvars`
**Ajout** : Configuration pools
**Versionné** : ❌ Non (secrets)

```hcl
# ===================================================================
# SSOT Infrastructure : Pools de ressources
# ===================================================================

# ... (config existante)

# ===================================================================
# NOUVEAUTÉ : Pools Proxmox (SSOT)
# ===================================================================
pools = {
  production = {
    comment = "VMs Production (haute disponibilité)"
  }
  
  development = {
    comment = "VMs Développement (environnement test)"
  }
  
  staging = {
    comment = "VMs Staging (pré-production)"
  }
  
  backup = {
    comment = "Infrastructure backup et snapshots"
  }
}

# ===================================================================
# SSOT : Attribution VMs aux pools
# ===================================================================
nodes = {
  tools-manager = {
    ip     = "172.16.100.20"
    cpu    = 4
    mem    = 8192
    disk   = 50
    bridge = "vmbr0"
    pool   = "production"        # ← NOUVEAUTÉ : Pool
    tags   = ["tools", "prod"]
  }

  gitlab-server = {
    ip     = "172.16.100.30"
    cpu    = 4
    mem    = 8192
    disk   = 100
    bridge = "vmbr0"
    pool   = "production"
    tags   = ["git", "prod"]
  }

  dev-sandbox = {
    ip     = "172.16.100.50"
    cpu    = 2
    mem    = 4096
    disk   = 30
    bridge = "vmbr0"
    pool   = "development"       # ← Pool dev
    tags   = ["dev", "test"]
  }

  backup-server = {
    ip     = "172.16.10.20"
    cpu    = 2
    mem    = 4096
    disk   = 500
    bridge = "vmbr2"
    pool   = "backup"
    tags   = ["backup", "mgmt"]
  }
}
```


***

### Fichier 6 : `pools.tf` (Création pools Terraform)

**Chemin** : `pools.tf` (nouveau fichier)
**Rôle** : Création pools Proxmox (idempotent)
**Versionné** : ✅ Oui

```hcl
# ===================================================================
# Pools Proxmox (SSOT)
# ===================================================================

variable "pools" {
  description = "Pools de ressources Proxmox (SSOT)"
  type = map(object({
    comment = string
  }))
  default = {}
}

# ===================================================================
# Création pools (idempotent)
# ===================================================================
resource "proxmox_virtual_environment_pool" "pool" {
  for_each = var.pools

  pool_id = each.key
  comment = each.value.comment
}

# ===================================================================
# Output pools créés
# ===================================================================
output "pools" {
  description = "Pools Proxmox créés"
  value = {
    for k, v in proxmox_virtual_environment_pool.pool : k => {
      id      = v.id
      comment = v.comment
    }
  }
}
```


***

### Fichier 7 : `main.tf` (Attribution VMs aux pools)

**Chemin** : `main.tf`
**Modification** : Ajout `pool_id`
**Versionné** : ✅ Oui

```hcl
resource "proxmox_virtual_environment_vm" "vm" {
  for_each  = var.nodes
  name      = each.key
  node_name = var.node_name
  tags      = sort(distinct([for t in each.value.tags : lower(t)]))

  # ===================================================================
  # NOUVEAUTÉ : Attribution pool (SSOT)
  # ===================================================================
  pool_id = each.value.pool != null ? proxmox_virtual_environment_pool.pool[each.value.pool].id : null

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

  vga {
    type   = "qxl"
    memory = 32
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

  # Dépendance : attendre création pool
  depends_on = [proxmox_virtual_environment_pool.pool]
}
```


***

### Fichier 8 : `playbooks/proxmox-users.yml` (Playbook gestion utilisateurs)

**Chemin** : `Ansible/playbooks/proxmox-users.yml`
**Rôle** : Playbook déploiement utilisateurs Proxmox
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Playbook : Gestion utilisateurs/groupes Proxmox (SSOT)
# ===================================================================

- name: Configuration utilisateurs Proxmox
  hosts: localhost
  gather_facts: false
  
  vars_files:
    - ../group_vars/proxmox_host.yml
    - ../group_vars/secrets/proxmox-users.vault
  
  tasks:
    - name: Inclure rôle proxmox_users
      ansible.builtin.include_role:
        name: proxmox_users
      tags: ['proxmox', 'users', 'groups', 'acls']
    
    # ===================================================================
    # Post-validation
    # ===================================================================
    - name: Vérifier connectivité API avec nouveau token
      ansible.builtin.uri:
        url: "{{ proxmox_endpoint }}/api2/json/cluster/resources"
        method: GET
        headers:
          Authorization: "PVEAPIToken=terraform@pve!terraform-token={{ lookup('file', '../secrets/proxmox-tokens-generated.txt') | regex_search('terraform@pve!terraform-token=([^\\n]+)', '\\1') | first }}"
        validate_certs: false
      register: api_test
      failed_when: api_test.status != 200
      tags: ['proxmox', 'validation']
    
    - name: Afficher résultat test API
      ansible.builtin.debug:
        msg: "✓ Token API Terraform fonctionnel ({{ api_test.json.data | length }} ressources)"
      tags: ['proxmox', 'validation']
```

**Utilisation** :

```bash
# Déploiement utilisateurs
ansible-playbook playbooks/proxmox-users.yml --ask-vault-pass

# Déploiement groupes uniquement
ansible-playbook playbooks/proxmox-users.yml --tags groups --ask-vault-pass

# Déploiement ACLs uniquement
ansible-playbook playbooks/proxmox-users.yml --tags acls --ask-vault-pass

# Mode dry-run
ansible-playbook playbooks/proxmox-users.yml --check --ask-vault-pass
```


***

## 📊 Tableau récapitulatif des fichiers

| Fichier | Chemin | Rôle SSOT | Versionné |
| :-- | :-- | :-- | :-- |
| `proxmox-rbac.md` | `docs/` | Documentation RBAC | ✅ Oui |
| `proxmox_host.yml` | `Ansible/group_vars/` | Config utilisateurs SSOT | ✅ Oui |
| `proxmox-users.vault` | `Ansible/group_vars/secrets/` | Passwords chiffrés | ✅ Oui (Vault) |
| `roles/proxmox_users/tasks/main.yml` | `Ansible/roles/proxmox_users/` | Gestion utilisateurs | ✅ Oui |
| `terraform.tfvars` | Racine | Pools SSOT | ❌ Non |
| `pools.tf` | Racine | Création pools | ✅ Oui |
| `main.tf` | Racine | Attribution VMs pools | ✅ Oui |
| `playbooks/proxmox-users.yml` | `Ansible/playbooks/` | Playbook déploiement | ✅ Oui |


***

## 🎯 Workflow DevOps Utilisateurs Proxmox

### Déploiement initial

```bash
# 1. Créer vault secrets
ansible-vault create Ansible/group_vars/secrets/proxmox-users.vault
# Ajouter passwords

# 2. Configurer utilisateurs/groupes (SSOT)
vim Ansible/group_vars/proxmox_host.yml

# 3. Déployer utilisateurs
cd Ansible/
ansible-playbook playbooks/proxmox-users.yml --ask-vault-pass

# 4. Récupérer tokens générés
cat ../secrets/proxmox-tokens-generated.txt

# 5. Configurer Terraform avec token
vim terraform.tfvars
# proxmox_token_id = "terraform-token"
# proxmox_token_secret = "<value>"

# 6. Créer pools
terraform plan
terraform apply
```


### Ajout nouvel utilisateur

```bash
# 1. Ajouter password dans Vault
ansible-vault edit Ansible/group_vars/secrets/proxmox-users.vault
# vault_proxmox_newuser_password: "SecurePass123!"

# 2. Ajouter utilisateur dans SSOT
vim Ansible/group_vars/proxmox_host.yml
# proxmox_users:
#   - username: newuser@pve
#     password: "{{ vault_proxmox_newuser_password }}"
#     groups: [devops]

# 3. Appliquer (idempotent)
ansible-playbook playbooks/proxmox-users.yml --ask-vault-pass

# 4. Vérifier
pveum user list | grep newuser
pveum user permissions newuser@pve
```


### Modification permissions

```bash
# 1. Modifier ACLs dans SSOT
vim Ansible/group_vars/proxmox_host.yml
# proxmox_acls:
#   - path: /pool/newpool
#     type: user
#     ugid: alice@pve
#     role: PVEPoolAdmin

# 2. Appliquer uniquement ACLs
ansible-playbook playbooks/proxmox-users.yml --tags acls --ask-vault-pass

# 3. Vérifier
pveum acl list | grep newpool
```


***


