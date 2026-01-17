# 🔷 Client Virtuel Visuel : SPICE et xterm.js


***

## 📍 Explication : Console virtuelle des VMs

### Définition

**SPICE** (Simple Protocol for Independent Computing Environments) et **xterm.js** sont deux technologies permettant l'accès console distant aux VMs, directement depuis un navigateur web.

### Comparaison des technologies

| Critère | SPICE | xterm.js | noVNC |
| :-- | :-- | :-- | :-- |
| **Type** | Protocole display complet (GPU) | Terminal web (SSH) | VNC web |
| **Cas d'usage** | Bureau graphique (GUI) | CLI uniquement | Desktop VNC |
| **Performance** | Excellente (compression) | Légère (texte seul) | Moyenne |
| **Dépendances** | SPICE client + proxy | WebSocket + SSH | noVNC proxy |
| **Intégration Proxmox** | ✅ Natif | ❌ Custom | ✅ Natif |

### Rôle dans l'architecture SSOT

```
┌─────────────────────────────────────────────────────────────┐
│ SSOT Accès Console Virtuelle                                │
├─────────────────────────────────────────────────────────────┤
│ • Terraform configure qemu-guest-agent                      │
│ • Cloud-init installe SPICE vdagent                         │
│ • Ansible déploie xterm.js (console web SSH)                │
│ • Proxmox expose consoles via API                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Accès Console Multi-Canal                                   │
├─────────────────────────────────────────────────────────────┤
│ 1. Proxmox Web UI → Console SPICE (GUI)                    │
│ 2. Proxmox Web UI → noVNC (GUI web)                        │
│ 3. Custom Web UI → xterm.js (SSH terminal)                 │
│ 4. SSH direct → Terminal natif                              │
└─────────────────────────────────────────────────────────────┘
```


***

## 📍 Cycle de vie : SPICE + xterm.js

### Phase 1 : Installation SPICE côté VM (Cloud-init)

```
1. Template Proxmox créé
   └─> Image Ubuntu avec qemu-guest-agent

2. Cloud-init exécute au boot
   └─> Installation packages :
       ├─> spice-vdagent (agent SPICE guest)
       ├─> qemu-guest-agent (communication Proxmox)
       └─> xserver-xorg-video-qxl (pilote GPU virtuel)

3. Services démarrés
   └─> systemctl enable spice-vdagent
   └─> systemctl start spice-vdagent

4. Console SPICE disponible
   └─> Proxmox Web UI → VM → Console → SPICE
```


### Phase 2 : Déploiement xterm.js (Ansible)

```
1. Ansible installe Node.js
   └─> Via rôle nodejs

2. Ansible clone xterm.js
   └─> git clone https://github.com/xtermjs/xterm.js

3. Configuration WebSocket SSH bridge
   └─> Installation websockify ou wetty
   └─> Création service systemd

4. Reverse proxy (optionnel)
   └─> Nginx/Traefik devant xterm.js
   └─> SSL/TLS (Let's Encrypt)

5. Console web accessible
   └─> https://console.lab.local
   └─> Authentification requise
```


### Phase 3 : Utilisation Multi-Canal

```
Administrateur → Choix canal accès :

1. Console SPICE (GUI complète)
   └─> Proxmox UI → VM → Console → Download SPICE file
   └─> Ouverture virt-viewer/remote-viewer
   └─> Bureau graphique complet

2. noVNC (GUI web)
   └─> Proxmox UI → VM → Console → noVNC
   └─> Navigateur web (HTML5)
   └─> Pas d'installation client

3. xterm.js (Terminal SSH web)
   └─> https://console.lab.local
   └─> Login SSH via WebSocket
   └─> Terminal CLI dans navigateur

4. SSH direct (Terminal natif)
   └─> ssh -i keys/ansible_ed25519 ansible@<ip>
   └─> Terminal local
```


***

## 📍 Architecture SSOT : Console Virtuelle

### Diagramme de flux SSOT

```
┌─────────────────────────────────────────────────────────────┐
│ SSOT Sources                                                │
├─────────────────────────────────────────────────────────────┤
│ • cloud-init/user-data.yaml.tftpl → Packages SPICE         │
│ • group_vars/console_hosts.yml → Config xterm.js           │
│ • main.tf → Configuration SPICE display (QXL)              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Provisionnement (Terraform)                                 │
├─────────────────────────────────────────────────────────────┤
│ vga {                                                       │
│   type = "qxl"          # GPU virtuel SPICE                │
│   memory = 32           # VRAM 32MB                         │
│ }                                                           │
│                                                             │
│ agent {                                                     │
│   enabled = true        # qemu-guest-agent                  │
│ }                                                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Bootstrap (Cloud-init)                                      │
├─────────────────────────────────────────────────────────────┤
│ packages:                                                   │
│   - spice-vdagent       # Agent SPICE guest                │
│   - qemu-guest-agent    # Communication Proxmox            │
│   - xserver-xorg-video-qxl  # Pilote GPU QXL               │
│                                                             │
│ runcmd:                                                     │
│   - systemctl enable spice-vdagent                         │
│   - systemctl start spice-vdagent                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Configuration (Ansible)                                     │
├─────────────────────────────────────────────────────────────┤
│ • Rôle nodejs → Installation Node.js 20.x                  │
│ • Rôle xterm_console → Déploiement serveur xterm.js       │
│ • Rôle nginx → Reverse proxy HTTPS                         │
│ • Certificats SSL → Let's Encrypt via certbot              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Console Disponible                                          │
├─────────────────────────────────────────────────────────────┤
│ • Proxmox → SPICE/noVNC (GUI)                              │
│ • Web → https://console.lab.local (xterm.js)               │
│ • SSH → Terminal natif                                      │
└─────────────────────────────────────────────────────────────┘
```


***

## 📍 Fichiers et code détaillés

### Fichier 1 : `cloud-init/user-data.yaml.tftpl` (ajout SPICE)

**Chemin** : `cloud-init/user-data.yaml.tftpl`
**Modification** : Ajout packages SPICE
**Versionné** : ✅ Oui

```yaml
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
  
  # ===================================================================
  # NOUVEAUTÉ : Packages SPICE (console graphique)
  # ===================================================================
  - spice-vdagent              # Agent SPICE guest (clipboard, resize)
  - xserver-xorg-video-qxl     # Pilote GPU QXL (accélération graphique)
  - spice-webdavd              # Partage fichiers SPICE (optionnel)

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
  
  # ===================================================================
  # NOUVEAUTÉ : Activation SPICE vdagent
  # ===================================================================
  - [ systemctl, enable, --now, spice-vdagent ]
  - [ systemctl, enable, --now, spice-webdavd ]
  
  - [ systemctl, restart, ssh ]
  - [ chown, -R, 'ansible:ansible', '/home/ansible' ]
```

**Explication des packages SPICE** :


| Package | Rôle | Requis |
| :-- | :-- | :-- |
| `spice-vdagent` | Agent SPICE côté guest (clipboard sync, résolution dynamique) | ✅ Oui |
| `xserver-xorg-video-qxl` | Pilote GPU virtuel QXL (accélération 2D/3D) | ✅ Oui |
| `spice-webdavd` | Partage de fichiers SPICE (drag \& drop) | ⚠️ Optionnel |


***

### Fichier 2 : `main.tf` (Configuration GPU QXL)

**Chemin** : `main.tf`
**Modification** : Ajout configuration GPU SPICE
**Versionné** : ✅ Oui

```hcl
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

  # ===================================================================
  # NOUVEAUTÉ : Configuration GPU SPICE (QXL)
  # ===================================================================
  vga {
    type   = "qxl"           # GPU virtuel QXL (SPICE)
    memory = 32              # VRAM 32MB (suffisant pour bureau léger)
  }

  # Alternative : VirtIO GPU (plus performant mais moins compatible)
  # vga {
  #   type   = "virtio"
  #   memory = 64
  # }

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
    
    dns {
      servers = ["1.1.1.1", "1.0.0.1"]
    }
  }

  agent {
    enabled = true
  }
}
```

**Comparaison types GPU** :


| Type | Performance | Compatibilité | Usage |
| :-- | :-- | :-- | :-- |
| `qxl` | Bonne | Excellente | SPICE (recommandé) |
| `virtio` | Excellente | Moyenne | VirtIO GPU (3D) |
| `std` | Faible | Maximale | VGA standard (fallback) |
| `vmware` | Moyenne | Bonne | VMware SVGA |


***

### Fichier 3 : `group_vars/console_hosts.yml` (Config xterm.js)

**Chemin** : `Ansible/group_vars/console_hosts.yml`
**Rôle** : Configuration SSOT xterm.js
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# SSOT Configuration Console Web (xterm.js)
# ===================================================================

# ===================================================================
# 1. Configuration Node.js (SSOT)
# ===================================================================
nodejs_version: "20.x"
nodejs_install_npm_user: ansible
nodejs_npm_global_packages:
  - pm2                        # Process manager
  - npm-check-updates          # Mise à jour packages

# ===================================================================
# 2. Configuration xterm.js backend (Wetty)
# ===================================================================
# Wetty = WebSocket SSH bridge pour xterm.js
xterm_backend: wetty
xterm_version: "2.5.0"
xterm_install_dir: /opt/xterm-console
xterm_user: xterm
xterm_group: xterm

# Port d'écoute Wetty (local uniquement, Nginx reverse proxy devant)
xterm_port: 3000
xterm_host: "127.0.0.1"

# Configuration SSH pour Wetty
xterm_ssh_host: "localhost"
xterm_ssh_port: 22
xterm_ssh_user_configurable: true    # Utilisateur choisi au login

# Base URL pour reverse proxy
xterm_base_url: "/console"

# ===================================================================
# 3. Configuration Nginx reverse proxy (SSOT)
# ===================================================================
xterm_domain: "console.lab.local"
xterm_ssl_enabled: true
xterm_ssl_certificate: "/etc/letsencrypt/live/{{ xterm_domain }}/fullchain.pem"
xterm_ssl_certificate_key: "/etc/letsencrypt/live/{{ xterm_domain }}/privkey.pem"

# Authentification basique (optionnel)
xterm_auth_enabled: true
xterm_auth_users:
  - username: admin
    password: "{{ vault_xterm_admin_password }}"  # Ansible Vault

# ===================================================================
# 4. Configuration PM2 (SSOT)
# ===================================================================
xterm_pm2_instances: 2          # Instances parallèles
xterm_pm2_max_memory: "200M"    # Limite mémoire
xterm_pm2_log_dir: "/var/log/xterm"

# ===================================================================
# 5. Configuration firewall (SSOT)
# ===================================================================
firewall_allowed_ports:
  - 443/tcp                     # HTTPS xterm.js
  - 80/tcp                      # HTTP (redirect HTTPS)

# ===================================================================
# 6. Configuration Let's Encrypt (SSOT)
# ===================================================================
certbot_admin_email: "admin@lab.local"
certbot_certs:
  - domains:
      - "{{ xterm_domain }}"
    webroot_path: /var/www/html

# ===================================================================
# 7. Options avancées xterm.js (SSOT)
# ===================================================================
xterm_options:
  fontSize: 14
  fontFamily: "'Fira Code', 'Courier New', monospace"
  theme:
    background: "#1e1e1e"
    foreground: "#d4d4d4"
    cursor: "#ffffff"
  cursorBlink: true
  cursorStyle: "block"
  scrollback: 10000            # Lignes historique terminal
  bellStyle: "sound"
```


***

### Fichier 4 : `roles/xterm_console/tasks/main.yml` (Déploiement xterm.js)

**Chemin** : `Ansible/roles/xterm_console/tasks/main.yml`
**Rôle** : Installation et configuration Wetty + xterm.js (idempotent)
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Rôle xterm_console : Déploiement console web SSH (idempotent)
# ===================================================================

# ===================================================================
# 1. Création utilisateur système xterm (idempotent)
# ===================================================================
- name: Créer utilisateur système xterm
  ansible.builtin.user:
    name: "{{ xterm_user }}"
    system: true
    shell: /usr/sbin/nologin
    home: "{{ xterm_install_dir }}"
    create_home: false
  tags: ['xterm', 'user']

- name: Créer groupe xterm
  ansible.builtin.group:
    name: "{{ xterm_group }}"
    system: true
  tags: ['xterm', 'user']

# ===================================================================
# 2. Installation Node.js (idempotent)
# ===================================================================
- name: Ajouter clé GPG NodeSource
  ansible.builtin.apt_key:
    url: "https://deb.nodesource.com/gpgkey/nodesource.gpg.key"
    state: present
  tags: ['xterm', 'nodejs']

- name: Ajouter repository NodeSource
  ansible.builtin.apt_repository:
    repo: "deb https://deb.nodesource.com/node_{{ nodejs_version }} {{ ansible_distribution_release }} main"
    state: present
    filename: nodesource
  tags: ['xterm', 'nodejs']

- name: Installation Node.js
  ansible.builtin.apt:
    name:
      - nodejs
      - npm
    state: present
    update_cache: true
  tags: ['xterm', 'nodejs']

- name: Installation packages npm globaux
  community.general.npm:
    name: "{{ item }}"
    global: true
    state: present
  loop: "{{ nodejs_npm_global_packages }}"
  tags: ['xterm', 'nodejs']

# ===================================================================
# 3. Installation Wetty (backend xterm.js) - Idempotent
# ===================================================================
- name: Créer répertoire installation
  ansible.builtin.file:
    path: "{{ xterm_install_dir }}"
    state: directory
    owner: "{{ xterm_user }}"
    group: "{{ xterm_group }}"
    mode: '0755'
  tags: ['xterm', 'install']

- name: Installation Wetty via npm (idempotent)
  community.general.npm:
    name: wetty
    version: "{{ xterm_version }}"
    path: "{{ xterm_install_dir }}"
    state: present
  become: true
  become_user: "{{ xterm_user }}"
  tags: ['xterm', 'install']

# ===================================================================
# 4. Configuration Wetty (SSOT - idempotent)
# ===================================================================
- name: Créer répertoire configuration
  ansible.builtin.file:
    path: "{{ xterm_install_dir }}/config"
    state: directory
    owner: "{{ xterm_user }}"
    group: "{{ xterm_group }}"
    mode: '0755'
  tags: ['xterm', 'config']

- name: Générer configuration Wetty (SSOT)
  ansible.builtin.template:
    src: wetty-config.js.j2
    dest: "{{ xterm_install_dir }}/config/config.js"
    owner: "{{ xterm_user }}"
    group: "{{ xterm_group }}"
    mode: '0644'
  notify: Restart xterm
  tags: ['xterm', 'config']

# ===================================================================
# 5. Configuration service systemd (idempotent)
# ===================================================================
- name: Créer service systemd Wetty
  ansible.builtin.template:
    src: xterm.service.j2
    dest: /etc/systemd/system/xterm.service
    owner: root
    group: root
    mode: '0644'
  notify:
    - Reload systemd
    - Restart xterm
  tags: ['xterm', 'systemd']

- name: Activer et démarrer service xterm (idempotent)
  ansible.builtin.systemd:
    name: xterm
    state: started
    enabled: true
    daemon_reload: true
  tags: ['xterm', 'systemd']

# ===================================================================
# 6. Configuration Nginx reverse proxy (idempotent)
# ===================================================================
- name: Installation Nginx
  ansible.builtin.apt:
    name: nginx
    state: present
  tags: ['xterm', 'nginx']

- name: Configuration vhost Nginx xterm.js (SSOT)
  ansible.builtin.template:
    src: nginx-xterm.conf.j2
    dest: "/etc/nginx/sites-available/{{ xterm_domain }}"
    owner: root
    group: root
    mode: '0644'
  notify: Reload nginx
  tags: ['xterm', 'nginx']

- name: Activer vhost Nginx
  ansible.builtin.file:
    src: "/etc/nginx/sites-available/{{ xterm_domain }}"
    dest: "/etc/nginx/sites-enabled/{{ xterm_domain }}"
    state: link
  notify: Reload nginx
  tags: ['xterm', 'nginx']

# ===================================================================
# 7. Configuration SSL Let's Encrypt (idempotent)
# ===================================================================
- name: Installation certbot
  ansible.builtin.apt:
    name:
      - certbot
      - python3-certbot-nginx
    state: present
  when: xterm_ssl_enabled
  tags: ['xterm', 'ssl']

- name: Génération certificat Let's Encrypt (idempotent)
  ansible.builtin.command:
    cmd: >
      certbot certonly --nginx
      --non-interactive
      --agree-tos
      --email {{ certbot_admin_email }}
      -d {{ xterm_domain }}
  args:
    creates: "/etc/letsencrypt/live/{{ xterm_domain }}/fullchain.pem"
  when: xterm_ssl_enabled
  notify: Reload nginx
  tags: ['xterm', 'ssl']

# ===================================================================
# 8. Création logs (idempotent)
# ===================================================================
- name: Créer répertoire logs
  ansible.builtin.file:
    path: "{{ xterm_pm2_log_dir }}"
    state: directory
    owner: "{{ xterm_user }}"
    group: "{{ xterm_group }}"
    mode: '0755'
  tags: ['xterm', 'logs']

# ===================================================================
# 9. Configuration firewall (idempotent)
# ===================================================================
- name: Autoriser ports HTTP/HTTPS (SSOT)
  community.general.ufw:
    rule: allow
    port: "{{ item.split('/')[0] }}"
    proto: "{{ item.split('/')[1] }}"
  loop: "{{ firewall_allowed_ports }}"
  when: firewall_enabled
  tags: ['xterm', 'firewall']
```


***

### Fichier 5 : `roles/xterm_console/templates/xterm.service.j2` (Service systemd)

**Chemin** : `Ansible/roles/xterm_console/templates/xterm.service.j2`
**Rôle** : Service systemd pour Wetty
**Versionné** : ✅ Oui

```ini
[Unit]
Description=Wetty Web Terminal (xterm.js)
Documentation=https://github.com/butlerx/wetty
After=network.target

[Service]
Type=simple
User={{ xterm_user }}
Group={{ xterm_group }}
WorkingDirectory={{ xterm_install_dir }}

# Commande de démarrage Wetty
ExecStart=/usr/bin/node {{ xterm_install_dir }}/node_modules/wetty/bin/index.js \
  --host {{ xterm_host }} \
  --port {{ xterm_port }} \
  --ssh-host {{ xterm_ssh_host }} \
  --ssh-port {{ xterm_ssh_port }} \
  --base {{ xterm_base_url }} \
  --title "Console Lab"

# Redémarrage automatique
Restart=on-failure
RestartSec=5s

# Limites ressources
LimitNOFILE=65536
MemoryLimit={{ xterm_pm2_max_memory }}

# Logs
StandardOutput=journal
StandardError=journal
SyslogIdentifier=xterm

# Sécurité
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths={{ xterm_pm2_log_dir }}

[Install]
WantedBy=multi-user.target
```


***

### Fichier 6 : `roles/xterm_console/templates/nginx-xterm.conf.j2` (Reverse proxy)

**Chemin** : `Ansible/roles/xterm_console/templates/nginx-xterm.conf.j2`
**Rôle** : Configuration Nginx pour xterm.js
**Versionné** : ✅ Oui

```nginx
# ===================================================================
# Nginx reverse proxy pour xterm.js (SSOT)
# ===================================================================

# Redirection HTTP → HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name {{ xterm_domain }};

    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}

# Configuration HTTPS
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name {{ xterm_domain }};

    # SSL/TLS Configuration (SSOT)
    ssl_certificate {{ xterm_ssl_certificate }};
    ssl_certificate_key {{ xterm_ssl_certificate_key }};
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

{% if xterm_auth_enabled %}
    # Authentification basique
    auth_basic "Console Restricted";
    auth_basic_user_file /etc/nginx/.htpasswd_xterm;
{% endif %}

    # Logs
    access_log /var/log/nginx/xterm-access.log;
    error_log /var/log/nginx/xterm-error.log;

    # Proxy vers Wetty (WebSocket)
    location {{ xterm_base_url }} {
        proxy_pass http://{{ xterm_host }}:{{ xterm_port }};
        proxy_http_version 1.1;
        
        # Headers WebSocket requis
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Headers proxy standard
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts WebSocket
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        
        # Buffer WebSocket
        proxy_buffering off;
    }

    # Page d'accueil statique (optionnel)
    location / {
        root /var/www/xterm;
        index index.html;
    }
}
```


***

### Fichier 7 : `roles/xterm_console/handlers/main.yml` (Handlers)

**Chemin** : `Ansible/roles/xterm_console/handlers/main.yml`
**Rôle** : Redémarrages services xterm.js
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Handlers : Redémarrages services xterm.js (idempotent)
# ===================================================================

- name: Reload systemd
  ansible.builtin.systemd:
    daemon_reload: true

- name: Restart xterm
  ansible.builtin.systemd:
    name: xterm
    state: restarted

- name: Reload nginx
  ansible.builtin.systemd:
    name: nginx
    state: reloaded
```


***

### Fichier 8 : `playbooks/console.yml` (Playbook déploiement console)

**Chemin** : `Ansible/playbooks/console.yml`
**Rôle** : Playbook déploiement xterm.js
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Playbook : Déploiement console web xterm.js
# ===================================================================

- name: Déploiement console web
  hosts: console_hosts
  gather_facts: true
  become: true
  
  roles:
    - role: xterm_console
      tags: ['console', 'xterm']
  
  post_tasks:
    # ===================================================================
    # Validation post-déploiement
    # ===================================================================
    - name: Attendre disponibilité service xterm
      ansible.builtin.wait_for:
        host: "{{ xterm_host }}"
        port: "{{ xterm_port }}"
        timeout: 30
      tags: ['console', 'validation']
    
    - name: Vérifier service systemd actif
      ansible.builtin.systemd:
        name: xterm
        state: started
      check_mode: true
      register: xterm_service
      tags: ['console', 'validation']
    
    - name: Afficher URL console
      ansible.builtin.debug:
        msg:
          - "=========================================="
          - "Console web xterm.js déployée !"
          - "=========================================="
          - "URL : https://{{ xterm_domain }}{{ xterm_base_url }}"
          - "Authentification : {{ 'Activée' if xterm_auth_enabled else 'Désactivée' }}"
          - "Service : {{ 'Actif' if xterm_service.status.ActiveState == 'active' else 'Inactif' }}"
          - "=========================================="
      tags: ['console', 'validation']
```


***

### Fichier 9 : `scripts/access-console.sh` (Script accès console)

**Chemin** : `scripts/access-console.sh`
**Rôle** : Script pour ouvrir consoles VMs
**Versionné** : ✅ Oui

```bash
#!/usr/bin/env bash
set -euo pipefail

# ===================================================================
# Script d'accès console virtuelle VMs
# ===================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Vérifier arguments
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <vm-name> <console-type>"
    echo ""
    echo "Console types:"
    echo "  spice     - Console SPICE (GUI, client natif requis)"
    echo "  novnc     - Console noVNC (GUI, navigateur web)"
    echo "  xterm     - Console xterm.js (CLI SSH, navigateur web)"
    echo "  ssh       - SSH direct (CLI, terminal natif)"
    echo ""
    echo "Exemples:"
    echo "  $0 tools-manager spice"
    echo "  $0 dns-server xterm"
    exit 1
fi

VM_NAME="$1"
CONSOLE_TYPE="$2"

# Charger IPs depuis Terraform
if [[ ! -f terraform.tfstate ]]; then
    log_error "Fichier terraform.tfstate introuvable"
    log_warn "Exécuter d'abord : terraform apply"
    exit 1
fi

VM_IP=$(terraform output -json vm_ips | jq -r ".${VM_NAME}" 2>/dev/null)
if [[ "${VM_IP}" == "null" || -z "${VM_IP}" ]]; then
    log_error "VM '${VM_NAME}' introuvable dans terraform.tfstate"
    log_warn "VMs disponibles :"
    terraform output -json vm_ips | jq -r 'keys[]' | sed 's/^/  - /'
    exit 1
fi

echo "=========================================="
echo "Accès console VM : ${VM_NAME}"
echo "IP : ${VM_IP}"
echo "Type : ${CONSOLE_TYPE}"
echo "=========================================="
echo ""

case "${CONSOLE_TYPE}" in
    spice)
        log_info "Ouverture console SPICE..."
        log_warn "Télécharger le fichier SPICE depuis Proxmox UI"
        log_warn "VM → Console → Download SPICE file"
        log_warn "Puis ouvrir avec : remote-viewer <fichier>.vv"
        ;;
    
    novnc)
        PROXMOX_URL=$(grep -oP 'proxmox_endpoint\s*=\s*"\K[^"]+' terraform.tfvars)
        VMID=$(terraform show -json | jq -r ".values.root_module.resources[] | select(.values.name == \"${VM_NAME}\") | .values.id" 2>/dev/null)
        
        if [[ -z "${VMID}" ]]; then
            log_error "VMID introuvable pour ${VM_NAME}"
            exit 1
        fi
        
        NOVNC_URL="${PROXMOX_URL}/?console=kvm&novnc=1&vmid=${VMID}&node=pve4"
        log_info "URL console noVNC :"
        echo -e "${BLUE}${NOVNC_URL}${NC}"
        
        # Ouvrir navigateur (Linux)
        if command -v xdg-open &>/dev/null; then
            xdg-open "${NOVNC_URL}" 2>/dev/null || true
        fi
        ;;
    
    xterm)
        XTERM_DOMAIN=$(grep -oP 'xterm_domain:\s*"\K[^"]+' Ansible/group_vars/console_hosts.yml 2>/dev/null || echo "console.lab.local")
        XTERM_URL="https://${XTERM_DOMAIN}/console"
        
        log_info "URL console xterm.js :"
        echo -e "${BLUE}${XTERM_URL}${NC}"
        
        log_warn "Au login, saisir :"
        log_warn "  Host: ${VM_IP}"
        log_warn "  User: ansible"
        log_warn "  Password: (utiliser clé SSH)"
        
        # Ouvrir navigateur
        if command -v xdg-open &>/dev/null; then
            xdg-open "${XTERM_URL}" 2>/dev/null || true
        fi
        ;;
    
    ssh)
        log_info "Connexion SSH directe..."
        SSH_KEY="keys/ansible_ed25519"
        
        if [[ ! -f "${SSH_KEY}" ]]; then
            log_error "Clé SSH introuvable : ${SSH_KEY}"
            exit 1
        fi
        
        log_info "Commande : ssh -i ${SSH_KEY} ansible@${VM_IP}"
        ssh -i "${SSH_KEY}" ansible@"${VM_IP}"
        ;;
    
    *)
        log_error "Type console inconnu : ${CONSOLE_TYPE}"
        log_warn "Types valides : spice, novnc, xterm, ssh"
        exit 1
        ;;
esac
```

**Utilisation** :

```bash
chmod +x scripts/access-console.sh

# Console SPICE (GUI)
./scripts/access-console.sh tools-manager spice

# Console noVNC (GUI web)
./scripts/access-console.sh tools-manager novnc

# Console xterm.js (SSH web)
./scripts/access-console.sh tools-manager xterm

# SSH direct
./scripts/access-console.sh tools-manager ssh
```


***

## 📊 Tableau récapitulatif des fichiers Console

| Fichier | Chemin | Rôle SSOT | Versionné |
| :-- | :-- | :-- | :-- |
| `user-data.yaml.tftpl` | `cloud-init/` | Packages SPICE (cloud-init) | ✅ Oui |
| `main.tf` | Racine | Configuration GPU QXL | ✅ Oui |
| `group_vars/console_hosts.yml` | `Ansible/group_vars/` | Config xterm.js SSOT | ✅ Oui |
| `roles/xterm_console/tasks/main.yml` | `Ansible/roles/xterm_console/` | Déploiement xterm.js | ✅ Oui |
| `roles/xterm_console/templates/xterm.service.j2` | `Ansible/roles/xterm_console/templates/` | Service systemd Wetty | ✅ Oui |
| `roles/xterm_console/templates/nginx-xterm.conf.j2` | `Ansible/roles/xterm_console/templates/` | Reverse proxy Nginx | ✅ Oui |
| `playbooks/console.yml` | `Ansible/playbooks/` | Playbook déploiement console | ✅ Oui |
| `scripts/access-console.sh` | `scripts/` | Script accès consoles | ✅ Oui |


***

## 🎯 Workflow DevOps Console Virtuelle

### Déploiement initial

```bash
# 1. Ajout tag 'console' aux VMs dans terraform.tfvars
nodes = {
  tools-manager = {
    # ...
    tags = ["tools", "console"]  # ← Ajout tag
  }
}

# 2. Application Terraform (GPU QXL + SPICE)
terraform apply

# 3. Déploiement xterm.js via Ansible
cd Ansible/
ansible-playbook playbooks/console.yml --tags console

# 4. Test accès consoles
../scripts/access-console.sh tools-manager xterm
../scripts/access-console.sh tools-manager ssh
```


### Utilisation quotidienne

```bash
# Accès rapide SSH web (sans client)
./scripts/access-console.sh <vm-name> xterm

# Accès GUI SPICE (haute performance)
./scripts/access-console.sh <vm-name> spice

# Accès noVNC (navigateur, pas d'install)
./scripts/access-console.sh <vm-name> novnc
```


***

## 🔐 Sécurisation Console Web

### Configuration authentification basique

```bash
# Générer mot de passe chiffré
htpasswd -c /etc/nginx/.htpasswd_xterm admin

# Ansible Vault pour sécuriser password
ansible-vault encrypt_string 'motdepasse_admin' --name 'vault_xterm_admin_password'
```


### Amélioration sécurité (best practices)

```yaml
# group_vars/console_hosts.yml
xterm_auth_enabled: true

# Ajout TOTP (optionnel)
xterm_2fa_enabled: true
xterm_2fa_provider: google-authenticator

# Limitation IPs autorisées
xterm_allowed_ips:
  - 192.168.1.0/24
  - 10.0.0.0/8

# Rate limiting Nginx
xterm_rate_limit: "10r/m"
```


***


