# 🔄 SSOT Complet - Déploiement GitLab CE sur Infrastructure Existante

## 📊 État Infrastructure Actuel (SSOT)

### Inventaire VMs Déployées

| Nom VM | IP | Groupe Ansible | Services Actifs | Statut |
| :-- | :-- | :-- | :-- | :-- |
| bind9dns | 172.16.100.254 | bind9_hosts | BIND9 DNS | ✅ Opérationnel |
| reverse-proxy | 172.16.100.253 | reverse_proxy_hosts | Nginx RP + TLS | ✅ Opérationnel |
| tools-manager | 172.16.100.20 | tools_hosts | Taiga + EdgeDoc | ✅ Opérationnel |
| harbor | 172.16.100.50 | harbor_portainer_hosts | Harbor + Portainer | ✅ Opérationnel |
| **git-lab** | **172.16.100.40** | **gitlab_hosts** | **À déployer** | 🔄 VM active |
| monitoring-stack | 172.16.100.60 | monitoring_hosts | Prometheus + Grafana | ✅ Opérationnel |
| k3s-manager | 172.16.100.250 | k3s_manager_hosts | Kubernetes master | ✅ Opérationnel |
| k3s-worker-0 | 172.16.100.251 | k3s_worker_hosts | Kubernetes node | ✅ Opérationnel |
| k3s-worker-1 | 172.16.100.252 | k3s_worker_hosts | Kubernetes node | ✅ Opérationnel |

### Rôles Ansible Existants

```
Ansible/roles/
├── bind9_docker/          # DNS autoritaire (*.lab.local)
├── edgedoc/               # Documentation collaborative
├── harbor/                # Registry Docker privé
├── monitoring/            # Prometheus + Grafana + Alertmanager
├── nginx_reverse_proxy/   # Reverse-proxy HTTPS + terminaison TLS
├── node_exporter/         # Métriques système (toutes VMs)
├── pki_ca/                # CA interne + génération certificats TLS
├── portainer/             # UI gestion Docker
├── systemli.bind9/        # Rôle externe BIND9
└── taiga/                 # Gestion projet Kanban/Scrum
```


***

## 🎯 Mission : Déployer GitLab CE sur git-lab (172.16.100.40)

### Architecture Cible GitLab

```
┌─────────────────────────────────────────────────────────────┐
│ VM : git-lab (172.16.100.40)                                │
│  ├─ GitLab Rails (Web UI + API)                            │
│  ├─ Gitaly (stockage Git repositories)                     │
│  ├─ PostgreSQL (métadonnées projets/users)                 │
│  ├─ Redis (cache + queues Sidekiq)                         │
│  ├─ Sidekiq (jobs asynchrones : mails, webhooks)           │
│  ├─ GitLab Runner (exécution pipelines CI/CD)              │
│  ├─ Container Registry (images Docker internes)            │
│  └─ Nginx interne (reverse-proxy HTTP backend)             │
│                                                             │
│  Workflow DevOps Complet :                                 │
│  1. Dev → git push code → GitLab                           │
│  2. GitLab → Trigger pipeline CI/CD (.gitlab-ci.yml)      │
│  3. Runner → Build image Docker                            │
│  4. Runner → Scan Trivy (sécurité CVE/secrets)            │
│  5. Runner → Push image vers Harbor (172.16.100.50)       │
│  6. Runner → Deploy Kubernetes (172.16.100.250-252)       │
│  7. Prometheus → Monitoring pipeline (durée, succès/échec) │
│  8. GitLab → Notifications (Slack, Email)                  │
│                                                             │
│  Intégrations :                                            │
│  ├─> Harbor (172.16.100.50) : Registry externe            │
│  ├─> K3s (172.16.100.250) : Déploiement conteneurs        │
│  ├─> Prometheus (172.16.100.60) : Monitoring              │
│  ├─> Slack/Email : Notifications                           │
│  └─> LDAP/SAML : Authentification (optionnel)             │
└─────────────────────────────────────────────────────────────┘
```


### Flux Réseau Externe (via Nginx RP)

```
Dev Station
    ↓ git push ssh://git@gitlab.lab.local:22
    ↓ HTTPS https://gitlab.lab.local
    ↓
Nginx RP (172.16.100.253:443) [TLS termination]
    ↓ HTTP backend
    ↓
GitLab (172.16.100.40:80) [Nginx interne]
    ↓ Runner pipeline
    ↓
Harbor (172.16.100.50) [Push images]
K3s (172.16.100.250) [Deploy apps]
Prometheus (172.16.100.60) [Scrape métriques]
```


***

## 🛠️ Workflow SSOT - Étapes Détaillées

### ÉTAPE 0 : Prérequis (Déjà Complété ✅)

**VM git-lab déjà provisionnée** :

- IP : 172.16.100.40
- OS : Ubuntu 22.04 LTS (cloud-init)
- User : ansible (clé SSH ED25519)
- Docker : À installer via rôle
- État : VM active, SSH accessible

**Vérification connectivité** :

```bash
cd Ansible
ansible gitlab_hosts -m ping
```

**Résultat attendu** :

```
git-lab | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```


***

### ÉTAPE 1 : Créer Structure Rôle GitLab

**Commande** :

```bash
cd Ansible/roles
ansible-galaxy role init gitlab
```

**Arborescence générée** :

```
Ansible/roles/gitlab/
├── README.md
├── defaults/
│   └── main.yml              # Variables par défaut
├── files/                    # Fichiers statiques
├── handlers/
│   └── main.yml              # Redémarrage services
├── meta/
│   └── main.yml              # Dépendances rôles
├── tasks/
│   └── main.yml              # Orchestration workflow
├── templates/                # Configs Jinja2
├── tests/
│   ├── inventory
│   └── test.yml
└── vars/
    └── main.yml              # Variables fixes
```

**Résultat** :

```
- Role gitlab was created successfully
```


***

### ÉTAPE 2 : Définir Variables SSOT

**Fichier** : `Ansible/roles/gitlab/defaults/main.yml`

**Contenu** :

```yaml
---
# Version GitLab CE (source officielle Docker Hub)
gitlab_version: "17.7.0-ce.0"
gitlab_runner_version: "alpine-v17.7.0"

# Configuration réseau
gitlab_hostname: "gitlab.lab.local"
gitlab_ip: "172.16.100.40"
gitlab_external_url: "https://{{ gitlab_hostname }}"
gitlab_registry_external_url: "https://registry.{{ gitlab_hostname }}"

# Ports exposition
gitlab_http_port: 80          # Backend HTTP (via Nginx RP)
gitlab_https_port: 443        # Terminaison TLS sur Nginx RP (253)
gitlab_ssh_port: 22           # Git SSH direct
gitlab_registry_port: 5050    # Container Registry interne

# Intégrations
harbor_url: "https://harbor.lab.local"
harbor_project: "gitlab-builds"
k3s_api_url: "https://172.16.100.250:6443"
prometheus_url: "http://172.16.100.60:9090"

# Secrets (Ansible Vault)
gitlab_root_password: "{{ vault_gitlab_root_password }}"
gitlab_runner_token: "{{ vault_gitlab_runner_token }}"
harbor_username: "{{ vault_harbor_username }}"
harbor_password: "{{ vault_harbor_password }}"

# Chemins persistance
gitlab_data_dir: "/srv/gitlab/data"
gitlab_config_dir: "/srv/gitlab/config"
gitlab_logs_dir: "/srv/gitlab/logs"
gitlab_runner_config_dir: "/srv/gitlab-runner/config"

# PostgreSQL
gitlab_postgres_user: "gitlab"
gitlab_postgres_db: "gitlabhq_production"

# Redis
gitlab_redis_maxmemory: "256mb"

# Runner configuration
gitlab_runner_executor: "docker"
gitlab_runner_docker_image: "docker:27-dind"
gitlab_runner_concurrent: 4
gitlab_runner_cache_dir: "/srv/gitlab-runner/cache"

# Monitoring
gitlab_prometheus_enabled: true
gitlab_node_exporter_enabled: true

# LDAP (optionnel)
gitlab_ldap_enabled: false
```


***

### ÉTAPE 3 : Créer Templates Configuration

**Fichier 1** : `Ansible/roles/gitlab/templates/docker-compose.yml.j2`

**Contenu** :

```yaml
---
version: '3.8'

services:
  gitlab:
    image: gitlab/gitlab-ce:{{ gitlab_version }}
    container_name: gitlab
    hostname: {{ gitlab_hostname }}
    restart: unless-stopped
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url '{{ gitlab_external_url }}'
        nginx['listen_port'] = {{ gitlab_http_port }}
        nginx['listen_https'] = false
        gitlab_rails['registry_enabled'] = true
        registry_external_url '{{ gitlab_registry_external_url }}'
        gitlab_rails['initial_root_password'] = '{{ gitlab_root_password }}'
        postgresql['shared_buffers'] = "256MB"
        redis['maxmemory'] = '{{ gitlab_redis_maxmemory }}'
        prometheus['enable'] = {{ gitlab_prometheus_enabled | lower }}
        prometheus['listen_address'] = '0.0.0.0:9090'
        node_exporter['enable'] = {{ gitlab_node_exporter_enabled | lower }}
    ports:
      - "{{ gitlab_http_port }}:80"
      - "{{ gitlab_ssh_port }}:22"
      - "{{ gitlab_registry_port }}:5050"
      - "9090:9090"  # Prometheus metrics
    volumes:
      - {{ gitlab_config_dir }}:/etc/gitlab
      - {{ gitlab_logs_dir }}:/var/log/gitlab
      - {{ gitlab_data_dir }}:/var/opt/gitlab
    shm_size: '256m'
    networks:
      - gitlab-network

  gitlab-runner:
    image: gitlab/gitlab-runner:{{ gitlab_runner_version }}
    container_name: gitlab-runner
    restart: unless-stopped
    volumes:
      - {{ gitlab_runner_config_dir }}:/etc/gitlab-runner
      - /var/run/docker.sock:/var/run/docker.sock
      - {{ gitlab_runner_cache_dir }}:/cache
    depends_on:
      - gitlab
    networks:
      - gitlab-network

networks:
  gitlab-network:
    driver: bridge
```

**Fichier 2** : `Ansible/roles/gitlab/templates/runner-config.toml.j2`

**Contenu** :

```toml
concurrent = {{ gitlab_runner_concurrent }}
check_interval = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "docker-runner-{{ gitlab_hostname }}"
  url = "{{ gitlab_external_url }}"
  token = "{{ gitlab_runner_token }}"
  executor = "{{ gitlab_runner_executor }}"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.docker]
    tls_verify = false
    image = "{{ gitlab_runner_docker_image }}"
    privileged = true
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]
    shm_size = 0
    network_mtu = 0
```


***

### ÉTAPE 4 : Créer Tasks Ansible

**Fichier** : `Ansible/roles/gitlab/tasks/main.yml`

**Contenu** :

```yaml
---
- name: Preconditions for GitLab deployment
  ansible.builtin.import_tasks: prerequisites.yml

- name: Install GitLab dependencies
  ansible.builtin.import_tasks: install.yml

- name: Configure GitLab files
  ansible.builtin.import_tasks: configure.yml

- name: Deploy GitLab stack
  ansible.builtin.import_tasks: deploy.yml

- name: Apply GitLab security hardening
  ansible.builtin.import_tasks: security.yml

- name: Validate GitLab deployment
  ansible.builtin.import_tasks: validation.yml
```

**Fichier** : `Ansible/roles/gitlab/tasks/prerequisites.yml`

**Contenu** :

```yaml
---
- name: Ensure Docker is installed
  ansible.builtin.package:
    name:
      - docker.io
      - docker-compose-v2
    state: present
  become: true

- name: Create GitLab directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: root
    group: root
    mode: '0755'
  loop:
    - "{{ gitlab_data_dir }}"
    - "{{ gitlab_config_dir }}"
    - "{{ gitlab_logs_dir }}"
    - "{{ gitlab_runner_config_dir }}"
    - "{{ gitlab_runner_cache_dir }}"
  become: true

- name: Check if GitLab is already running
  ansible.builtin.command: docker ps -q -f name=gitlab
  register: gitlab_running
  changed_when: false
  failed_when: false
```

**Fichier** : `Ansible/roles/gitlab/tasks/configure.yml`

**Contenu** :

```yaml
---
- name: Deploy GitLab docker-compose.yml
  ansible.builtin.template:
    src: docker-compose.yml.j2
    dest: /srv/gitlab/docker-compose.yml
    owner: root
    group: root
    mode: '0644'
  become: true
  notify: restart gitlab

- name: Deploy GitLab Runner config
  ansible.builtin.template:
    src: runner-config.toml.j2
    dest: "{{ gitlab_runner_config_dir }}/config.toml"
    owner: root
    group: root
    mode: '0600'
  become: true
  notify: restart gitlab-runner
```

**Fichier** : `Ansible/roles/gitlab/tasks/deploy.yml`

**Contenu** :

```yaml
---
- name: Start GitLab stack
  ansible.builtin.command:
    cmd: docker compose up -d
    chdir: /srv/gitlab
  become: true
  register: gitlab_deploy
  changed_when: "'Started' in gitlab_deploy.stdout or 'Created' in gitlab_deploy.stdout"

- name: Wait for GitLab to be ready
  ansible.builtin.uri:
    url: "http://{{ gitlab_ip }}/-/health"
    status_code: 200
    timeout: 300
  register: gitlab_health
  until: gitlab_health.status == 200
  retries: 30
  delay: 10
```

**Fichier** : `Ansible/roles/gitlab/tasks/security.yml`

**Contenu** :

```yaml
---
- name: Configure UFW for GitLab
  community.general.ufw:
    rule: allow
    port: "{{ item }}"
    proto: tcp
    comment: "GitLab {{ item }}"
  loop:
    - "{{ gitlab_http_port }}"
    - "{{ gitlab_ssh_port }}"
    - "{{ gitlab_registry_port }}"
    - "9090"  # Prometheus metrics
  become: true

- name: Allow Nginx RP to access GitLab
  community.general.ufw:
    rule: allow
    from_ip: 172.16.100.253
    to_port: "{{ gitlab_http_port }}"
    proto: tcp
    comment: "Nginx RP to GitLab"
  become: true
```

**Fichier** : `Ansible/roles/gitlab/tasks/validation.yml`

**Contenu** :

```yaml
---
- name: Check GitLab container status
  ansible.builtin.command: docker ps -f name=gitlab --format '{% raw %}{{.Status}}{% endraw %}'
  register: gitlab_status
  changed_when: false
  failed_when: "'Up' not in gitlab_status.stdout"
  become: true

- name: Test GitLab HTTP endpoint
  ansible.builtin.uri:
    url: "http://{{ gitlab_ip }}/-/health"
    return_content: true
  register: gitlab_http_test
  failed_when: gitlab_http_test.status != 200

- name: Display GitLab root password
  ansible.builtin.debug:
    msg: "GitLab root password: {{ gitlab_root_password }}"
  when: gitlab_deploy.changed
```

**Fichier** : `Ansible/roles/gitlab/handlers/main.yml`

**Contenu** :

```yaml
---
- name: restart gitlab
  ansible.builtin.command:
    cmd: docker compose restart gitlab
    chdir: /srv/gitlab
  become: true

- name: restart gitlab-runner
  ansible.builtin.command:
    cmd: docker compose restart gitlab-runner
    chdir: /srv/gitlab
  become: true
```


***

### ÉTAPE 5 : Créer Playbook Orchestration

**Fichier** : `Ansible/playbooks/gitlab.yml`

**Contenu** :

```yaml
---
- name: Deploy GitLab CE on git-lab VM
  hosts: gitlab_hosts
  become: true
  roles:
    - role: gitlab
      tags: ['gitlab', 'deploy']

- name: Configure Nginx reverse-proxy for GitLab
  hosts: reverse_proxy_hosts
  become: true
  vars:
    nginx_gitlab_backend: "172.16.100.40"
  roles:
    - role: nginx_reverse_proxy
      tags: ['nginx', 'reverse-proxy']

- name: Update BIND9 DNS for GitLab
  hosts: bind9_hosts
  become: true
  vars:
    bind9_gitlab_ip: "172.16.100.253"  # Pointe vers Nginx RP
  roles:
    - role: bind9_docker
      tags: ['dns', 'bind9']
```


***

### ÉTAPE 6 : Intégrer Nginx Reverse-Proxy

**Fichier** : `Ansible/roles/nginx_reverse_proxy/defaults/main.yml`

**Ajouter** :

```yaml
nginx_backends:
  # ... autres backends existants ...
  - name: gitlab
    domain: gitlab.lab.local
    backend_ip: 172.16.100.40
    backend_port: 80
    ssl_cert: /etc/ssl/certs/gitlab.lab.local.crt
    ssl_key: /etc/ssl/private/gitlab.lab.local.key
    extra_config: |
      proxy_request_buffering off;
      client_max_body_size 2G;
      proxy_read_timeout 300;
      proxy_connect_timeout 300;
      proxy_send_timeout 300;
```

**Fichier** : `Ansible/roles/nginx_reverse_proxy/templates/gitlab.conf.j2`

**Créer** :

```nginx
upstream gitlab_backend {
    server {{ backend_ip }}:{{ backend_port }} max_fails=3 fail_timeout=30s;
}

server {
    listen 443 ssl http2;
    server_name {{ domain }};

    ssl_certificate {{ ssl_cert }};
    ssl_certificate_key {{ ssl_key }};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    access_log /var/log/nginx/gitlab_access.log;
    error_log /var/log/nginx/gitlab_error.log;

    location / {
        proxy_pass http://gitlab_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Ssl on;
        
        {{ extra_config | indent(8) }}
    }
}
```


***

### ÉTAPE 7 : Mettre à Jour BIND9 DNS

**Fichier** : `Ansible/roles/bind9_docker/defaults/main.yml`

**Ajouter** :

```yaml
bind9_zone_records:
  # ... enregistrements existants ...
  - name: gitlab
    type: A
    value: 172.16.100.253  # Pointe vers Nginx RP
    ttl: 300
  - name: registry.gitlab
    type: CNAME
    value: gitlab.lab.local.
    ttl: 300
```


***

### ÉTAPE 8 : Créer Secrets Ansible Vault

**Fichier** : `Ansible/secrets/gitlab.yml` (chiffré)

**Commande** :

```bash
cd Ansible
ansible-vault create secrets/gitlab.yml
```

**Contenu** :

```yaml
---
vault_gitlab_root_password: "MotDePasse_Securise_123!"
vault_gitlab_runner_token: "glrt-xxxxxxxxxxxxxxxxxxxx"
vault_harbor_username: "gitlab"
vault_harbor_password: "Harbor_Password_456!"
```

**Référencer dans inventaire** :

```yaml
# Ansible/inventory/group_vars/gitlab_hosts.yml
---
# Charger secrets
vault_file: "{{ playbook_dir }}/../secrets/gitlab.yml"
```


***

### ÉTAPE 9 : Exécuter Déploiement

**Commandes séquencées** :

```bash
cd Ansible

# 1. Générer certificat TLS pour gitlab.lab.local
ansible-playbook playbooks/pki_ca.yml \
  --extra-vars "cert_common_name=gitlab.lab.local" \
  --ask-vault-pass

# 2. Déployer GitLab
ansible-playbook playbooks/gitlab.yml \
  --tags gitlab \
  --check  # Dry-run
ansible-playbook playbooks/gitlab.yml \
  --tags gitlab \
  --ask-vault-pass  # Déploiement réel

# 3. Configurer Nginx RP
ansible-playbook playbooks/nginx_reverse_proxy.yml \
  --ask-vault-pass

# 4. Mettre à jour DNS
ansible-playbook playbooks/bind9-docker.yml

# 5. Valider déploiement
./validate.sh gitlab
```


***

### ÉTAPE 10 : Validation Post-Déploiement

**Tests manuels** :

```bash
# Test résolution DNS
dig @172.16.100.254 gitlab.lab.local +short
# Résultat attendu : 172.16.100.253

# Test HTTPS via Nginx RP
curl -kv https://gitlab.lab.local/-/health
# Résultat attendu : HTTP/2 200

# Test SSH Git
ssh -T git@gitlab.lab.local
# Résultat attendu : "Welcome to GitLab, @root!"

# Test Container Registry
docker login registry.gitlab.lab.local
# Résultat attendu : Login Succeeded
```

**Script validation automatique** :

```bash
# Ansible/validate.sh gitlab
./validate.sh gitlab
```


***

## 📁 Arborescence Finale du Projet

```
Projet_infra_devops/
├── main.tf
├── variables.tf
├── ansible_inventory.tf
└── Ansible/
    ├── inventory/
    │   ├── hosts.yml              # git-lab: 172.16.100.40
    │   └── group_vars/
    │       └── gitlab_hosts.yml   # Variables groupe GitLab
    ├── playbooks/
    │   ├── gitlab.yml             # 🆕 Orchestration GitLab
    │   ├── nginx_reverse_proxy.yml
    │   ├── bind9-docker.yml
    │   └── pki_ca.yml
    ├── roles/
    │   ├── gitlab/                # 🆕 Rôle GitLab CE
    │   │   ├── defaults/main.yml
    │   │   ├── tasks/
    │   │   │   ├── main.yml
    │   │   │   ├── prerequisites.yml
    │   │   │   ├── configure.yml
    │   │   │   ├── deploy.yml
    │   │   │   ├── security.yml
    │   │   │   └── validation.yml
    │   │   ├── templates/
    │   │   │   ├── docker-compose.yml.j2
    │   │   │   └── runner-config.toml.j2
    │   │   └── handlers/main.yml
    │   ├── nginx_reverse_proxy/
    │   │   ├── defaults/main.yml  # Ajout backend GitLab
    │   │   └── templates/
    │   │       └── gitlab.conf.j2 # 🆕 Config Nginx GitLab
    │   └── bind9_docker/
    │       └── defaults/main.yml  # Ajout enregistrement DNS
    ├── secrets/
    │   └── gitlab.yml             # 🆕 Secrets Vault (chiffré)
    └── validate.sh                # Script validation

```


***

## ✅ Checklist SSOT Finale

- [x] VM git-lab (172.16.100.40) active et accessible SSH
- [x] Rôle Ansible `gitlab` créé avec arborescence complète
- [x] Variables SSOT dans `defaults/main.yml` (versions, IPs, intégrations)
- [x] Templates Docker Compose + Runner configurés
- [x] Tasks Ansible idempotentes (prerequisites → validation)
- [x] Playbook `gitlab.yml` orchestrant déploiement + Nginx + DNS
- [x] Intégration Nginx RP (terminaison TLS, proxy HTTP backend)
- [x] Intégration BIND9 (enregistrement A `gitlab.lab.local`)
- [x] Secrets Ansible Vault pour credentials sensibles
- [x] Script validation automatique `validate.sh gitlab`
- [x] Documentation flux DevOps (Git → CI/CD → Harbor → K3s)

***

## 🚀 Commande de Lancement Globale

```bash
cd Ansible

# Lancement complet (une seule commande)
ansible-playbook playbooks/gitlab.yml --ask-vault-pass

# Ou étape par étape
ansible-playbook playbooks/pki_ca.yml --extra-vars "cert_common_name=gitlab.lab.local" --ask-vault-pass
ansible-playbook playbooks/gitlab.yml --tags gitlab --ask-vault-pass
ansible-playbook playbooks/nginx_reverse_proxy.yml --ask-vault-pass
ansible-playbook playbooks/bind9-docker.yml
./validate.sh gitlab
```

**Temps déploiement estimé** : 10-15 minutes (dont 5 min initialisation GitLab).
<span style="display:none">[^1]</span>

<div align="center">⁂</div>

[^1]: https-github-com-katachiyari-p-bz7svhA9SI2Zm9XDbnnP5Q.md

