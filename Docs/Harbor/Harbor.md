# 🐳 Harbor : Registry Docker Privé


***

## 📍 Explication : Registry Docker et Harbor

### Définition

**Harbor** est un registry Docker open-source de niveau entreprise développé par VMware. Il permet de stocker, signer et scanner des images Docker en privé, avec gestion fine des permissions, réplication multi-sites et interface web complète.

### Comparaison des solutions Registry Docker

| Solution | Interface Web | Scan Vulnérabilités | RBAC | Réplication | Signature Images | Complexité |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| **Harbor** | ✅ Complète | ✅ Trivy intégré | ✅ Avancé | ✅ Oui | ✅ Notary | Moyenne |
| **Docker Registry** | ❌ Non | ❌ Non | ❌ Basic | ❌ Non | ❌ Non | Faible |
| **Nexus Repository** | ✅ Oui | ✅ Oui | ✅ Oui | ⚠️ Payant | ⚠️ Payant | Élevée |
| **GitLab Container Registry** | ✅ Oui | ✅ Oui | ✅ Oui | ❌ Non | ❌ Non | Moyenne |
| **Quay.io** | ✅ Oui | ✅ Clair | ✅ Oui | ✅ Oui | ✅ Oui | Élevée |
| **JFrog Artifactory** | ✅ Oui | ✅ Xray | ✅ Oui | ✅ Oui | ✅ Oui | Très élevée |

### Rôle dans l'architecture DevSecOps

```
┌─────────────────────────────────────────────────────────────┐
│ Architecture Registry Harbor                                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  VM : harbor (172.16.100.50)                               │
│  ├─ Harbor Core (HTTP/HTTPS)                               │
│  ├─ Docker Registry v2 (stockage images)                   │
│  ├─ PostgreSQL (métadonnées)                               │
│  ├─ Redis (cache/sessions)                                 │
│  ├─ Trivy (scan vulnérabilités)                            │
│  └─ Nginx (reverse proxy)                                  │
│                                                             │
│  Workflow DevSecOps :                                      │
│  1. Dev push image → harbor.lab.local/myapp:v1.0          │
│  2. Harbor scan vulnérabilités (Trivy)                     │
│  3. Si vulnérabilités → Alerte admin                       │
│  4. GitLab CI pull image depuis Harbor                     │
│  5. Déploiement production                                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```


***

## 📍 Cycle de vie : Harbor

### Phase 1 : Provisionnement VM (Terraform)

```
1. Création VM harbor
   └─> Terraform provisionne VM
       ├─> Hostname : harbor
       ├─> IP statique : 172.16.100.50
       ├─> CPU : 4 cores (recommandé pour scan images)
       ├─> RAM : 8 GB (PostgreSQL + Redis + Trivy)
       └─> Disk : 100 GB (stockage images Docker)

2. Cloud-init configure réseau
   └─> IP : 172.16.100.50/24
   └─> Gateway : 172.16.100.1
   └─> DNS : 172.16.100.254 (dns-server)

3. VM disponible
   └─> Accessible via SSH
   └─> Docker pré-installé (rôle common)
```


### Phase 2 : Installation Harbor (Ansible)

```
1. Téléchargement Harbor offline installer
   └─> wget https://github.com/goharbor/harbor/releases/download/v2.10.0/harbor-offline-installer-v2.10.0.tgz
   └─> Extraction dans /opt/harbor

2. Configuration harbor.yml
   └─> /opt/harbor/harbor.yml (généré depuis template Ansible)
       ├─> Hostname : harbor.lab.local
       ├─> HTTP port : 80
       ├─> HTTPS : auto-signé ou Let's Encrypt
       ├─> Admin password : (Ansible Vault)
       ├─> Database : PostgreSQL interne
       ├─> Redis : interne
       ├─> Trivy : activé (scan vulnérabilités)
       └─> Storage : filesystem /data/harbor

3. Génération certificats SSL
   └─> Option A : Auto-signé (lab)
       └─> openssl req -newkey rsa:4096 -nodes -sha256 -keyout harbor.key -x509 -days 365 -out harbor.crt
   └─> Option B : Let's Encrypt (production)
       └─> certbot certonly --standalone -d harbor.lab.local

4. Exécution install script
   └─> ./install.sh --with-trivy --with-chartmuseum
       ├─> Préparation environnement
       ├─> Génération docker-compose.yml
       ├─> Pull images Docker Harbor
       ├─> Démarrage stack (docker-compose up -d)
       └─> Initialisation database PostgreSQL

5. Stack Harbor démarrée
   └─> 9 containers Docker actifs :
       ├─> harbor-core (API Harbor)
       ├─> harbor-portal (UI web)
       ├─> harbor-jobservice (tâches async)
       ├─> registry (Docker Registry v2)
       ├─> registryctl (contrôle registry)
       ├─> postgresql (base données)
       ├─> redis (cache)
       ├─> trivy-adapter (scan vulnérabilités)
       └─> nginx (reverse proxy HTTPS)
```


### Phase 3 : Configuration Initiale (Web UI)

```
1. Connexion Web UI
   └─> https://harbor.lab.local
   └─> Login : admin / {{ vault_harbor_admin_password }}

2. Création projet "library" (public par défaut)
   └─> Projects → New Project
       ├─> Name : library
       ├─> Access Level : Public (pull anonyme autorisé)
       └─> Storage Quota : -1 (illimité)

3. Création projet privé "prod"
   └─> Projects → New Project
       ├─> Name : prod
       ├─> Access Level : Private
       └─> Members : user@lab.local (Developer)

4. Configuration Trivy (scan vulnérabilités)
   └─> Administration → Interrogation Services
       ├─> Vulnerability Scanners → Trivy
       ├─> Set as Default
       └─> Auto-scan on push : ✅ Enabled

5. Configuration Garbage Collection
   └─> Administration → Garbage Collection
       ├─> Schedule : Daily 2:00 AM
       └─> Delete untagged manifests : ✅ Enabled

6. Création utilisateur robot (CI/CD)
   └─> Projects → prod → Robot Accounts → New Robot Account
       ├─> Name : gitlab-ci
       ├─> Expiration : Never
       ├─> Permissions : Push/Pull artifacts
       └─> Token généré : robot$gitlab-ci+xxxxx
```


### Phase 4 : Configuration Clients Docker

```
1. Configuration Docker daemon (toutes VMs)
   └─> /etc/docker/daemon.json
       └─> Ajout registry insecure (si auto-signé) :
           {
             "insecure-registries": ["harbor.lab.local"]
           }
   └─> systemctl restart docker

2. Login Docker vers Harbor
   └─> docker login harbor.lab.local
       ├─> Username : admin
       ├─> Password : {{ vault_harbor_admin_password }}
       └─> Login Succeeded

3. Test push image
   └─> docker pull nginx:alpine
   └─> docker tag nginx:alpine harbor.lab.local/library/nginx:alpine
   └─> docker push harbor.lab.local/library/nginx:alpine
       ├─> Push réussi
       └─> Trivy scan automatique lancé

4. Vérification scan Trivy
   └─> Harbor UI → Projects → library → Repositories → nginx → Artifacts
       └─> Scan résultat :
           ├─> Critical : 0
           ├─> High : 2
           ├─> Medium : 15
           └─> Low : 30
```


### Phase 5 : Intégration GitLab CI

```
1. Configuration GitLab CI variables
   └─> GitLab → Settings → CI/CD → Variables
       ├─> HARBOR_REGISTRY : harbor.lab.local
       ├─> HARBOR_USER : robot$gitlab-ci
       └─> HARBOR_PASSWORD : (token robot) [masked]

2. .gitlab-ci.yml (exemple build & push)
   └─> stages:
         - build
         - deploy
       
       build:
         stage: build
         script:
           - docker login -u $HARBOR_USER -p $HARBOR_PASSWORD $HARBOR_REGISTRY
           - docker build -t $HARBOR_REGISTRY/prod/myapp:$CI_COMMIT_TAG .
           - docker push $HARBOR_REGISTRY/prod/myapp:$CI_COMMIT_TAG

3. Pipeline exécuté
   └─> Image buildée et pushée dans Harbor
   └─> Trivy scan automatique
   └─> Résultat scan visible dans Harbor UI
```


***

## 📍 Architecture Harbor Détaillée

### Diagramme de flux Push Image

```
┌─────────────────────────────────────────────────────────────┐
│ Developer (poste local)                                     │
├─────────────────────────────────────────────────────────────┤
│ • docker build -t myapp:v1.0 .                             │
│ • docker tag myapp:v1.0 harbor.lab.local/prod/myapp:v1.0  │
│ • docker push harbor.lab.local/prod/myapp:v1.0            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ HTTPS (443)
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ harbor (172.16.100.50)                                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Nginx (reverse proxy)                                  │
│     └─> Terminaison SSL                                     │
│     └─> Redirection vers harbor-core                       │
│                                                             │
│  2. Harbor Core (API)                                      │
│     └─> Authentification (admin/robot)                     │
│     └─> Vérification RBAC (user a-t-il droit push ?)      │
│     └─> Si OK → Transfert vers registry                    │
│                                                             │
│  3. Docker Registry v2                                     │
│     └─> Stockage blobs image dans /data/harbor/registry   │
│     └─> Enregistrement manifest                            │
│                                                             │
│  4. PostgreSQL                                             │
│     └─> Insertion métadonnées image :                      │
│         ├─> Projet : prod                                  │
│         ├─> Repository : myapp                              │
│         ├─> Tag : v1.0                                      │
│         ├─> Digest : sha256:abcdef...                       │
│         ├─> Size : 150 MB                                   │
│         └─> Push time : 2026-01-17 18:30:00                │
│                                                             │
│  5. Harbor Jobservice (tâche asynchrone)                   │
│     └─> Job créé : Scan image avec Trivy                   │
│                                                             │
│  6. Trivy Adapter                                          │
│     └─> Pull image depuis registry local                   │
│     └─> Scan vulnérabilités CVE                            │
│     └─> Résultat :                                         │
│         ├─> Critical : 1 (CVE-2024-1234)                   │
│         ├─> High : 5                                        │
│         └─> Medium : 20                                     │
│                                                             │
│  7. PostgreSQL (sauvegarde résultat scan)                  │
│     └─> Mise à jour métadonnées image                      │
│                                                             │
│  8. Webhook (optionnel)                                    │
│     └─> POST https://slack.com/webhook                     │
│         └─> Notification : "Image myapp:v1.0 pushed"       │
│                                                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Réponse HTTP 201 Created
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Developer                                                   │
├─────────────────────────────────────────────────────────────┤
│ • Push réussi                                              │
│ • Digest : sha256:abcdef...                                │
│ • Accès Web UI pour voir scan résultat                     │
└─────────────────────────────────────────────────────────────┘
```


### Diagramme de flux Pull Image

```
┌─────────────────────────────────────────────────────────────┐
│ GitLab CI Runner                                            │
├─────────────────────────────────────────────────────────────┤
│ • docker pull harbor.lab.local/prod/myapp:v1.0            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ HTTPS (443)
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ harbor (172.16.100.50)                                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Nginx → Harbor Core                                    │
│     └─> Authentification (token robot GitLab CI)           │
│     └─> Vérification RBAC (robot a-t-il droit pull ?)     │
│                                                             │
│  2. Harbor Core                                            │
│     └─> Query PostgreSQL : manifest image existe ?         │
│     └─> Si projet "Private" : vérifier membre              │
│     └─> Si OK → Autorisation pull                          │
│                                                             │
│  3. Docker Registry v2                                     │
│     └─> Lecture blobs depuis /data/harbor/registry         │
│     └─> Streaming layers vers client                       │
│                                                             │
│  4. Redis (cache)                                          │
│     └─> Cache manifest fréquemment utilisés                │
│     └─> Accélération pulls répétés                         │
│                                                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Image layers (streaming)
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ GitLab CI Runner                                            │
├─────────────────────────────────────────────────────────────┤
│ • Layers téléchargées et extraites                         │
│ • Image disponible localement                              │
│ • Démarrage container                                      │
└─────────────────────────────────────────────────────────────┘
```


### Architecture Stockage Harbor

```
/data/harbor/
├── registry/                  # Stockage images Docker (blobs)
│   ├── docker/
│   │   └── registry/
│   │       └── v2/
│   │           ├── blobs/     # Layers images (dedupliqués)
│   │           │   └── sha256/
│   │           │       ├── ab/cd/abcdef...  # Layer 1
│   │           │       ├── 12/34/123456...  # Layer 2
│   │           │       └── ...
│   │           └── repositories/  # Manifests par projet
│   │               ├── library/
│   │               │   └── nginx/
│   │               │       └── _manifests/
│   │               └── prod/
│   │                   └── myapp/
│   │                       └── _manifests/
│   │
├── database/                  # PostgreSQL data
│   └── postgres/
│       ├── base/
│       └── pg_wal/
│
├── redis/                     # Redis data (cache/sessions)
│   └── dump.rdb
│
├── trivy/                     # Cache database Trivy
│   └── db/
│       └── trivy.db
│
├── chart_storage/             # Helm charts (si ChartMuseum activé)
│   └── charts/
│
└── job_logs/                  # Logs tâches asynchrones
    └── scan_all_2026011701.log
```


***

## 📍 Fichiers Configuration Harbor

### Fichier 1 : `harbor.yml` (Configuration principale)

**Chemin** : `/opt/harbor/harbor.yml`
**Rôle** : Configuration Harbor (généré depuis Ansible template)
**Généré** : ✅ Ansible template

```yaml
# ===================================================================
# Configuration Harbor (généré par Ansible)
# Date : 2026-01-17
# ===================================================================

# ===================================================================
# 1. Configuration réseau
# ===================================================================
hostname: harbor.lab.local

# HTTP (port 80 - redirect vers HTTPS)
http:
  port: 80

# HTTPS (port 443)
https:
  port: 443
  certificate: /data/harbor/cert/harbor.crt
  private_key: /data/harbor/cert/harbor.key

# URL externe (utilisée dans emails, webhooks)
external_url: https://harbor.lab.local

# ===================================================================
# 2. Configuration Harbor Core
# ===================================================================
# Password admin initial (changeable via UI)
harbor_admin_password: "{{ harbor_admin_password }}"

# Database PostgreSQL (interne)
database:
  password: "{{ harbor_db_password }}"
  max_idle_conns: 100
  max_open_conns: 900
  conn_max_lifetime: 5m
  conn_max_idle_time: 0

# Redis (cache et sessions)
redis:
  # Internal Redis (conteneur Harbor)
  # host: redis
  # port: 6379
  # password: ""
  # database: 0
  
  # External Redis (optionnel)
  # external:
  #   host: redis.lab.local
  #   port: 6379
  #   password: "{{ redis_password }}"

# ===================================================================
# 3. Stockage
# ===================================================================
data_volume: /data/harbor

# Stockage filesystem (par défaut)
storage_service:
  filesystem:
    rootdirectory: /storage
    maxthreads: 100

# Stockage S3 (optionnel)
# storage_service:
#   s3:
#     accesskey: AWS_ACCESS_KEY_ID
#     secretkey: AWS_SECRET_ACCESS_KEY
#     region: us-west-1
#     bucket: harbor-images
#     encrypt: false
#     secure: true
#     v4auth: true

# ===================================================================
# 4. Configuration Trivy (scan vulnérabilités)
# ===================================================================
trivy:
  # Ignore unfixed vulnerabilities
  ignore_unfixed: false
  
  # Skip update DB Trivy (utiliser cache local)
  skip_update: false
  
  # Offline mode (pas de téléchargement DB)
  offline_scan: false
  
  # GitHub token (rate limit API GitHub)
  # github_token: ""
  
  # Insecure registries (skip TLS verify)
  insecure: false
  
  # Timeout scan
  timeout: 5m0s

# ===================================================================
# 5. Configuration authentification
# ===================================================================
# Mode authentification : database (local) ou ldap/oidc
auth_mode: database

# LDAP (optionnel)
# ldap:
#   url: ldap://ldap.lab.local:389
#   search_dn: cn=admin,dc=lab,dc=local
#   search_password: "{{ ldap_password }}"
#   base_dn: dc=lab,dc=local
#   uid: uid
#   filter: (objectClass=person)
#   scope: 2
#   timeout: 5

# Self-registration (inscription libre)
self_registration: false

# Token expiration (sessions)
token_expiration: 30

# ===================================================================
# 6. Configuration email (notifications)
# ===================================================================
email:
  host: smtp.lab.local
  port: 587
  username: harbor@lab.local
  password: "{{ smtp_password }}"
  from: harbor@lab.local
  ssl: false
  insecure: true  # Skip cert verify

# ===================================================================
# 7. Logs
# ===================================================================
log:
  level: info
  local:
    rotate_count: 50
    rotate_size: 200M
    location: /var/log/harbor

# Syslog externe (optionnel)
# external_endpoint:
#   protocol: tcp
#   host: syslog.lab.local
#   port: 514

# ===================================================================
# 8. Proxy (accès Internet pour Trivy DB update)
# ===================================================================
# proxy:
#   http_proxy: http://proxy.lab.local:3128
#   https_proxy: http://proxy.lab.local:3128
#   no_proxy: 127.0.0.1,localhost,.lab.local

# ===================================================================
# 9. Features optionnels
# ===================================================================
# ChartMuseum (repository Helm charts)
chart:
  absolute_url: disabled

# Jobservice (tâches asynchrones)
jobservice:
  max_job_workers: 10

# Webhook (notifications externes)
notification:
  webhook_job_max_retry: 3
  webhook_job_http_client_timeout: 3s

# Cache registry (accélérer pulls)
cache:
  enabled: false
  # expire_hours: 24

# ===================================================================
# 10. Quotas et limites
# ===================================================================
# Quota stockage par défaut (0 = illimité)
default_project_quota: 0

# Upload size max (0 = illimité)
upload_max_size: 0

# ===================================================================
# 11. Garbage Collection
# ===================================================================
# Suppression automatique images non référencées
# Schedule via UI : Administration → Garbage Collection

# ===================================================================
# 12. Replication (multi-sites - optionnel)
# ===================================================================
# Replication vers autre Harbor instance
# Configuration via UI : Administration → Replications

# ===================================================================
# 13. Scan automatique
# ===================================================================
# Scan automatique au push
# Configuration via UI : Administration → Interrogation Services

# ===================================================================
# 14. Métriques Prometheus (optionnel)
# ===================================================================
metric:
  enabled: true
  port: 9090
  path: /metrics

# ===================================================================
# 15. Tracing (optionnel)
# ===================================================================
# trace:
#   enabled: true
#   sample_rate: 1
#   jaeger:
#     endpoint: http://jaeger.lab.local:14268/api/traces
```


***

### Fichier 2 : `docker-compose.yml` (Stack Harbor)

**Chemin** : `/opt/harbor/docker-compose.yml`
**Rôle** : Stack Docker Compose Harbor (généré automatiquement)
**Généré** : ✅ Script Harbor `install.sh`

```yaml
# ===================================================================
# Docker Compose Harbor (généré automatiquement par install.sh)
# NE PAS ÉDITER MANUELLEMENT - Utiliser harbor.yml
# ===================================================================

version: '2.3'

services:
  # =================================================================
  # PostgreSQL : Base de données Harbor
  # =================================================================
  postgresql:
    image: goharbor/harbor-db:v2.10.0
    container_name: harbor-db
    restart: always
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - DAC_OVERRIDE
      - SETGID
      - SETUID
    volumes:
      - /data/harbor/database:/var/lib/postgresql/data:z
    networks:
      - harbor
    env_file:
      - ./common/config/db/env
    depends_on:
      - log
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://localhost:1514"
        tag: "postgresql"

  # =================================================================
  # Redis : Cache et sessions
  # =================================================================
  redis:
    image: goharbor/redis-photon:v2.10.0
    container_name: redis
    restart: always
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID
    volumes:
      - /data/harbor/redis:/var/lib/redis
    networks:
      - harbor
    depends_on:
      - log
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://localhost:1514"
        tag: "redis"

  # =================================================================
  # Harbor Core : API principale
  # =================================================================
  core:
    image: goharbor/harbor-core:v2.10.0
    container_name: harbor-core
    restart: always
    cap_drop:
      - ALL
    cap_add:
      - SETGID
      - SETUID
    volumes:
      - /data/harbor/ca_download/:/etc/core/ca/:z
      - /data/harbor/:/data/:z
      - ./common/config/core/certificates/:/etc/core/certificates/:z
    networks:
      - harbor
    env_file:
      - ./common/config/core/env
    depends_on:
      - log
      - registry
      - redis
      - postgresql
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://localhost:1514"
        tag: "core"

  # =================================================================
  # Harbor Portal : Interface Web
  # =================================================================
  portal:
    image: goharbor/harbor-portal:v2.10.0
    container_name: harbor-portal
    restart: always
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID
      - NET_BIND_SERVICE
    networks:
      - harbor
    depends_on:
      - log
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://localhost:1514"
        tag: "portal"

  # =================================================================
  # Jobservice : Tâches asynchrones (scan, GC, replication)
  # =================================================================
  jobservice:
    image: goharbor/harbor-jobservice:v2.10.0
    container_name: harbor-jobservice
    restart: always
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID
    volumes:
      - /data/harbor/job_logs:/var/log/jobs:z
      - /data/harbor/:/data/:z
    networks:
      - harbor
    env_file:
      - ./common/config/jobservice/env
    depends_on:
      - core
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://localhost:1514"
        tag: "jobservice"

  # =================================================================
  # Docker Registry v2 : Stockage images
  # =================================================================
  registry:
    image: goharbor/registry-photon:v2.10.0
    container_name: registry
    restart: always
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID
    volumes:
      - /data/harbor/registry:/storage:z
      - ./common/config/registry/:/etc/registry/:z
    networks:
      - harbor
    depends_on:
      - log
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://localhost:1514"
        tag: "registry"

  # =================================================================
  # Registryctl : Contrôle registry (GC, health)
  # =================================================================
  registryctl:
    image: goharbor/harbor-registryctl:v2.10.0
    container_name: registryctl
    restart: always
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID
    volumes:
      - /data/harbor/registry:/storage:z
      - ./common/config/registry/:/etc/registry/:z
      - ./common/config/registryctl/env
    networks:
      - harbor
    depends_on:
      - log
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://localhost:1514"
        tag: "registryctl"

  # =================================================================
  # Trivy : Scan vulnérabilités
  # =================================================================
  trivy-adapter:
    image: goharbor/trivy-adapter-photon:v2.10.0
    container_name: trivy-adapter
    restart: always
    cap_drop:
      - ALL
    networks:
      - harbor
    volumes:
      - /data/harbor/trivy-adapter/trivy:/home/scanner/.cache/trivy:z
    depends_on:
      - log
      - redis
    env_file:
      - ./common/config/trivy-adapter/env
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://localhost:1514"
        tag: "trivy-adapter"

  # =================================================================
  # Nginx : Reverse proxy HTTPS
  # =================================================================
  nginx:
    image: goharbor/nginx-photon:v2.10.0
    container_name: nginx
    restart: always
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID
      - NET_BIND_SERVICE
    volumes:
      - ./common/config/nginx:/etc/nginx:z
      - /data/harbor/cert:/etc/cert:z
    networks:
      - harbor
    ports:
      - 80:8080
      - 443:8443
    depends_on:
      - registry
      - core
      - portal
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://localhost:1514"
        tag: "nginx"

  # =================================================================
  # Log : Collecteur logs rsyslog
  # =================================================================
  log:
    image: goharbor/harbor-log:v2.10.0
    container_name: harbor-log
    restart: always
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - DAC_OVERRIDE
      - SETGID
      - SETUID
    volumes:
      - /var/log/harbor/:/var/log/docker/:z
      - ./common/config/log/logrotate.conf:/etc/logrotate.d/logrotate.conf:z
      - ./common/config/log/rsyslog_docker.conf:/etc/rsyslog.d/rsyslog_docker.conf:z
    networks:
      - harbor
    ports:
      - 127.0.0.1:1514:10514

networks:
  harbor:
    driver: bridge
```


***

### Fichier 3 : `/etc/docker/daemon.json` (Config clients Docker)

**Chemin** : `/etc/docker/daemon.json` (sur toutes VMs clientes)
**Rôle** : Configuration Docker pour Harbor insecure (auto-signé)
**Généré** : ✅ Ansible

```json
{
  "insecure-registries": [
    "harbor.lab.local",
    "172.16.100.50"
  ],
  "registry-mirrors": [
    "https://harbor.lab.local"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
```

**Application** :

```bash
systemctl restart docker
```


***

## 📊 Commandes Maintenance Harbor

### 🔍 Diagnostic et Status

#### Vérifier containers Harbor

```bash
cd /opt/harbor
docker-compose ps

# Output attendu (9 containers)
# NAME                COMMAND                  STATUS
# harbor-core         "/harbor/entrypoint.…"   Up
# harbor-db           "/docker-entrypoint.…"   Up (healthy)
# harbor-jobservice   "/harbor/entrypoint.…"   Up
# harbor-log          "/bin/sh -c /usr/loc…"   Up
# harbor-portal       "nginx -g 'daemon of…"   Up
# nginx               "nginx -g 'daemon of…"   Up
# redis               "redis-server /etc/r…"   Up
# registry            "/home/harbor/entryp…"   Up
# registryctl         "/home/harbor/start.…"   Up
# trivy-adapter       "/home/scanner/entry…"   Up
```


#### Logs containers

```bash
# Logs tous containers (temps réel)
docker-compose logs -f

# Logs container spécifique
docker-compose logs -f harbor-core
docker-compose logs -f nginx
docker-compose logs -f trivy-adapter

# Logs avec timestamp
docker-compose logs -f --timestamps harbor-core

# 100 dernières lignes
docker-compose logs --tail=100 harbor-core
```


#### Vérifier API Harbor

```bash
# Health check
curl -k https://harbor.lab.local/api/v2.0/health
# Output : {"status":"healthy"}

# Version Harbor
curl -k https://harbor.lab.local/api/v2.0/systeminfo
# Output : {"harbor_version":"v2.10.0", ...}

# Statistiques
curl -k -u admin:password https://harbor.lab.local/api/v2.0/statistics
# Output : {"project_count":2, "repo_count":5, ...}
```


#### Vérifier espace disque

```bash
# Espace total utilisé
du -sh /data/harbor/

# Détail par composant
du -sh /data/harbor/registry      # Images Docker
du -sh /data/harbor/database      # PostgreSQL
du -sh /data/harbor/redis         # Cache
du -sh /data/harbor/trivy-adapter # Cache Trivy

# Top 10 images volumineuses
docker exec harbor-core /usr/bin/find /storage -type f -exec du -h {} + | sort -rh | head -10
```


***

### 🔄 Gestion Service

#### Contrôle stack Harbor

```bash
cd /opt/harbor

# Démarrer stack
docker-compose up -d

# Arrêter stack
docker-compose down

# Redémarrer stack
docker-compose restart

# Arrêter et supprimer volumes (DANGER : perte données)
docker-compose down -v
```


#### Restart container spécifique

```bash
# Restart un seul container
docker-compose restart harbor-core
docker-compose restart nginx

# Restart sans downtime (rolling restart)
docker-compose up -d --no-deps --build harbor-core
```


#### Mise à jour Harbor

```bash
# Backup avant upgrade
cd /opt/harbor
./backup.sh

# Télécharger nouvelle version
wget https://github.com/goharbor/harbor/releases/download/v2.11.0/harbor-offline-installer-v2.11.0.tgz
tar xvf harbor-offline-installer-v2.11.0.tgz -C /opt/

# Migration configuration
cd /opt/harbor-v2.11.0
./install.sh --with-trivy --with-chartmuseum

# Vérifier version
curl -k https://harbor.lab.local/api/v2.0/systeminfo | jq .harbor_version
```


***

### 🐳 Gestion Images Docker

#### Login/Logout

```bash
# Login Harbor
docker login harbor.lab.local
# Username : admin
# Password : ******
# Login Succeeded

# Login avec token robot
docker login harbor.lab.local -u robot$gitlab-ci -p TOKEN

# Logout
docker logout harbor.lab.local
```


#### Push image

```bash
# Build image
docker build -t myapp:v1.0 .

# Tag pour Harbor
docker tag myapp:v1.0 harbor.lab.local/prod/myapp:v1.0

# Push vers Harbor
docker push harbor.lab.local/prod/myapp:v1.0

# Vérifier dans UI
# Harbor → Projects → prod → Repositories → myapp → Artifacts
```


#### Pull image

```bash
# Pull depuis Harbor
docker pull harbor.lab.local/prod/myapp:v1.0

# Pull image publique (projet library)
docker pull harbor.lab.local/library/nginx:alpine
```


#### Lister images

```bash
# Via API (liste projets)
curl -k -u admin:password https://harbor.lab.local/api/v2.0/projects

# Liste repositories d'un projet
curl -k -u admin:password https://harbor.lab.local/api/v2.0/projects/prod/repositories

# Liste artifacts (tags) d'un repository
curl -k -u admin:password https://harbor.lab.local/api/v2.0/projects/prod/repositories/myapp/artifacts
```


#### Supprimer image

```bash
# Via UI (recommandé)
# Harbor → Projects → prod → Repositories → myapp → Artifact → Delete

# Via API
curl -k -X DELETE -u admin:password \
  https://harbor.lab.local/api/v2.0/projects/prod/repositories/myapp/artifacts/sha256:abcdef...

# Exécuter Garbage Collection après
# Harbor UI → Administration → Garbage Collection → Run Now
```


***

### 🔍 Scan Vulnérabilités (Trivy)

#### Scan manuel image

```bash
# Via UI
# Harbor → Projects → prod → Repositories → myapp → Artifact → Scan

# Via API
curl -k -X POST -u admin:password \
  https://harbor.lab.local/api/v2.0/projects/prod/repositories/myapp/artifacts/v1.0/scan
```


#### Consulter résultat scan

```bash
# Via API
curl -k -u admin:password \
  https://harbor.lab.local/api/v2.0/projects/prod/repositories/myapp/artifacts/v1.0/additions/vulnerabilities | jq

# Output :
# {
#   "summary": {
#     "critical": 1,
#     "high": 5,
#     "medium": 20,
#     "low": 50
#   },
#   "vulnerabilities": [
#     {
#       "id": "CVE-2024-1234",
#       "severity": "Critical",
#       "package": "openssl",
#       "version": "1.1.1k",
#       "fixed_version": "1.1.1l",
#       "description": "..."
#     }
#   ]
# }
```


#### Scan all images (tous projets)

```bash
# Via UI
# Harbor → Administration → Interrogation Services → Scan All

# Via API
curl -k -X POST -u admin:password \
  https://harbor.lab.local/api/v2.0/system/scanAll/schedule
```


#### Mettre à jour database Trivy

```bash
# Automatique : Trivy update tous les jours
# Manuel :
docker exec trivy-adapter trivy --download-db-only

# Vérifier version DB
docker exec trivy-adapter trivy --version
```


***

### 🗑️ Garbage Collection

#### Exécuter GC manuellement

```bash
# Via UI (recommandé)
# Harbor → Administration → Garbage Collection → Run Now

# Via docker-compose (arrêt service registry requis)
cd /opt/harbor
docker-compose stop registry registryctl
docker run --rm -v /data/harbor/registry:/storage \
  goharbor/registry-photon:v2.10.0 \
  garbage-collect /etc/registry/config.yml
docker-compose start registry registryctl
```


#### Programmer GC automatique

```bash
# Via UI
# Harbor → Administration → Garbage Collection
# Schedule : Daily 2:00 AM
# Delete untagged manifests : ✅ Enabled
```


#### Vérifier logs GC

```bash
# Logs jobservice (GC exécuté par jobservice)
docker-compose logs jobservice | grep -i "garbage"

# Logs registry
docker-compose logs registry | grep -i "gc"
```


***

### 👥 Gestion Utilisateurs et Projets

#### Créer projet (via API)

```bash
curl -k -X POST -u admin:password \
  -H "Content-Type: application/json" \
  https://harbor.lab.local/api/v2.0/projects \
  -d '{
    "project_name": "dev",
    "public": false,
    "storage_limit": -1
  }'
```


#### Créer utilisateur robot (via API)

```bash
curl -k -X POST -u admin:password \
  -H "Content-Type: application/json" \
  https://harbor.lab.local/api/v2.0/projects/2/robots \
  -d '{
    "name": "ci-bot",
    "description": "CI/CD bot",
    "duration": -1,
    "level": "project",
    "permissions": [
      {
        "kind": "project",
        "namespace": "dev",
        "access": [
          {"resource": "repository", "action": "pull"},
          {"resource": "repository", "action": "push"}
        ]
      }
    ]
  }'

# Récupérer token dans response JSON
# "secret": "eyJhbGciOiJSUzI1NiIsIn..."
```


#### Lister membres projet

```bash
curl -k -u admin:password \
  https://harbor.lab.local/api/v2.0/projects/prod/members | jq
```


***

### 📊 Monitoring et Métriques

#### Métriques Prometheus

```bash
# Activer dans harbor.yml
# metric:
#   enabled: true
#   port: 8001
#   path: /metrics

# Récupérer métriques
curl http://172.16.100.50:8001/metrics

# Métriques importantes
# harbor_project_repo_total
# harbor_project_artifact_total
# registry_http_request_duration_seconds
# harbor_health
```


#### Statistiques Harbor

```bash
# Via API
curl -k -u admin:password \
  https://harbor.lab.local/api/v2.0/statistics | jq

# Output :
# {
#   "project_count": 3,
#   "repo_count": 15,
#   "storage_consumed": 5368709120,  # 5 GB en bytes
#   "total_artifact_count": 50
# }
```


***

### 🔐 Sécurité

#### Vérifier webhooks (audit logs)

```bash
# Via UI
# Harbor → Projects → prod → Webhooks → View Logs

# Via API (logs audit)
curl -k -u admin:password \
  'https://harbor.lab.local/api/v2.0/projects/prod/logs?page=1&page_size=100' | jq

# Types événements
# - PUSH_ARTIFACT
# - PULL_ARTIFACT
# - DELETE_ARTIFACT
# - SCANNING_COMPLETED
```


#### Export audit logs

```bash
# Logs PostgreSQL
docker exec harbor-db pg_dump -U postgres -d registry > harbor-audit.sql

# Logs fichiers
tar -czf harbor-logs-$(date +%Y%m%d).tar.gz /var/log/harbor/
```


#### Bloquer push images vulnérables

```bash
# Via UI
# Harbor → Projects → prod → Configuration
# Prevent vulnerable images from running : ✅ Enabled
# Severity : Critical + High

# Test : push image avec CVE critical
docker push harbor.lab.local/prod/vuln-app:v1.0
# Error : "current image has 1 vulnerabilities with severity >= High"
```


***

### 💾 Backup et Restore

#### Backup complet Harbor

```bash
#!/bin/bash
# Script backup Harbor

BACKUP_DIR="/backup/harbor/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# 1. Backup PostgreSQL
docker exec harbor-db pg_dumpall -U postgres > $BACKUP_DIR/database.sql

# 2. Backup Redis
docker exec redis redis-cli --rdb /data/dump.rdb
docker cp redis:/data/dump.rdb $BACKUP_DIR/redis.rdb

# 3. Backup registry (images Docker)
tar -czf $BACKUP_DIR/registry.tar.gz /data/harbor/registry/

# 4. Backup configuration
cp /opt/harbor/harbor.yml $BACKUP_DIR/
cp -r /data/harbor/cert/ $BACKUP_DIR/cert/

# 5. Backup job logs
tar -czf $BACKUP_DIR/job_logs.tar.gz /data/harbor/job_logs/

echo "Backup terminé : $BACKUP_DIR"
du -sh $BACKUP_DIR
```


#### Restore Harbor

```bash
#!/bin/bash
# Script restore Harbor

BACKUP_DIR="/backup/harbor/20260117"

# 1. Arrêter Harbor
cd /opt/harbor
docker-compose down

# 2. Restore configuration
cp $BACKUP_DIR/harbor.yml /opt/harbor/
cp -r $BACKUP_DIR/cert/ /data/harbor/

# 3. Restore PostgreSQL
cat $BACKUP_DIR/database.sql | docker exec -i harbor-db psql -U postgres

# 4. Restore Redis
docker cp $BACKUP_DIR/redis.rdb redis:/data/dump.rdb

# 5. Restore registry
tar -xzf $BACKUP_DIR/registry.tar.gz -C /

# 6. Redémarrer Harbor
docker-compose up -d

echo "Restore terminé"
```


***

## 🎯 Use Cases Avancés

### 🔄 Réplication Multi-Sites

```yaml
# Configuration réplication (via UI)
# Harbor → Administration → Replications → New Replication Rule

# Source : harbor.lab.local (local)
# Destination : harbor-backup.lab.local (remote)
# Trigger : Event Based (push image)
# Filters :
#   - Name : prod/**
#   - Tag : v*.*.*
# Mode : Push-based
```


### 🔗 Intégration GitLab CI

```yaml
# .gitlab-ci.yml
stages:
  - build
  - scan
  - deploy

variables:
  HARBOR_REGISTRY: harbor.lab.local
  IMAGE_NAME: $HARBOR_REGISTRY/prod/myapp
  IMAGE_TAG: $CI_COMMIT_TAG

build:
  stage: build
  script:
    - docker login -u $HARBOR_USER -p $HARBOR_PASSWORD $HARBOR_REGISTRY
    - docker build -t $IMAGE_NAME:$IMAGE_TAG .
    - docker push $IMAGE_NAME:$IMAGE_TAG

scan:
  stage: scan
  script:
    # Déclencher scan Trivy via API Harbor
    - |
      curl -k -X POST -u $HARBOR_USER:$HARBOR_PASSWORD \
        https://$HARBOR_REGISTRY/api/v2.0/projects/prod/repositories/myapp/artifacts/$IMAGE_TAG/scan
    
    # Attendre fin scan
    - sleep 30
    
    # Récupérer résultat
    - |
      VULNS=$(curl -k -u $HARBOR_USER:$HARBOR_PASSWORD \
        https://$HARBOR_REGISTRY/api/v2.0/projects/prod/repositories/myapp/artifacts/$IMAGE_TAG/additions/vulnerabilities \
        | jq '.summary.critical + .summary.high')
    
    # Fail si vulnérabilités critiques/high
    - if [ "$VULNS" -gt 0 ]; then exit 1; fi

deploy:
  stage: deploy
  script:
    - docker pull $IMAGE_NAME:$IMAGE_TAG
    - docker run -d $IMAGE_NAME:$IMAGE_TAG
  only:
    - tags
```


***

## � Guide de Résolution : Réinitialisation du Mot de Passe Admin Harbor

### 📋 Contexte du Problème

**Date** : 26 janvier 2026  
**Symptôme Initial** : Impossibilité de se connecter à Harbor avec les identifiants admin  
**Mot de passe attendu** : `P@ssw0rd`  
**Environnement** :
- Harbor v2.11.1 sur VM 172.16.100.50
- Reverse proxy Nginx sur 172.16.100.253
- DNS BIND9 sur 172.16.100.254
- PostgreSQL (registry DB)

---

### 🔍 Phase 1 : Diagnostic Initial

#### Étape 1.1 : Test d'authentification API

```bash
# Tentative d'authentification via API
curl -k -u admin:P@ssw0rd https://harbor.lab.local/api/v2.0/systeminfo

# Résultat : HTTP/2 401 Unauthorized
# ❌ Échec : mot de passe refusé
```

**Diagnostic** : Le mot de passe `P@ssw0rd` défini dans `harbor.yml` n'est pas fonctionnel.

#### Étape 1.2 : Vérification de la configuration

```bash
# Vérifier le mot de passe dans harbor.yml
ssh ansible@172.16.100.50 \
  "sudo grep harbor_admin_password /opt/harbor/harbor/harbor.yml"

# Résultat : harbor_admin_password: ChangeMe!HarborAdmin
# ❌ Le fichier contient toujours le mot de passe par défaut
```

**Constat** : Le mot de passe n'avait jamais été mis à jour dans la configuration Harbor.

---

### 🔧 Phase 2 : Tentative de Réinitialisation via Base de Données

#### Étape 2.1 : Localisation de la table utilisateurs

```bash
# Connexion à PostgreSQL et recherche de la table
docker exec harbor-db psql -U postgres -l

# Test dans la DB postgres
docker exec harbor-db psql -U postgres -d postgres -c "\dt"
# ❌ Table harbor_user non trouvée

# Test dans la DB registry (✅ correct)
docker exec harbor-db psql -U postgres -d registry -c "\dt"
# ✅ Table public.harbor_user trouvée
```

**Découverte** : La table `harbor_user` se trouve dans la base de données `registry`, pas `postgres`.

#### Étape 2.2 : Tentative de réinitialisation du hash

```bash
# Vider le hash et le salt pour forcer la régénération
docker exec harbor-db psql -U postgres -d registry -c \
  "UPDATE harbor_user SET password='', salt='' WHERE username='admin';"

# Résultat : UPDATE 1
# ✅ Hash vidé avec succès
```

#### Étape 2.3 : Redémarrage du service Harbor Core

```bash
# Première tentative (nom incorrect)
cd /opt/harbor/harbor && docker compose restart harbor-core
# ❌ Erreur : no such service: harbor-core

# Vérification des noms de services réels
docker compose ps
# ✅ Le service s'appelle "core", pas "harbor-core"

# Redémarrage avec le bon nom
docker compose restart core && sleep 3
# ✅ Service redémarré
```

#### Étape 2.4 : Test d'authentification après redémarrage

```bash
curl -k -u admin:P@ssw0rd https://harbor.lab.local/api/v2.0/systeminfo
# ❌ Résultat : HTTP/2 401 Unauthorized
# Échec : La réinitialisation du hash n'a pas fonctionné
```

**Constat** : Vider le hash ne suffit pas. Harbor nécessite un redéploiement complet pour appliquer le nouveau mot de passe.

---

### 🎯 Phase 3 : Solution via Ansible (Redéploiement)

#### Étape 3.1 : Mise à jour de la variable dans Ansible

```bash
# Créer le fichier host_vars pour surcharger le default
cat > Ansible/inventory/host_vars/harbor.yml << 'EOF'
---
# Host vars for Harbor
harbor_admin_password: "P@ssw0rd"
EOF
```

**Fichiers concernés** :
- `Ansible/roles/harbor/defaults/main.yml` : Contient le mot de passe par défaut
- `Ansible/inventory/host_vars/harbor.yml` : ✅ **Nouveau fichier** avec surcharge du mot de passe
- `Ansible/roles/harbor/templates/harbor.yml.j2` : Template utilisant `{{ harbor_admin_password }}`

#### Étape 3.2 : Redéploiement via Ansible

```bash
# Créer un playbook temporaire
cat > /tmp/redeploy-harbor.yml << 'EOF'
---
- name: Redeploy Harbor configuration
  hosts: harbor
  become: yes
  roles:
    - role: harbor
EOF

# Exécuter le redéploiement
cd Ansible
ansible-playbook -i inventory/hosts.yml /tmp/redeploy-harbor.yml

# ✅ Résultat : 
# - changed=9 : Harbor reconfiguré et redéployé
# - harbor.yml mis à jour avec P@ssw0rd
```

#### Étape 3.3 : Vérification de la mise à jour

```bash
# Vérifier que harbor.yml contient le nouveau mot de passe
ssh ansible@172.16.100.50 \
  "sudo grep harbor_admin_password /opt/harbor/harbor/harbor.yml"

# ✅ Résultat : harbor_admin_password: P@ssw0rd
```

---

### 🐛 Phase 4 : Résolution des Problèmes Bloquants

#### Problème 4.1 : Reverse Proxy Nginx Arrêté

**Symptôme** :
```bash
docker login harbor.lab.local
# Erreur : dial tcp 172.16.100.253:443: connect: connection refused
```

**Diagnostic** :
```bash
# Vérification du port 443
ssh ansible@172.16.100.253 "sudo ss -tlnp | grep 443"
# ❌ Aucun résultat : Nginx n'écoute pas sur le port 443

# Vérification des containers Docker
docker ps | grep nginx
# ❌ Seul nginx-prometheus-exporter est en cours d'exécution
# Le container nginx-reverse-proxy n'existe pas
```

**Résolution** :
```bash
# Redéploiement du reverse proxy via Ansible
cd Ansible
ansible-playbook -i inventory/hosts.yml playbooks/nginx_reverse_proxy.yml

# ✅ Résultat : Nginx redéployé et en écoute sur ports 80, 443, 8080, 9113
```

**Vérification** :
```bash
docker ps | grep nginx
# ✅ nginx-reverse-proxy : Up, 0.0.0.0:443->443/tcp
# ✅ nginx-prometheus-exporter : Up, 0.0.0.0:9113->9113/tcp
```

#### Problème 4.2 : Configuration DNS Incorrecte

**Symptôme** :
```bash
docker login harbor.lab.local
# Erreur : dial tcp: lookup harbor.lab.local: Temporary failure in name resolution
```

**Diagnostic** :
```bash
# Vérification de la configuration DNS
resolvectl status

# ❌ Résultat :
# Current DNS Server: 8.8.8.8
# Le serveur pointe vers Google DNS au lieu de BIND9 local (172.16.100.254)
```

**Résolution** :
```bash
# Configuration de systemd-resolved pour utiliser BIND9
sudo mkdir -p /etc/systemd/resolved.conf.d/
cat << 'EOF' | sudo tee /etc/systemd/resolved.conf.d/00-dns.conf
[Resolve]
DNS=172.16.100.254
Domains=~lab.local
EOF

# Redémarrage du service
sudo systemctl restart systemd-resolved
```

**Vérification** :
```bash
resolvectl status
# ✅ Résultat :
# Global DNS Servers: 172.16.100.254
# DNS Domain: ~lab.local

# Test de résolution
ping -c 1 harbor.lab.local
# ✅ 64 bytes from 172.16.100.253
```

#### Problème 4.3 : Certificat TLS Auto-Signé Non Approuvé

**Symptôme** :
```bash
docker login harbor.lab.local
# Erreur : tls: failed to verify certificate: x509: certificate signed by unknown authority
```

**Diagnostic** :
```bash
# Analyse de la chaîne de certificats
openssl s_client -connect harbor.lab.local:443 -servername harbor.lab.local \
  < /dev/null 2>/dev/null | openssl x509 -noout -issuer -subject

# Résultat :
# issuer=C=FR, ST=IDF, L=Paris, O=Lab, CN=*.lab.local
# subject=C=FR, ST=IDF, L=Paris, O=Lab, CN=*.lab.local
# ❌ Certificat auto-signé (issuer = subject)

# Vérification des certificats sur le reverse proxy
ssh ansible@172.16.100.253 \
  "sudo openssl x509 -in /etc/nginx/ssl/wildcard.lab.local.crt -noout -issuer"
# ❌ Le wildcard n'est PAS signé par le root CA, il est auto-signé
```

**Constat** : Deux certificats existent :
- `/etc/nginx/ssl/root-ca.crt` : CA root (CN=Lab Root CA)
- `/etc/nginx/ssl/wildcard.lab.local.crt` : Certificat wildcard **auto-signé** (CN=*.lab.local)

Le certificat wildcard n'est pas signé par le CA root, il faut donc l'ajouter directement comme CA de confiance pour Docker.

**Résolution** :
```bash
# 1. Copier le certificat wildcard vers l'hôte tools-manager
ssh ansible@172.16.100.253 \
  "sudo cp /etc/nginx/ssl/wildcard.lab.local.crt /tmp/wildcard.crt && \
   sudo chmod 644 /tmp/wildcard.crt"

scp ansible@172.16.100.253:/tmp/wildcard.crt /tmp/
scp /tmp/wildcard.crt ansible@172.16.100.20:/tmp/

# 2. Installer le certificat pour Docker (répertoire spécifique Harbor)
ssh ansible@172.16.100.20 "
  sudo mkdir -p /etc/docker/certs.d/harbor.lab.local
  sudo cp /tmp/wildcard.crt /etc/docker/certs.d/harbor.lab.local/ca.crt
  sudo chmod 644 /etc/docker/certs.d/harbor.lab.local/ca.crt
"

# 3. Installer au niveau système (trust store)
ssh ansible@172.16.100.20 "
  sudo cp /tmp/wildcard.crt /usr/local/share/ca-certificates/harbor-wildcard.crt
  sudo update-ca-certificates
"
# ✅ Résultat : 1 added, 0 removed

# 4. Redémarrer Docker pour prendre en compte les nouveaux certificats
ssh ansible@172.16.100.20 "sudo systemctl restart docker"
```

**Vérification** :
```bash
# Test de connexion TLS
openssl s_client -connect harbor.lab.local:443 -CAfile /tmp/wildcard.crt \
  < /dev/null 2>&1 | grep "Verify return code"
# ✅ Verify return code: 0 (ok)
```

---

### ✅ Phase 5 : Validation Finale

#### Étape 5.1 : Test du mot de passe par défaut (diagnostic)

```bash
# Test avec l'ancien mot de passe
echo 'ChangeMe!HarborAdmin' | docker login -u admin --password-stdin harbor.lab.local

# ✅ Résultat : Login Succeeded
# ⚠️ Constat : Le mot de passe par défaut fonctionne toujours
# Le redéploiement Ansible n'a pas réinitialisé le hash en base de données
```

**Explication** : Le role Ansible met à jour `harbor.yml` mais ne réinstalle pas Harbor. Le hash du mot de passe en base de données reste inchangé.

#### Étape 5.2 : Réinstallation de Harbor avec le nouveau mot de passe

```bash
# Arrêt, préparation et réinstallation complète
ssh ansible@172.16.100.50 "
  cd /opt/harbor/harbor
  sudo docker compose down
  sudo ./prepare
  sudo ./install.sh --with-trivy
"

# ✅ Résultat :
# [Step 1]: checking if docker is installed ...
# [Step 2]: checking docker-compose is installed ...
# [Step 3]: loading Harbor images ...
# [Step 4]: preparing environment ...
# [Step 5]: starting Harbor ...
# ✔ ----Harbor has been installed and started successfully.----
```

**Processus de réinstallation** :
1. `docker compose down` : Arrêt de tous les services Harbor
2. `./prepare` : Génération des fichiers de configuration à partir de `harbor.yml`
3. `./install.sh --with-trivy` : 
   - Création des containers
   - **Initialisation de la base de données avec le nouveau mot de passe**
   - Calcul du hash bcrypt pour `P@ssw0rd`
   - Insertion dans `registry.harbor_user`

#### Étape 5.3 : Changement du mot de passe via API Harbor

**Alternative à la réinstallation** : Utiliser l'API Harbor pour changer le mot de passe

```bash
# Connexion avec l'ancien mot de passe pour changer vers le nouveau
curl -k -X PUT \
  -u admin:ChangeMe!HarborAdmin \
  -H "Content-Type: application/json" \
  -d '{
    "old_password": "ChangeMe!HarborAdmin",
    "new_password": "P@ssw0rd"
  }' \
  https://harbor.lab.local/api/v2.0/users/1/password

# ✅ Résultat : HTTP 200 OK (pas de sortie = succès)
```

#### Étape 5.4 : Validation Docker Login avec P@ssw0rd

```bash
# Déconnexion
docker logout harbor.lab.local

# Test de connexion avec le nouveau mot de passe
echo 'P@ssw0rd' | docker login -u admin --password-stdin harbor.lab.local

# ✅ Résultat :
# Login Succeeded
# WARNING! Your credentials are stored unencrypted in '/home/ansible/.docker/config.json'.
```

#### Étape 5.5 : Tests de validation complets

```bash
# 1. Authentification API
curl -k -u admin:P@ssw0rd https://harbor.lab.local/api/v2.0/systeminfo
# ✅ {"harbor_version":"v2.11.1",...}

# 2. Liste des repositories
curl -k -u admin:P@ssw0rd https://harbor.lab.local/api/v2.0/repositories
# ✅ [] (liste vide car aucun repo créé)

# 3. Push d'une image de test
docker pull alpine:latest
docker tag alpine:latest harbor.lab.local/library/alpine:test
docker push harbor.lab.local/library/alpine:test
# ✅ The push refers to repository [harbor.lab.local/library/alpine]
# ✅ test: digest: sha256:... size: 528

# 4. Vérification dans Harbor
curl -k -u admin:P@ssw0rd \
  https://harbor.lab.local/api/v2.0/projects/library/repositories/alpine/artifacts
# ✅ [{"tags":[{"name":"test"}],...}]
```

---

### 📊 Résumé des Problèmes et Solutions

| Problème | Symptôme | Cause Racine | Solution | Statut |
|----------|----------|--------------|----------|--------|
| **Mot de passe refusé** | 401 Unauthorized | Hash ancien en DB | Réinstallation Harbor avec `./install.sh` | ✅ Résolu |
| **Reverse proxy down** | Connection refused (443) | Nginx non déployé | `ansible-playbook nginx_reverse_proxy.yml` | ✅ Résolu |
| **DNS invalide** | Lookup failure | Serveur DNS = 8.8.8.8 | Config systemd-resolved → 172.16.100.254 | ✅ Résolu |
| **Certificat TLS rejeté** | x509 unknown authority | Wildcard auto-signé | Ajout cert dans `/etc/docker/certs.d/` | ✅ Résolu |
| **Harbor containers arrêtés** | 502 Bad Gateway | Docker compose down | `docker compose up -d` | ✅ Résolu |

---

### 🔑 Points Clés à Retenir

#### Configuration du Mot de Passe Harbor

1. **Définition dans Ansible** :
   ```yaml
   # Ansible/inventory/host_vars/harbor.yml
   harbor_admin_password: "P@ssw0rd"
   ```

2. **Application via harbor.yml** :
   ```yaml
   # /opt/harbor/harbor/harbor.yml
   harbor_admin_password: P@ssw0rd  # Lu par ./prepare et ./install.sh
   ```

3. **Stockage dans PostgreSQL** :
   ```sql
   -- Base de données : registry
   -- Table : harbor_user
   -- Hash : bcrypt du mot de passe + salt
   SELECT username, password, salt FROM harbor_user WHERE username='admin';
   ```

#### Méthodes de Changement du Mot de Passe

| Méthode | Moment d'Usage | Avantages | Inconvénients |
|---------|----------------|-----------|---------------|
| **./install.sh** | Installation initiale | Hash créé automatiquement | Redéploiement complet requis |
| **API Harbor** | Post-installation | Rapide, pas de downtime | Nécessite l'ancien mot de passe |
| **UPDATE SQL** | Urgence (perte MDP) | Fonctionne sans ancien MDP | ❌ **Ne fonctionne pas** : Harbor ignore le hash vide |

#### Architecture de Confiance TLS

```
Client Docker (tools-manager)
    ↓
    └─ /etc/docker/certs.d/harbor.lab.local/ca.crt (certificat wildcard)
    └─ /usr/local/share/ca-certificates/harbor-wildcard.crt (trust store système)
    ↓
Reverse Proxy (172.16.100.253:443)
    ↓
    └─ /etc/nginx/ssl/wildcard.lab.local.crt (certificat présenté)
    └─ /etc/nginx/ssl/wildcard.lab.local.key (clé privée)
    ↓
Harbor Core (172.16.100.50:80)
```

---

### 🚀 Procédure de Réinitialisation Complète (Checklist)

```bash
# ✅ ÉTAPE 1 : Mettre à jour la variable Ansible
cat > Ansible/inventory/host_vars/harbor.yml << 'EOF'
---
harbor_admin_password: "VotreNouveauMotDePasse"
EOF

# ✅ ÉTAPE 2 : Redéployer Harbor via Ansible
cd Ansible
ansible-playbook -i inventory/hosts.yml playbooks/harbor_portainer.yml

# ✅ ÉTAPE 3 : Vérifier que harbor.yml est à jour
ssh ansible@172.16.100.50 \
  "sudo grep harbor_admin_password /opt/harbor/harbor/harbor.yml"

# ✅ ÉTAPE 4 : Réinstaller Harbor pour appliquer le nouveau mot de passe
ssh ansible@172.16.100.50 "
  cd /opt/harbor/harbor
  sudo docker compose down
  sudo ./prepare
  sudo ./install.sh --with-trivy
"

# ✅ ÉTAPE 5 : Attendre la stabilisation (tous containers healthy)
sleep 30
ssh ansible@172.16.100.50 \
  "sudo docker ps --format '{{.Names}}\t{{.Status}}' | grep harbor"

# ✅ ÉTAPE 6 : Tester l'authentification
curl -k -u admin:VotreNouveauMotDePasse \
  https://harbor.lab.local/api/v2.0/systeminfo | jq .harbor_version

# ✅ ÉTAPE 7 : Tester docker login
echo 'VotreNouveauMotDePasse' | \
  docker login -u admin --password-stdin harbor.lab.local

# ✅ ÉTAPE 8 : Valider avec un push d'image
docker pull alpine:latest
docker tag alpine:latest harbor.lab.local/library/alpine:test
docker push harbor.lab.local/library/alpine:test
```

---

### 🛡️ Recommandations de Sécurité

#### 1. Gestion des Mots de Passe

```bash
# ❌ MAUVAISE PRATIQUE : Mot de passe en clair dans host_vars
harbor_admin_password: "P@ssw0rd"

# ✅ BONNE PRATIQUE : Utiliser Ansible Vault
ansible-vault encrypt_string 'P@ssw0rd' --name 'harbor_admin_password'
```

**Mise en œuvre** :
```yaml
# Ansible/inventory/host_vars/harbor.yml
harbor_admin_password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          66386439653937653966643861636136336163616365626533646261366261363266656437373035
          ...
```

#### 2. Certificats TLS Signés par CA

**Problème actuel** : Certificat wildcard auto-signé  
**Solution** : Générer un certificat signé par le CA root

```bash
# Génération d'un certificat wildcard signé par le CA root
# Sur le serveur avec le CA root (/etc/nginx/ssl/root-ca.crt)

# 1. Créer une demande de signature (CSR)
openssl req -new -newkey rsa:4096 -nodes \
  -keyout wildcard.lab.local.key \
  -out wildcard.lab.local.csr \
  -subj "/C=FR/ST=IDF/L=Paris/O=Lab/CN=*.lab.local"

# 2. Signer avec le CA root
openssl x509 -req -in wildcard.lab.local.csr \
  -CA root-ca.crt -CAkey root-ca.key -CAcreateserial \
  -out wildcard.lab.local.crt -days 825 -sha256 \
  -extfile <(printf "subjectAltName=DNS:*.lab.local,DNS:lab.local")

# 3. Déployer sur le reverse proxy
sudo cp wildcard.lab.local.{crt,key} /etc/nginx/ssl/
sudo systemctl reload nginx

# 4. Distribuer SEULEMENT le root-ca.crt aux clients
# Les clients feront confiance à toutes les signatures du CA
```

#### 3. Rotation des Mots de Passe

**Politique recommandée** :
- Changement du mot de passe admin tous les 90 jours
- Utilisation de mots de passe forts (16+ caractères)
- Éviter les mots de passe réutilisés

**Automatisation** :
```bash
# Script de rotation mensuelle (cron)
#!/bin/bash
NEW_PASS=$(openssl rand -base64 32)
curl -k -X PUT -u admin:$OLD_PASS \
  -H "Content-Type: application/json" \
  -d "{\"old_password\":\"$OLD_PASS\",\"new_password\":\"$NEW_PASS\"}" \
  https://harbor.lab.local/api/v2.0/users/1/password

# Stocker le nouveau mot de passe dans Vault
ansible-vault encrypt_string "$NEW_PASS" --name 'harbor_admin_password' \
  >> inventory/host_vars/harbor.yml
```

---

### 📝 Logs de Diagnostic Utiles

```bash
# Logs Harbor Core (authentification)
docker logs harbor-core --tail 100 --follow

# Logs Nginx Harbor (requêtes proxy)
docker logs nginx --tail 100 --follow

# Logs PostgreSQL (requêtes DB)
docker logs harbor-db --tail 100 --follow

# Logs Reverse Proxy (SSL/TLS)
ssh ansible@172.16.100.253 \
  "sudo docker logs nginx-reverse-proxy --tail 100"

# Vérification du statut de santé
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Vérification de la configuration DNS
resolvectl query harbor.lab.local

# Test de la chaîne TLS complète
openssl s_client -connect harbor.lab.local:443 -showcerts
```

---

***

## �📚 Références Officielles

- **Documentation Harbor** : https://goharbor.io/docs/2.10.0/
- **GitHub Harbor** : https://github.com/goharbor/harbor
- **Trivy** : https://github.com/aquasecurity/trivy
- **Docker Registry v2** : https://docs.docker.com/registry/
- **API Harbor** : https://editor.swagger.io/?url=https://raw.githubusercontent.com/goharbor/harbor/main/api/v2.0/swagger.yaml

***

**Harbor est maintenant documenté de A à Z !** 🚢 Registry Docker privé sécurisé et prêt pour la production ! 🔒

