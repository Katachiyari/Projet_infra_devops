# 🦊 GitLab : Plateforme DevOps Complète


***

## 📍 Explication : Git et GitLab

### Définition

**GitLab** est une plateforme DevOps complète open-source qui intègre gestion de code source (Git), CI/CD, gestion de projets, registry Docker, sécurité applicative et monitoring. GitLab offre une solution tout-en-un pour le cycle de vie complet du développement logiciel, de la planification au déploiement.

### Comparaison des solutions Git et DevOps

| Solution | Git Hosting | CI/CD | Registry Docker | Issue Tracking | Wiki | Auto DevOps | Self-hosted | Prix |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| **GitLab CE** | ✅ Oui | ✅ Complet | ✅ Intégré | ✅ Avancé | ✅ Oui | ✅ Oui | ✅ Oui | Gratuit |
| **GitLab EE** | ✅ Oui | ✅ Avancé | ✅ Intégré | ✅ Enterprise | ✅ Oui | ✅ Oui | ✅ Oui | Payant |
| **GitHub** | ✅ Oui | ✅ Actions | ✅ GHCR | ✅ Basique | ✅ Oui | ❌ Non | ⚠️ Enterprise | Freemium |
| **Bitbucket** | ✅ Oui | ✅ Pipelines | ❌ Non | ✅ Jira | ✅ Oui | ❌ Non | ✅ Oui | Freemium |
| **Gitea** | ✅ Oui | ⚠️ Basique | ❌ Non | ✅ Basique | ✅ Oui | ❌ Non | ✅ Oui | Gratuit |
| **Azure DevOps** | ✅ Oui | ✅ Pipelines | ✅ ACR | ✅ Boards | ✅ Oui | ❌ Non | ⚠️ Server | Freemium |

### Rôle dans l'architecture DevOps

```
┌─────────────────────────────────────────────────────────────┐
│ Architecture GitLab DevOps Complète                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  VM : gitlab (172.16.100.30)                               │
│  ├─ GitLab Rails (Web UI + API)                            │
│  ├─ Gitaly (stockage Git repositories)                     │
│  ├─ PostgreSQL (métadonnées)                               │
│  ├─> Redis (cache + queues)                                │
│  ├─ Sidekiq (jobs asynchrones)                             │
│  ├─ GitLab Runner (exécution CI/CD)                        │
│  ├─ Container Registry (images Docker)                     │
│  └─ Nginx (reverse proxy HTTPS)                            │
│                                                             │
│  Workflow DevOps Complet :                                 │
│  1. Dev → git push code → GitLab                           │
│  2. GitLab → Trigger pipeline CI/CD (.gitlab-ci.yml)      │
│  3. Runner → Build image Docker                            │
│  4. Runner → Scan Trivy (sécurité)                         │
│  5. Runner → Push image vers Harbor                        │
│  6. Runner → Deploy Kubernetes/Docker                      │
│  7. GitLab → Monitoring pipeline (durée, succès/échec)    │
│  8. GitLab → Notifications (Slack, Email)                  │
│                                                             │
│  Intégrations :                                            │
│  ├─> Harbor (registry externe)                             │
│  ├─> Kubernetes (déploiement)                              │
│  ├─> Prometheus (monitoring)                               │
│  ├─> Slack (notifications)                                 │
│  └─> LDAP/SAML (authentification)                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```


***

## 📍 Cycle de vie : GitLab

### Phase 1 : Provisionnement VM GitLab (Terraform)

```
1. Création VM gitlab
   └─> Terraform provisionne VM
       ├─> Hostname : gitlab
       ├─> IP statique : 172.16.100.30
       ├─> CPU : 8 cores (recommandé GitLab)
       ├─> RAM : 16 GB (minimum production)
       └─> Disk : 200 GB (repos Git + artifacts + registry)

2. Cloud-init configure réseau
   └─> IP : 172.16.100.30/24
   └─> Gateway : 172.16.100.1
   └─> DNS : 172.16.100.254 (dns-server)
   └─> Hostname : gitlab.lab.local

3. VM disponible
   └─> Accessible via SSH
   └─> Prête pour installation GitLab
```


### Phase 2 : Installation GitLab (Ansible)

```
1. Ajout repository GitLab officiel
   └─> curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash
   └─> Repository ajouté : /etc/apt/sources.list.d/gitlab_gitlab-ce.list

2. Installation GitLab CE (Community Edition)
   └─> EXTERNAL_URL="https://gitlab.lab.local" apt install gitlab-ce
       ├─> Téléchargement packages (~1 GB)
       ├─> Installation dépendances (PostgreSQL, Redis, Nginx)
       ├─> Configuration initiale gitlab.rb
       └─> Premier reconfigure (gitlab-ctl reconfigure)

3. Configuration initiale automatique
   └─> GitLab services démarrés :
       ├─> postgresql (port 5432)
       ├─> redis (port 6379)
       ├─> gitaly (Git RPC service)
       ├─> sidekiq (background jobs)
       ├─> puma (Rails app server)
       ├─> nginx (HTTPS 443)
       └─> gitlab-runner (CI/CD - optionnel)

4. Génération password root
   └─> Password initial : /etc/gitlab/initial_root_password
   └─> Expire après 24h (change obligatoire)

5. Configuration SSL/TLS
   └─> Option A : Let's Encrypt (auto)
       └─> letsencrypt['enable'] = true
   └─> Option B : Auto-signé (lab)
       └─> Certificat généré : /etc/gitlab/ssl/gitlab.lab.local.crt
   └─> Option C : Certificat custom
       └─> Copier cert dans /etc/gitlab/ssl/

6. Configuration externe (gitlab.rb)
   └─> /etc/gitlab/gitlab.rb (fichier principal)
       ├─> external_url "https://gitlab.lab.local"
       ├─> PostgreSQL settings (shared buffers, connections)
       ├─> Redis settings (cache size)
       ├─> Sidekiq workers (concurrency)
       ├─> Gitaly settings (storage paths)
       ├─> Container Registry (activé)
       ├─> Email settings (SMTP)
       └─> Backup settings (cron schedule)

7. Reconfigure GitLab
   └─> gitlab-ctl reconfigure
       ├─> Génération configs templates
       ├─> Redémarrage services modifiés
       ├─> Migrations database PostgreSQL
       └─> Validation configuration

8. Accès Web UI
   └─> https://gitlab.lab.local
   └─> Login : root
   └─> Password : (voir /etc/gitlab/initial_root_password)
```


### Phase 3 : Configuration GitLab (Web UI)

```
1. Connexion root
   └─> https://gitlab.lab.local
   └─> Login : root / {{ initial_password }}
   └─> Change password obligatoire

2. Configuration générale
   └─> Admin Area → Settings → General
       ├─> Sign-up restrictions : ❌ Disabled (pas d'inscription libre)
       ├─> Sign-in restrictions : ✅ 2FA required (optionnel)
       ├─> Account and limit :
       │   ├─> Max attachment size : 100 MB
       │   ├─> Max push size : 500 MB
       │   └─> Session duration : 10080 min (7 jours)
       └─> Visibility and access controls :
           ├─> Default project visibility : Private
           ├─> Default group visibility : Private
           └─> Restricted visibility levels : None

3. Configuration CI/CD
   └─> Admin Area → Settings → CI/CD
       ├─> Continuous Integration :
       │   ├─> Default CI/CD configuration file : .gitlab-ci.yml
       │   ├─> Auto DevOps : ❌ Disabled (manuel)
       │   └─> Pipeline timeout : 1h
       ├─> Runners :
       │   ├─> Shared runners : ✅ Enabled
       │   └─> Runner registration token : (affiché)
       └─> Artifacts :
           ├─> Max size : 1 GB
           └─> Expiration : 30 days

4. Configuration Container Registry
   └─> Admin Area → Settings → CI/CD → Container Registry
       ├─> ✅ Enable Container Registry
       ├─> Registry external URL : https://registry.gitlab.lab.local
       └─> Cleanup policy : 14 days (images non taguées)

5. Configuration Email (SMTP)
   └─> /etc/gitlab/gitlab.rb
       └─> gitlab_rails['smtp_enable'] = true
           gitlab_rails['smtp_address'] = "smtp.lab.local"
           gitlab_rails['smtp_port'] = 587
           gitlab_rails['smtp_user_name'] = "gitlab@lab.local"
           gitlab_rails['smtp_password'] = "{{ smtp_password }}"
           gitlab_rails['smtp_domain'] = "lab.local"
           gitlab_rails['smtp_authentication'] = "login"
           gitlab_rails['smtp_enable_starttls_auto'] = true
           gitlab_rails['gitlab_email_from'] = 'gitlab@lab.local'

6. Création groupes et projets
   └─> Groups → New Group
       ├─> Name : "DevOps Team"
       ├─> Visibility : Private
       └─> Members : alice (Owner), bob (Developer)
   
   └─> Projects → New Project
       ├─> Name : "myapp"
       ├─> Group : DevOps Team
       ├─> Visibility : Private
       └─> Initialize with README : ✅

7. Configuration webhooks (Slack, Discord)
   └─> Project → Settings → Integrations
       ├─> Slack notifications :
       │   ├─> Webhook URL : https://hooks.slack.com/xxx
       │   ├─> Triggers : Push, Merge Request, Pipeline
       │   └─> Branches : main, develop
       └─> Discord notifications :
           └─> Webhook URL : https://discord.com/api/webhooks/xxx
```


### Phase 4 : Installation GitLab Runner (CI/CD)

```
1. Installation Runner (même VM ou VM dédiée)
   └─> curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash
   └─> apt install gitlab-runner

2. Enregistrement Runner auprès GitLab
   └─> gitlab-runner register
       ├─> GitLab URL : https://gitlab.lab.local
       ├─> Registration token : (depuis GitLab Admin → Runners)
       ├─> Description : "docker-runner-01"
       ├─> Tags : docker, linux, production
       ├─> Executor : docker
       └─> Default Docker image : docker:24-dind

3. Configuration Runner
   └─> /etc/gitlab-runner/config.toml
       └─> [[runners]]
             name = "docker-runner-01"
             url = "https://gitlab.lab.local"
             token = "xxx"
             executor = "docker"
             [runners.docker]
               image = "docker:24-dind"
               privileged = true
               volumes = ["/var/run/docker.sock:/var/run/docker.sock", "/cache"]
               pull_policy = "if-not-present"

4. Démarrage Runner
   └─> gitlab-runner start
   └─> Vérification : GitLab UI → Admin → Runners
       └─> ✅ docker-runner-01 (Active)

5. Test pipeline
   └─> Créer .gitlab-ci.yml dans projet
   └─> Git push → Pipeline déclenché
   └─> Runner exécute jobs
   └─> Résultat visible dans GitLab UI
```


### Phase 5 : Utilisation Quotidienne (Workflow Dev)

```
1. Développeur clone repo
   └─> git clone https://gitlab.lab.local/devops-team/myapp.git
   └─> cd myapp

2. Créer branche feature
   └─> git checkout -b feature/new-login
   └─> Édition code...
   └─> git add .
   └─> git commit -m "Add new login page"

3. Push branche vers GitLab
   └─> git push origin feature/new-login
   └─> GitLab détecte push
   └─> Pipeline CI/CD déclenché automatiquement

4. Pipeline exécution (.gitlab-ci.yml)
   └─> Stage 1 : Build
       ├─> docker build -t myapp:feature .
       └─> ✓ Succès
   
   └─> Stage 2 : Test
       ├─> npm run test
       ├─> npm run lint
       └─> ✓ Succès
   
   └─> Stage 3 : Security
       ├─> trivy fs .
       ├─> trivy image myapp:feature
       └─> ✓ Pas de CVE CRITICAL
   
   └─> Stage 4 : Deploy (preview)
       ├─> docker run -d myapp:feature
       └─> ✓ Environnement preview disponible

5. Créer Merge Request
   └─> GitLab UI → Create Merge Request
       ├─> Source : feature/new-login
       ├─> Target : main
       ├─> Assignee : Tech Lead
       ├─> Reviewers : alice, bob
       └─> Labels : feature, frontend

6. Code Review
   └─> alice/bob review code
   └─> Commentaires inline sur diff
   └─> Suggestions changements
   └─> Dev corrige → push → Pipeline rejoué

7. Approve et Merge
   └─> Reviewers approuvent (✓ Approved)
   └─> Tech Lead merge vers main
   └─> Pipeline production déclenché

8. Déploiement production
   └─> Stage 5 : Build Production
       └─> docker build -t myapp:v1.2.0 .
   
   └─> Stage 6 : Push Harbor
       └─> docker tag myapp:v1.2.0 harbor.lab.local/prod/myapp:v1.2.0
       └─> docker push harbor.lab.local/prod/myapp:v1.2.0
   
   └─> Stage 7 : Deploy Kubernetes
       └─> kubectl set image deployment/myapp myapp=harbor.lab.local/prod/myapp:v1.2.0
       └─> kubectl rollout status deployment/myapp
   
   └─> ✓ Déploiement production réussi

9. Tag release
   └─> git tag v1.2.0
   └─> git push origin v1.2.0
   └─> GitLab crée Release automatique
```


***

## 📍 Architecture GitLab Détaillée

### Diagramme de flux Git Push → CI/CD → Deploy

```
┌─────────────────────────────────────────────────────────────┐
│ Développeur (poste local)                                   │
├─────────────────────────────────────────────────────────────┤
│ • git add .                                                 │
│ • git commit -m "Fix login bug"                            │
│ • git push origin feature/fix-login                        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ HTTPS Git Push
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ GitLab Server (172.16.100.30)                               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Nginx (reverse proxy)                                  │
│     └─> Terminaison SSL                                     │
│     └─> Redirection vers GitLab Rails                      │
│                                                             │
│  2. GitLab Rails (Puma)                                    │
│     └─> Authentification (username/password ou token)      │
│     └─> Autorisation (user a-t-il droit push ?)           │
│     └─> Si OK → Transfert vers Gitaly                      │
│                                                             │
│  3. Gitaly (Git RPC service)                               │
│     └─> Réception objects Git (commits, trees, blobs)     │
│     └─> Stockage dans filesystem :                         │
│         /var/opt/gitlab/git-data/repositories/             │
│         └─> devops-team/myapp.git/                         │
│             ├─> objects/ (blobs, trees, commits)           │
│             ├─> refs/ (branches, tags)                     │
│             └─> hooks/ (pre-receive, post-receive)         │
│                                                             │
│  4. PostgreSQL (métadonnées)                               │
│     └─> Insertion enregistrement :                         │
│         ├─> Table : events                                 │
│         │   ├─> event_type : "pushed"                      │
│         │   ├─> user_id : 42                               │
│         │   ├─> project_id : 10                            │
│         │   ├─> ref : refs/heads/feature/fix-login         │
│         │   └─> timestamp : 2026-01-17 19:00:00            │
│         └─> Table : push_events                            │
│             ├─> commits_count : 1                          │
│             ├─> commit_sha : abc123...                     │
│             └─> commit_message : "Fix login bug"           │
│                                                             │
│  5. Redis (queues)                                         │
│     └─> Enqueue job "ProcessPushEvent"                     │
│         └─> Queue : pipeline_processing                    │
│                                                             │
│  6. Sidekiq (background worker)                            │
│     └─> Dequeue job "ProcessPushEvent"                     │
│     └─> Détection .gitlab-ci.yml dans repo                │
│     └─> Parse YAML → Extraction stages/jobs               │
│     └─> Création pipeline :                                │
│         ├─> pipeline_id : 1234                             │
│         ├─> status : "pending"                             │
│         ├─> stages : [build, test, deploy]                 │
│         └─> jobs : 5 jobs créés                            │
│                                                             │
│  7. Enqueue jobs CI/CD                                     │
│     └─> Redis queue : build:1                              │
│     └─> Redis queue : build:2                              │
│                                                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Job dispatch (HTTP API)
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ GitLab Runner (docker-runner-01)                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  8. Runner polling GitLab API                              │
│     └─> GET https://gitlab.lab.local/api/v4/jobs/request   │
│     └─> Headers : Authorization: Bearer RUNNER_TOKEN       │
│                                                             │
│  9. GitLab répond avec job                                 │
│     └─> Job ID : 5678                                       │
│     └─> Job name : "build"                                  │
│     └─> Script :                                           │
│         - docker build -t myapp:$CI_COMMIT_SHA .           │
│         - docker push harbor.lab.local/dev/myapp:$CI_COMMIT_SHA │
│     └─> Variables :                                        │
│         CI_COMMIT_SHA=abc123                               │
│         CI_PROJECT_NAME=myapp                              │
│                                                             │
│  10. Runner exécution job                                  │
│      └─> docker run --rm \                                 │
│          -v $PWD:/builds \                                 │
│          docker:24-dind \                                  │
│          sh -c "docker build -t myapp:abc123 ."            │
│                                                             │
│  11. Clone repository Git                                  │
│      └─> git clone https://gitlab-ci-token:xxx@gitlab.lab.local/devops-team/myapp.git
│      └─> git checkout abc123                              │
│                                                             │
│  12. Exécution scripts job                                 │
│      └─> $ docker build -t myapp:abc123 .                  │
│          ├─> Step 1/10 : FROM node:18-alpine              │
│          ├─> Step 2/10 : WORKDIR /app                      │
│          └─> ...                                           │
│          ✓ Build réussi                                    │
│                                                             │
│      └─> $ trivy image myapp:abc123                        │
│          ✓ Pas de CVE CRITICAL                             │
│                                                             │
│      └─> $ docker push harbor.lab.local/dev/myapp:abc123  │
│          ✓ Push réussi                                     │
│                                                             │
│  13. Streaming logs vers GitLab (temps réel)              │
│      └─> PATCH https://gitlab.lab.local/api/v4/jobs/5678/trace
│      └─> Body : logs stdout/stderr                        │
│                                                             │
│  14. Job terminé - Update status                          │
│      └─> PUT https://gitlab.lab.local/api/v4/jobs/5678    │
│      └─> Body : { "status": "success" }                    │
│                                                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Job result (HTTP API)
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ GitLab Server - Update Pipeline                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  15. PostgreSQL update                                     │
│      └─> Table : ci_builds                                 │
│          ├─> job_id : 5678                                 │
│          ├─> status : "success"                            │
│          ├─> finished_at : 2026-01-17 19:05:30             │
│          └─> duration : 330s                               │
│                                                             │
│  16. Check pipeline status                                 │
│      └─> Tous jobs stage "build" : ✓ success              │
│      └─> Déclencher stage suivant : "test"                │
│                                                             │
│  17. Enqueue jobs stage "test"                             │
│      └─> Redis queue : test:1                              │
│                                                             │
│  18. Runner exécute jobs "test"                            │
│      └─> npm run test                                       │
│      └─> npm run lint                                       │
│      └─> ✓ Tests passés                                    │
│                                                             │
│  19. Pipeline terminé                                      │
│      └─> Status : ✓ passed                                 │
│      └─> Duration : 8m 30s                                 │
│                                                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Notification
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Notifications                                               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  20. Webhook Slack                                         │
│      └─> POST https://hooks.slack.com/services/xxx         │
│      └─> Payload :                                         │
│          {                                                  │
│            "text": "✅ Pipeline #1234 passed",             │
│            "attachments": [{                               │
│              "color": "good",                              │
│              "fields": [                                    │
│                {"title": "Project", "value": "myapp"},     │
│                {"title": "Branch", "value": "feature/fix-login"},
│                {"title": "Duration", "value": "8m 30s"}    │
│              ]                                              │
│            }]                                               │
│          }                                                  │
│                                                             │
│  21. Email notification                                    │
│      └─> To : developer@lab.local                          │
│      └─> Subject : "[myapp] Pipeline #1234 passed"        │
│      └─> Body : HTML avec résumé pipeline                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```


### Architecture Stockage GitLab

```
/var/opt/gitlab/
├── git-data/                      # Repositories Git
│   └── repositories/
│       ├── @hashed/               # Git repos (hashed storage)
│       │   └── 6b/
│       │       └── 86/
│       │           └── 6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b.git/
│       │               ├── objects/        # Git objects
│       │               ├── refs/           # Branches, tags
│       │               ├── HEAD            # Current branch
│       │               └── config          # Repo config
│       │
│       └── @snippets/             # Code snippets
│
├── gitlab-rails/                  # Rails application data
│   ├── uploads/                   # User uploads (avatars, attachments)
│   ├── shared/
│   │   ├── artifacts/             # CI/CD artifacts (logs, binaries)
│   │   ├── lfs-objects/           # Git LFS objects (large files)
│   │   ├── packages/              # Package registry (npm, maven...)
│   │   ├── terraform_state/       # Terraform state files
│   │   └── pages/                 # GitLab Pages sites
│   │
│   └── tmp/                       # Temporary files
│
├── gitlab-ci/                     # CI/CD builds
│   └── builds/
│       └── docker-runner-01/
│           └── 0/                 # Runner concurrent jobs
│               └── myapp/         # Cloned repo
│
├── postgresql/                    # PostgreSQL database
│   └── data/
│       ├── base/                  # Database files
│       ├── pg_wal/                # Write-ahead logs
│       └── postgresql.conf        # PostgreSQL config
│
├── redis/                         # Redis cache
│   └── dump.rdb
│
├── registry/                      # Container Registry
│   └── docker/
│       └── registry/
│           └── v2/
│               ├── blobs/         # Image layers
│               └── repositories/  # Image manifests
│
├── backups/                       # GitLab backups
│   ├── 1705520400_2026_01_17_16.8.0_gitlab_backup.tar
│   └── ...
│
└── nginx/                         # Nginx configs
    └── conf/
        └── gitlab-http.conf
```


***

## 📍 Fichiers Configuration GitLab

### Fichier 1 : `/etc/gitlab/gitlab.rb` (Configuration principale)

**Chemin** : `/etc/gitlab/gitlab.rb`
**Rôle** : Configuration GitLab omnibus (fichier unique)
**Généré** : ✅ Ansible template

```ruby
# ===================================================================
# Configuration GitLab (généré par Ansible)
# Date : 2026-01-17
# ===================================================================

# ===================================================================
# 1. Configuration réseau externe
# ===================================================================
external_url 'https://gitlab.lab.local'

# Configuration Nginx (reverse proxy interne)
nginx['enable'] = true
nginx['listen_port'] = 443
nginx['listen_https'] = true
nginx['redirect_http_to_https'] = true

# SSL/TLS Certificats
nginx['ssl_certificate'] = "/etc/gitlab/ssl/gitlab.lab.local.crt"
nginx['ssl_certificate_key'] = "/etc/gitlab/ssl/gitlab.lab.local.key"

# SSL Protocols et Ciphers (sécurité)
nginx['ssl_protocols'] = "TLSv1.2 TLSv1.3"
nginx['ssl_ciphers'] = "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256"
nginx['ssl_prefer_server_ciphers'] = "on"

# HSTS (HTTP Strict Transport Security)
nginx['hsts_max_age'] = 31536000
nginx['hsts_include_subdomains'] = false

# ===================================================================
# 2. Configuration PostgreSQL (database)
# ===================================================================
postgresql['enable'] = true
postgresql['shared_buffers'] = "4GB"        # 25% de RAM
postgresql['effective_cache_size'] = "12GB" # 75% de RAM
postgresql['max_connections'] = 200
postgresql['work_mem'] = "16MB"
postgresql['maintenance_work_mem'] = "512MB"
postgresql['checkpoint_completion_target'] = 0.9
postgresql['wal_buffers'] = "16MB"
postgresql['default_statistics_target'] = 100
postgresql['random_page_cost'] = 1.1
postgresql['effective_io_concurrency'] = 200
postgresql['min_wal_size'] = "1GB"
postgresql['max_wal_size'] = "4GB"

# Connexions PostgreSQL
postgresql['listen_address'] = '127.0.0.1'
postgresql['port'] = 5432

# ===================================================================
# 3. Configuration Redis (cache et queues)
# ===================================================================
redis['enable'] = true
redis['bind'] = '127.0.0.1'
redis['port'] = 6379
redis['maxmemory'] = '2GB'
redis['maxmemory_policy'] = 'allkeys-lru'
redis['save'] = ['900 1', '300 10', '60 10000']  # Persistence RDB

# ===================================================================
# 4. Configuration Gitaly (Git RPC)
# ===================================================================
gitaly['enable'] = true
gitaly['configuration'] = {
  storage: [
    {
      name: 'default',
      path: '/var/opt/gitlab/git-data/repositories'
    }
  ],
  concurrency: [
    {
      rpc: '/gitaly.SmartHTTPService/PostReceivePack',
      max_per_repo: 20
    },
    {
      rpc: '/gitaly.SSHService/SSHUploadPack',
      max_per_repo: 20
    }
  ]
}

# ===================================================================
# 5. Configuration Sidekiq (background jobs)
# ===================================================================
sidekiq['enable'] = true
sidekiq['concurrency'] = 25  # Nombre workers parallèles

# Queues Sidekiq (priorités)
sidekiq['queue_groups'] = [
  'urgent',      # Jobs critiques
  'default',     # Jobs normaux
  'low'          # Jobs non urgents
]

# ===================================================================
# 6. Configuration GitLab Rails (application)
# ===================================================================
gitlab_rails['time_zone'] = 'Europe/Paris'

# Limites uploads
gitlab_rails['max_attachment_size'] = 100  # MB
gitlab_rails['max_import_size'] = 500      # MB

# Session expiration
gitlab_rails['session_expire_delay'] = 10080  # 7 jours (minutes)

# Email configuration (SMTP)
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "smtp.lab.local"
gitlab_rails['smtp_port'] = 587
gitlab_rails['smtp_user_name'] = "gitlab@lab.local"
gitlab_rails['smtp_password'] = "{{ smtp_password }}"
gitlab_rails['smtp_domain'] = "lab.local"
gitlab_rails['smtp_authentication'] = "login"
gitlab_rails['smtp_enable_starttls_auto'] = true
gitlab_rails['smtp_tls'] = false
gitlab_rails['smtp_openssl_verify_mode'] = 'peer'

# Email from
gitlab_rails['gitlab_email_from'] = 'gitlab@lab.local'
gitlab_rails['gitlab_email_display_name'] = 'GitLab'
gitlab_rails['gitlab_email_reply_to'] = 'noreply@lab.local'

# ===================================================================
# 7. Configuration Container Registry (Docker)
# ===================================================================
registry_external_url 'https://registry.gitlab.lab.local'

registry['enable'] = true
registry['registry_http_addr'] = "0.0.0.0:5000"

# Stockage Registry
registry['storage'] = {
  'filesystem' => {
    'rootdirectory' => '/var/opt/gitlab/gitlab-rails/shared/registry'
  }
}

# Garbage Collection automatique
registry['gc_enabled'] = true
registry['gc_time'] = '02:00'  # 2h du matin

# ===================================================================
# 8. Configuration CI/CD
# ===================================================================
gitlab_rails['gitlab_default_projects_features_builds'] = true
gitlab_rails['gitlab_default_projects_features_container_registry'] = true

# Artifacts CI/CD
gitlab_rails['artifacts_enabled'] = true
gitlab_rails['artifacts_path'] = "/var/opt/gitlab/gitlab-rails/shared/artifacts"
gitlab_rails['artifacts_object_store_enabled'] = false

# Expiration artifacts par défaut
gitlab_rails['expire_build_artifacts_worker_cron'] = "50 * * * *"  # Toutes les heures

# LFS (Large File Storage)
gitlab_rails['lfs_enabled'] = true
gitlab_rails['lfs_storage_path'] = "/var/opt/gitlab/gitlab-rails/shared/lfs-objects"

# ===================================================================
# 9. Configuration Backup
# ===================================================================
gitlab_rails['manage_backup_path'] = true
gitlab_rails['backup_path'] = "/var/opt/gitlab/backups"
gitlab_rails['backup_keep_time'] = 604800  # 7 jours (secondes)

# Schedule backup automatique (cron)
gitlab_rails['backup_cron_enable'] = true
gitlab_rails['backup_cron_minute'] = "0"
gitlab_rails['backup_cron_hour'] = "2"    # 2h du matin
gitlab_rails['backup_cron_day'] = "*"
gitlab_rails['backup_cron_month'] = "*"
gitlab_rails['backup_cron_weekday'] = "*"

# ===================================================================
# 10. Configuration Monitoring (Prometheus)
# ===================================================================
prometheus['enable'] = true
prometheus['listen_address'] = '0.0.0.0:9090'
prometheus['scrape_interval'] = 15  # secondes
prometheus['scrape_timeout'] = 15

# Exporters Prometheus
node_exporter['enable'] = true
postgres_exporter['enable'] = true
redis_exporter['enable'] = true
gitlab_exporter['enable'] = true

# ===================================================================
# 11. Configuration Authentification
# ===================================================================
# Inscription libre désactivée
gitlab_rails['gitlab_signup_enabled'] = false

# 2FA (Two-Factor Authentication)
gitlab_rails['require_two_factor_authentication'] = false
gitlab_rails['two_factor_grace_period'] = 48  # heures

# LDAP (optionnel)
# gitlab_rails['ldap_enabled'] = true
# gitlab_rails['ldap_servers'] = {
#   'main' => {
#     'label' => 'LDAP',
#     'host' => 'ldap.lab.local',
#     'port' => 389,
#     'uid' => 'uid',
#     'bind_dn' => 'cn=admin,dc=lab,dc=local',
#     'password' => '{{ ldap_password }}',
#     'encryption' => 'plain',
#     'verify_certificates' => true,
#     'active_directory' => false,
#     'base' => 'ou=users,dc=lab,dc=local',
#     'user_filter' => '(objectClass=posixAccount)'
#   }
# }

# SAML (optionnel)
# gitlab_rails['omniauth_enabled'] = true
# gitlab_rails['omniauth_allow_single_sign_on'] = ['saml']
# gitlab_rails['omniauth_block_auto_created_users'] = false
# gitlab_rails['omniauth_providers'] = [
#   {
#     name: 'saml',
#     args: {
#       assertion_consumer_service_url: 'https://gitlab.lab.local/users/auth/saml/callback',
#       idp_cert_fingerprint: 'XX:XX:XX:...',
#       idp_sso_target_url: 'https://sso.lab.local/saml',
#       issuer: 'https://gitlab.lab.local',
#       name_identifier_format: 'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent'
#     },
#     label: 'Company SSO'
#   }
# ]

# ===================================================================
# 12. Configuration Sécurité
# ===================================================================
# Rate limiting (protection DDoS)
gitlab_rails['rack_attack_git_basic_auth'] = {
  'enabled' => true,
  'ip_whitelist' => ["127.0.0.1"],
  'maxretry' => 10,
  'findtime' => 60,
  'bantime' => 3600
}

# Password policy
gitlab_rails['password_minimum_length'] = 12
gitlab_rails['password_required_special_char'] = true
gitlab_rails['password_required_uppercase'] = true
gitlab_rails['password_required_lowercase'] = true
gitlab_rails['password_required_number'] = true

# ===================================================================
# 13. Configuration Performance
# ===================================================================
# Puma (Rails app server)
puma['enable'] = true
puma['worker_processes'] = 4
puma['max_threads'] = 4
puma['worker_timeout'] = 60

# Unicorn (ancien - désactivé si Puma activé)
unicorn['enable'] = false

# ===================================================================
# 14. Configuration Logs
# ===================================================================
logging['logrotate_frequency'] = "daily"
logging['logrotate_size'] = "200M"
logging['logrotate_rotate'] = 30  # Conserver 30 jours
logging['logrotate_compress'] = "compress"
logging['logrotate_method'] = "copytruncate"
logging['logrotate_delaycompress'] = "delaycompress"

# Log level
logging['svlogd_size'] = 200 * 1024 * 1024  # 200 MB
logging['svlogd_num'] = 30
logging['svlogd_timeout'] = 24 * 60 * 60
logging['svlogd_filter'] = "gzip"
logging['svlogd_udp'] = nil
logging['svlogd_prefix'] = nil

# ===================================================================
# 15. Configuration Pages (GitLab Pages)
# ===================================================================
pages_external_url 'https://pages.lab.local'
gitlab_pages['enable'] = false  # Désactivé (optionnel)

# ===================================================================
# 16. Configuration Terraform State
# ===================================================================
gitlab_rails['terraform_state_enabled'] = true
gitlab_rails['terraform_state_storage_path'] = "/var/opt/gitlab/gitlab-rails/shared/terraform_state"

# ===================================================================
# 17. Configuration Package Registry
# ===================================================================
gitlab_rails['packages_enabled'] = true
gitlab_rails['packages_storage_path'] = "/var/opt/gitlab/gitlab-rails/shared/packages"

# Npm registry
gitlab_rails['npm_package_registry_enabled'] = true

# Maven registry
gitlab_rails['maven_package_registry_enabled'] = true

# PyPI registry
gitlab_rails['pypi_package_registry_enabled'] = true

# ===================================================================
# FIN CONFIGURATION
# ===================================================================
```

**Application configuration** :

```bash
# Vérifier syntax
gitlab-ctl check-config

# Reconfigure GitLab (appliquer changements)
gitlab-ctl reconfigure

# Restart services
gitlab-ctl restart
```


***

### Fichier 2 : `.gitlab-ci.yml` (Pipeline CI/CD)

**Chemin** : `./.gitlab-ci.yml` (racine projet Git)
**Rôle** : Définition pipeline CI/CD
**Généré** : ✅ Manuel (développeur)

```yaml
# ===================================================================
# Pipeline CI/CD GitLab
# ===================================================================

# ===================================================================
# Variables globales
# ===================================================================
variables:
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: "/certs"
  HARBOR_REGISTRY: harbor.lab.local
  IMAGE_NAME: $HARBOR_REGISTRY/prod/$CI_PROJECT_NAME
  KUBERNETES_NAMESPACE: production

# ===================================================================
# Stages (ordre exécution)
# ===================================================================
stages:
  - build
  - test
  - security
  - publish
  - deploy
  - cleanup

# ===================================================================
# Templates réutilisables
# ===================================================================
.docker_template: &docker_template
  image: docker:24-dind
  services:
    - docker:24-dind
  before_script:
    - docker login -u $HARBOR_USER -p $HARBOR_PASSWORD $HARBOR_REGISTRY

# ===================================================================
# Stage 1 : Build Application
# ===================================================================
build:app:
  <<: *docker_template
  stage: build
  script:
    # Build image Docker
    - docker build -t $IMAGE_NAME:$CI_COMMIT_SHA .
    - docker tag $IMAGE_NAME:$CI_COMMIT_SHA $IMAGE_NAME:latest
    
    # Save image (artifact pour stages suivants)
    - docker save $IMAGE_NAME:$CI_COMMIT_SHA -o image.tar
  
  artifacts:
    paths:
      - image.tar
    expire_in: 1 hour
  
  tags:
    - docker
    - linux
  
  only:
    - branches
    - tags

# ===================================================================
# Stage 2 : Tests Unitaires
# ===================================================================
test:unit:
  image: node:18-alpine
  stage: test
  script:
    # Install dependencies
    - npm ci
    
    # Run tests
    - npm run test:unit
    
    # Generate coverage report
    - npm run test:coverage
  
  artifacts:
    reports:
      junit: junit.xml
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml
    paths:
      - coverage/
    expire_in: 30 days
  
  coverage: '/Lines\s*:\s*(\d+\.\d+)%/'
  
  tags:
    - docker
  
  only:
    - merge_requests
    - main

test:integration:
  image: node:18-alpine
  stage: test
  services:
    - postgres:15-alpine
    - redis:7-alpine
  
  variables:
    POSTGRES_DB: testdb
    POSTGRES_USER: testuser
    POSTGRES_PASSWORD: testpass
    DATABASE_URL: postgresql://testuser:testpass@postgres:5432/testdb
    REDIS_URL: redis://redis:6379
  
  script:
    - npm ci
    - npm run test:integration
  
  tags:
    - docker
  
  only:
    - merge_requests
    - main

test:e2e:
  image: cypress/included:13.0.0
  stage: test
  script:
    # Run Cypress E2E tests
    - cypress run --browser chrome
  
  artifacts:
    when: on_failure
    paths:
      - cypress/screenshots/
      - cypress/videos/
    expire_in: 7 days
  
  tags:
    - docker
  
  only:
    - merge_requests
    - main

# ===================================================================
# Stage 3 : Sécurité (SAST, DAST, Trivy)
# ===================================================================
security:trivy-fs:
  image: aquasec/trivy:latest
  stage: security
  script:
    # Scan filesystem (dependencies)
    - trivy fs --exit-code 0 --severity CRITICAL,HIGH --format json -o trivy-fs-report.json .
    
    # Display results
    - trivy fs --severity CRITICAL,HIGH .
  
  artifacts:
    reports:
      dependency_scanning: trivy-fs-report.json
    paths:
      - trivy-fs-report.json
    expire_in: 30 days
  
  tags:
    - docker
  
  allow_failure: true
  
  only:
    - merge_requests
    - main

security:trivy-image:
  <<: *docker_template
  stage: security
  dependencies:
    - build:app
  script:
    # Load image from artifact
    - docker load -i image.tar
    
    # Scan image Docker
    - trivy image --exit-code 1 --severity CRITICAL --format json -o trivy-image-report.json $IMAGE_NAME:$CI_COMMIT_SHA
    
    # Display results
    - trivy image --severity CRITICAL,HIGH $IMAGE_NAME:$CI_COMMIT_SHA
  
  artifacts:
    reports:
      container_scanning: trivy-image-report.json
    paths:
      - trivy-image-report.json
    expire_in: 30 days
  
  tags:
    - docker
  
  allow_failure: false  # FAIL si CVE CRITICAL
  
  only:
    - merge_requests
    - main

security:secrets:
  image: aquasec/trivy:latest
  stage: security
  script:
    # Scan secrets hardcodés
    - trivy repo --scanners secret --exit-code 1 .
  
  tags:
    - docker
  
  allow_failure: false
  
  only:
    - merge_requests
    - main

sast:
  stage: security
  image: returntocorp/semgrep:latest
  script:
    # SAST (Static Application Security Testing)
    - semgrep --config=auto --json -o semgrep-report.json .
  
  artifacts:
    reports:
      sast: semgrep-report.json
    paths:
      - semgrep-report.json
    expire_in: 30 days
  
  tags:
    - docker
  
  allow_failure: true
  
  only:
    - merge_requests
    - main

# ===================================================================
# Stage 4 : Publish vers Harbor
# ===================================================================
publish:harbor:
  <<: *docker_template
  stage: publish
  dependencies:
    - build:app
  script:
    # Load image
    - docker load -i image.tar
    
    # Tag version
    - |
      if [ "$CI_COMMIT_TAG" ]; then
        docker tag $IMAGE_NAME:$CI_COMMIT_SHA $IMAGE_NAME:$CI_COMMIT_TAG
        docker push $IMAGE_NAME:$CI_COMMIT_TAG
      fi
    
    # Tag latest (si branche main)
    - |
      if [ "$CI_COMMIT_BRANCH" == "main" ]; then
        docker tag $IMAGE_NAME:$CI_COMMIT_SHA $IMAGE_NAME:latest
        docker push $IMAGE_NAME:latest
      fi
    
    # Push SHA
    - docker push $IMAGE_NAME:$CI_COMMIT_SHA
  
  tags:
    - docker
  
  only:
    - main
    - tags

# ===================================================================
# Stage 5 : Deploy
# ===================================================================
deploy:staging:
  image: bitnami/kubectl:latest
  stage: deploy
  environment:
    name: staging
    url: https://staging-myapp.lab.local
    on_stop: cleanup:staging
  
  script:
    # Configure kubectl
    - kubectl config use-context lab/k8s-cluster
    
    # Deploy vers Kubernetes
    - kubectl set image deployment/myapp myapp=$IMAGE_NAME:$CI_COMMIT_SHA -n staging
    - kubectl rollout status deployment/myapp -n staging --timeout=5m
    
    # Vérifier health
    - kubectl get pods -n staging -l app=myapp
  
  tags:
    - docker
  
  only:
    - main
  
  when: manual

deploy:production:
  image: bitnami/kubectl:latest
  stage: deploy
  environment:
    name: production
    url: https://myapp.lab.local
  
  script:
    - kubectl config use-context lab/k8s-cluster
    - kubectl set image deployment/myapp myapp=$IMAGE_NAME:$CI_COMMIT_TAG -n production
    - kubectl rollout status deployment/myapp -n production --timeout=10m
    - kubectl get pods -n production -l app=myapp
  
  tags:
    - docker
  
  only:
    - tags
  
  when: manual

# ===================================================================
# Stage 6 : Cleanup
# ===================================================================
cleanup:staging:
  image: bitnami/kubectl:latest
  stage: cleanup
  environment:
    name: staging
    action: stop
  
  script:
    - kubectl delete namespace staging --ignore-not-found
  
  tags:
    - docker
  
  when: manual

cleanup:artifacts:
  stage: cleanup
  script:
    - rm -f image.tar
  
  tags:
    - docker
  
  when: always
```


***

### Fichier 3 : `/etc/gitlab-runner/config.toml` (Config Runner)

**Chemin** : `/etc/gitlab-runner/config.toml`
**Rôle** : Configuration GitLab Runner
**Généré** : ✅ `gitlab-runner register`

```toml
# ===================================================================
# Configuration GitLab Runner
# ===================================================================

concurrent = 4  # Nombre de jobs parallèles max
check_interval = 3  # Polling interval (secondes)
log_level = "info"
shutdown_timeout = 0

# ===================================================================
# Session server (terminal interactif debug)
# ===================================================================
[session_server]
  session_timeout = 1800

# ===================================================================
# Runner 1 : Docker executor
# ===================================================================
[[runners]]
  name = "docker-runner-01"
  url = "https://gitlab.lab.local"
  id = 1
  token = "{{ runner_token }}"
  token_obtained_at = 2026-01-17T12:00:00Z
  token_expires_at = 0001-01-01T00:00:00Z
  executor = "docker"
  
  # Tags runner (filtre jobs)
  tags = ["docker", "linux", "production"]
  
  # Configuration Docker
  [runners.docker]
    tls_verify = false
    image = "docker:24-dind"
    privileged = true  # Requis pour Docker-in-Docker
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    
    # Volumes montés
    volumes = [
      "/var/run/docker.sock:/var/run/docker.sock",
      "/cache"
    ]
    
    # Pull policy
    pull_policy = ["if-not-present"]
    
    # Registry mirror (accélérer pulls)
    # allowed_pull_policies = ["always", "if-not-present", "never"]
    
    # Shared cache
    shm_size = 0
    
    # Network mode
    network_mode = "bridge"
    
    # DNS
    dns = ["172.16.100.254", "1.1.1.1"]
    
    # Extra hosts
    extra_hosts = ["harbor.lab.local:172.16.100.2"]
    
    # Limites ressources
    cpus = "2"
    memory = "4g"
    memory_swap = "4g"
    
    # Timeout
    wait_for_services_timeout = 300
  
  # Cache configuration
  [runners.cache]
    Type = "local"
    Path = "/cache"
    Shared = true
    
    [runners.cache.local]
      MaxUploadedArchiveSize = 0
  
  # Feature flags
  [runners.feature_flags]
    FF_USE_DIRECT_DOWNLOAD = true
    FF_SKIP_NOOP_BUILD_STAGES = true

# ===================================================================
# Runner 2 : Shell executor (optionnel - scripts bash)
# ===================================================================
[[runners]]
  name = "shell-runner-01"
  url = "https://gitlab.lab.local"
  id = 2
  token = "{{ runner_token_shell }}"
  executor = "shell"
  
  tags = ["shell", "scripts"]
  
  [runners.cache]
    Type = "local"
    Path = "/tmp/runner-cache"
    Shared = false

# ===================================================================
# Runner 3 : Kubernetes executor (optionnel - cluster K8s)
# ===================================================================
# [[runners]]
#   name = "k8s-runner-01"
#   url = "https://gitlab.lab.local"
#   token = "{{ runner_token_k8s }}"
#   executor = "kubernetes"
#   
#   tags = ["kubernetes", "k8s"]
#   
#   [runners.kubernetes]
#     host = "https://k8s-api.lab.local:6443"
#     namespace = "gitlab-runner"
#     image = "alpine:latest"
#     privileged = true
#     
#     # Resources limites
#     cpu_limit = "2"
#     memory_limit = "4Gi"
#     service_cpu_limit = "1"
#     service_memory_limit = "2Gi"
#     helper_cpu_limit = "500m"
#     helper_memory_limit = "512Mi"
#     
#     # Volumes
#     [[runners.kubernetes.volumes.host_path]]
#       name = "docker-sock"
#       mount_path = "/var/run/docker.sock"
#       host_path = "/var/run/docker.sock"
```

**Application configuration** :

```bash
# Restart runner
gitlab-runner restart

# Vérifier status
gitlab-runner status

# Vérifier runners enregistrés
gitlab-runner list
```


***

## 📊 Commandes Maintenance GitLab

### 🔍 Status et Monitoring

#### Vérifier status services

```bash
# Status global
gitlab-ctl status

# Output :
# run: gitaly: (pid 1234) 50000s; run: log: (pid 5678) 50000s
# run: gitlab-workhorse: (pid 2345) 50000s
# run: logrotate: (pid 3456) 3600s; run: log: (pid 4567) 3600s
# run: nginx: (pid 5678) 50000s; run: log: (pid 6789) 50000s
# run: postgresql: (pid 7890) 50000s; run: log: (pid 8901) 50000s
# run: redis: (pid 9012) 50000s; run: log: (pid 1123) 50000s
# run: sidekiq: (pid 2234) 50000s; run: log: (pid 3345) 50000s

# Status service spécifique
gitlab-ctl status nginx
gitlab-ctl status postgresql
gitlab-ctl status sidekiq
```


#### Logs services

```bash
# Tail logs tous services
gitlab-ctl tail

# Logs service spécifique
gitlab-ctl tail nginx
gitlab-ctl tail postgresql
gitlab-ctl tail sidekiq
gitlab-ctl tail gitaly

# Logs avec grep
gitlab-ctl tail nginx | grep ERROR

# Logs fichiers (sans gitlab-ctl)
tail -f /var/log/gitlab/nginx/gitlab_access.log
tail -f /var/log/gitlab/nginx/gitlab_error.log
tail -f /var/log/gitlab/postgresql/current
tail -f /var/log/gitlab/sidekiq/current
```


#### Vérifier santé GitLab

```bash
# Health check HTTP
curl -k https://gitlab.lab.local/-/health

# Readiness check
curl -k https://gitlab.lab.local/-/readiness

# Liveness check
curl -k https://gitlab.lab.local/-/liveness

# GitLab doctor (diagnostic complet)
gitlab-rake gitlab:check

# Check database
gitlab-rake gitlab:db:check

# Check repositories
gitlab-rake gitlab:git:fsck
```


***

### 🔄 Gestion Services

#### Contrôle services

```bash
# Restart tous services
gitlab-ctl restart

# Restart service spécifique
gitlab-ctl restart nginx
gitlab-ctl restart puma
gitlab-ctl restart sidekiq

# Stop/Start
gitlab-ctl stop
gitlab-ctl start

# Stop service spécifique
gitlab-ctl stop sidekiq
gitlab-ctl start sidekiq

# Reconfigure (appliquer changements gitlab.rb)
gitlab-ctl reconfigure

# Reload (sans restart - nginx, postgresql)
gitlab-ctl hup nginx
```


#### Maintenance GitLab

```bash
# Vérifier configuration avant reconfigure
gitlab-ctl check-config

# Vérifier version GitLab
gitlab-rake gitlab:env:info

# Upgrade GitLab
apt update
apt install gitlab-ce

# Migration database après upgrade
gitlab-rake db:migrate

# Clear cache
gitlab-rake cache:clear
```


***

### 👥 Gestion Utilisateurs

#### Créer utilisateur via CLI

```bash
# Créer user
gitlab-rake "gitlab:users:create[alice,alice@lab.local,Alice Smith,password123]"

# Changer password
gitlab-rake "gitlab:password:reset[alice]"

# Lister users
gitlab-rake gitlab:users:list

# Désactiver user
gitlab-rake "gitlab:users:disable[alice]"

# Activer user
gitlab-rake "gitlab:users:enable[alice]"
```


#### Reset password root

```bash
# Console GitLab Rails
gitlab-rails console

# Dans console Ruby :
user = User.find_by(username: 'root')
user.password = 'newpassword123'
user.password_confirmation = 'newpassword123'
user.save!
exit
```


***

### 📦 Gestion Projets et Repositories

#### Lister projets

```bash
# Via CLI
gitlab-rake gitlab:projects:list

# Via API
curl -k --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  https://gitlab.lab.local/api/v4/projects | jq
```


#### Import projet

```bash
# Import depuis archive .tar.gz
gitlab-rake gitlab:import:project[group_path,project_name,/path/to/export.tar.gz]

# Import depuis Git URL
curl -k --request POST --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{
    "name": "imported-project",
    "namespace_id": 2,
    "import_url": "https://github.com/user/repo.git"
  }' \
  https://gitlab.lab.local/api/v4/projects
```


#### Export projet

```bash
# Via API
curl -k --request POST --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  https://gitlab.lab.local/api/v4/projects/10/export

# Attendre export terminé
curl -k --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  https://gitlab.lab.local/api/v4/projects/10/export | jq .export_status

# Download export
curl -k --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  https://gitlab.lab.local/api/v4/projects/10/export/download -o project-export.tar.gz
```


***

### 💾 Backup et Restore

#### Backup complet GitLab

```bash
# Backup automatique (configuré dans gitlab.rb)
# Schedule : 2h du matin (gitlab_rails['backup_cron_hour'] = "2")

# Backup manuel
gitlab-backup create

# Backup avec timestamp personnalisé
gitlab-backup create BACKUP=2026-01-17_manual

# Backup uniquement database
gitlab-backup create SKIP=repositories,uploads,builds,artifacts,lfs,registry,pages

# Backup uniquement repositories
gitlab-backup create SKIP=db,uploads,builds,artifacts,lfs,registry,pages

# Lister backups
ls -lh /var/opt/gitlab/backups/
# 1705520400_2026_01_17_16.8.0_gitlab_backup.tar
```


#### Restore backup

```bash
# Arrêter services (garder PostgreSQL et Redis actifs)
gitlab-ctl stop puma
gitlab-ctl stop sidekiq

# Restore backup
gitlab-backup restore BACKUP=1705520400_2026_01_17_16.8.0

# Confirmer restore (tape "yes")

# Redémarrer services
gitlab-ctl restart

# Vérifier santé
gitlab-rake gitlab:check SANITIZE=true
```


#### Backup configuration

```bash
# Backup /etc/gitlab/ (gitlab.rb, ssl certs...)
tar -czf /backup/gitlab-config-$(date +%Y%m%d).tar.gz /etc/gitlab/

# Backup secrets (clés encryption)
gitlab-rake gitlab:backup:create SKIP=repositories,uploads,builds,artifacts,lfs,registry,pages,db
```


***

### 🏃 Gestion GitLab Runner

#### Status Runner

```bash
# Vérifier runner actif
gitlab-runner status

# Lister runners enregistrés
gitlab-runner list

# Vérifier runners depuis GitLab UI
# Admin Area → CI/CD → Runners
```


#### Enregistrer nouveau runner

```bash
# Enregistrement interactif
gitlab-runner register

# Prompts :
# GitLab URL : https://gitlab.lab.local
# Registration token : (depuis GitLab UI)
# Description : docker-runner-02
# Tags : docker,linux
# Executor : docker
# Default image : docker:24-dind
```


#### Unregister runner

```bash
# Unregister runner spécifique
gitlab-runner unregister --name docker-runner-01

# Unregister tous runners
gitlab-runner unregister --all-runners
```


#### Logs Runner

```bash
# Logs temps réel
gitlab-runner --debug run

# Logs systemd
journalctl -u gitlab-runner -f

# Logs fichier (si configuré)
tail -f /var/log/gitlab-runner/gitlab-runner.log
```


***

### 🐳 Gestion Container Registry

#### Lister images registry

```bash
# Via API
curl -k --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  https://gitlab.lab.local/api/v4/projects/10/registry/repositories | jq

# Lister tags d'une image
curl -k --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  https://gitlab.lab.local/api/v4/projects/10/registry/repositories/1/tags | jq
```


#### Supprimer images registry

```bash
# Delete tag spécifique (via API)
curl -k --request DELETE --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  https://gitlab.lab.local/api/v4/projects/10/registry/repositories/1/tags/v1.0.0

# Cleanup images automatique (Garbage Collection)
# Via UI : Project → Settings → CI/CD → Container Registry
# Cleanup policy : 14 days, keep 10 tags
```


#### Garbage Collection registry

```bash
# Manuellement (offline)
gitlab-ctl stop registry
gitlab-ctl registry-garbage-collect
gitlab-ctl start registry

# Automatique (configuré dans gitlab.rb)
# registry['gc_enabled'] = true
# registry['gc_time'] = '02:00'  # 2h matin
```


***

### 📊 Monitoring et Métriques

#### Métriques Prometheus

```bash
# Accès Prometheus intégré
http://gitlab.lab.local:9090

# Métriques GitLab
curl http://localhost:9090/metrics

# Métriques importantes :
# gitlab_database_rows (nombre enregistrements DB)
# gitlab_cache_operations_total (ops Redis)
# gitlab_repository_count (nombre repos Git)
# gitlab_transaction_duration_seconds (latence requests)
```


#### Performance database

```bash
# Console PostgreSQL
gitlab-psql -d gitlabhq_production

# Requêtes lentes
SELECT query, calls, mean_exec_time 
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC 
LIMIT 10;

# Taille database
SELECT pg_size_pretty(pg_database_size('gitlabhq_production'));

# Vacuum database (maintenance)
gitlab-rake gitlab:db:vacuum

# Reindex database
gitlab-rake gitlab:db:reindex
```


#### Performance Sidekiq

```bash
# Vérifier queues Sidekiq
gitlab-rails runner 'pp Sidekiq::Queue.all.map(&:name)'

# Nombre jobs en attente
gitlab-rails runner 'pp Sidekiq::Queue.new("default").size'

# Clear queue (DANGER)
gitlab-rails runner 'Sidekiq::Queue.new("default").clear'
```


***

### 🔐 Sécurité

#### Générer token API

```bash
# Via Rails console
gitlab-rails console

# Créer personal access token
user = User.find_by(username: 'alice')
token = user.personal_access_tokens.create(
  name: 'api-token',
  scopes: ['api', 'read_repository', 'write_repository'],
  expires_at: 1.year.from_now
)
puts token.token
exit
```


#### Rotate secrets

```bash
# Rotate secret_key_base (sessions)
gitlab-rake gitlab:env:info | grep secret_key_base

# Regenerate secrets
gitlab-rake gitlab:generate_secrets

# Reconfigure
gitlab-ctl reconfigure
```


#### Scan sécurité

```bash
# Check permissions fichiers
gitlab-rake gitlab:check:permissions

# Check Git storage
gitlab-rake gitlab:git:fsck

# Check LDAP
gitlab-rake gitlab:ldap:check
```


***

## 🎯 Use Cases Avancés

### 🔄 Multi-Runner Architecture

```yaml
# /etc/gitlab-runner/config.toml
concurrent = 10  # 10 jobs parallèles

# Runner 1 : Docker (build images)
[[runners]]
  name = "docker-builder"
  executor = "docker"
  tags = ["docker", "build"]
  
# Runner 2 : Kubernetes (deploy)
[[runners]]
  name = "k8s-deployer"
  executor = "kubernetes"
  tags = ["kubernetes", "deploy"]

# Runner 3 : Shell (scripts)
[[runners]]
  name = "shell-executor"
  executor = "shell"
  tags = ["shell", "scripts"]
```


### 🔗 Intégration Harbor Registry

```yaml
# .gitlab-ci.yml
variables:
  HARBOR_REGISTRY: harbor.lab.local
  CI_REGISTRY: $HARBOR_REGISTRY  # Override GitLab registry

build:
  script:
    - docker login -u $HARBOR_USER -p $HARBOR_PASSWORD $HARBOR_REGISTRY
    - docker build -t $HARBOR_REGISTRY/prod/$CI_PROJECT_NAME:$CI_COMMIT_TAG .
    - docker push $HARBOR_REGISTRY/prod/$CI_PROJECT_NAME:$CI_COMMIT_TAG
```


### 📧 Notifications Slack/Discord

```yaml
# .gitlab-ci.yml
after_script:
  - |
    if [ "$CI_JOB_STATUS" == "success" ]; then
      COLOR="good"
      EMOJI="✅"
    else
      COLOR="danger"
      EMOJI="❌"
    fi
    
    curl -X POST $SLACK_WEBHOOK \
      -H 'Content-Type: application/json' \
      -d "{
        \"attachments\": [{
          \"color\": \"$COLOR\",
          \"text\": \"$EMOJI Pipeline #$CI_PIPELINE_ID $CI_JOB_STATUS\",
          \"fields\": [
            {\"title\": \"Project\", \"value\": \"$CI_PROJECT_NAME\"},
            {\"title\": \"Branch\", \"value\": \"$CI_COMMIT_REF_NAME\"},
            {\"title\": \"Author\", \"value\": \"$GITLAB_USER_NAME\"}
          ]
        }]
      }"
```


***

## 📚 Références Officielles

- **Documentation GitLab** : https://docs.gitlab.com/
- **GitLab CI/CD** : https://docs.gitlab.com/ee/ci/
- **GitLab API** : https://docs.gitlab.com/ee/api/
- **GitLab Runner** : https://docs.gitlab.com/runner/
- **GitLab Omnibus** : https://docs.gitlab.com/omnibus/

***

**GitLab est maintenant documenté de A à Z !** 🦊 Plateforme DevOps complète prête pour la production ! 🚀

