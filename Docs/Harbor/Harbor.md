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
│  VM : harbor (172.16.100.2)                                │
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
       ├─> IP statique : 172.16.100.2
       ├─> CPU : 4 cores (recommandé pour scan images)
       ├─> RAM : 8 GB (PostgreSQL + Redis + Trivy)
       └─> Disk : 100 GB (stockage images Docker)

2. Cloud-init configure réseau
   └─> IP : 172.16.100.2/24
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
│ harbor (172.16.100.2)                                       │
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
│ harbor (172.16.100.2)                                       │
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
    "172.16.100.2"
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
#   port: 9090
#   path: /metrics

# Récupérer métriques
curl http://172.16.100.2:9090/metrics

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

## 📚 Références Officielles

- **Documentation Harbor** : https://goharbor.io/docs/2.10.0/
- **GitHub Harbor** : https://github.com/goharbor/harbor
- **Trivy** : https://github.com/aquasecurity/trivy
- **Docker Registry v2** : https://docs.docker.com/registry/
- **API Harbor** : https://editor.swagger.io/?url=https://raw.githubusercontent.com/goharbor/harbor/main/api/v2.0/swagger.yaml

***

**Harbor est maintenant documenté de A à Z !** 🚢 Registry Docker privé sécurisé et prêt pour la production ! 🔒

