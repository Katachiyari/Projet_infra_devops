# 🔍 Trivy : Scanner de Vulnérabilités


***

## 📍 Explication : Scanner de Sécurité et Trivy

### Définition

**Trivy** est un scanner de vulnérabilités open-source développé par Aqua Security. Il détecte les vulnérabilités CVE (Common Vulnerabilities and Exposures) dans les images Docker, systèmes de fichiers, repositories Git, et fichiers de configuration IaC (Infrastructure as Code). Trivy est rapide, précis et ne nécessite aucune configuration complexe.

### Comparaison des solutions de scan de sécurité

| Solution | Images Docker | Filesystem | Git Repos | IaC (Terraform) | Secrets | Licences | Performance | Prix |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| **Trivy** | ✅ Oui | ✅ Oui | ✅ Oui | ✅ Oui | ✅ Oui | ✅ Oui | Excellente | Gratuit |
| **Clair** | ✅ Oui | ❌ Non | ❌ Non | ❌ Non | ❌ Non | ❌ Non | Bonne | Gratuit |
| **Snyk** | ✅ Oui | ✅ Oui | ✅ Oui | ✅ Oui | ✅ Oui | ✅ Oui | Bonne | Freemium |
| **Anchore** | ✅ Oui | ✅ Oui | ❌ Non | ❌ Non | ❌ Non | ✅ Oui | Moyenne | Freemium |
| **Grype** | ✅ Oui | ✅ Oui | ❌ Non | ❌ Non | ❌ Non | ❌ Non | Excellente | Gratuit |
| **Docker Scout** | ✅ Oui | ❌ Non | ❌ Non | ❌ Non | ❌ Non | ❌ Non | Bonne | Freemium |

### Rôle dans l'architecture DevSecOps

```
┌─────────────────────────────────────────────────────────────┐
│ Architecture Trivy dans Pipeline DevSecOps                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Développeur commit code                                │
│     └─> GitLab détecte push                                 │
│                                                             │
│  2. GitLab CI déclenche pipeline                           │
│     ├─> Build image Docker                                  │
│     └─> Push vers Harbor                                    │
│                                                             │
│  3. Harbor déclenche scan Trivy automatique                │
│     ├─> Trivy pull image depuis registry                   │
│     ├─> Scan OS packages (Alpine, Debian, Ubuntu...)       │
│     ├─> Scan dependencies (npm, pip, gem, maven...)        │
│     ├─> Détection vulnérabilités CVE                       │
│     └─> Score sévérité : CRITICAL, HIGH, MEDIUM, LOW       │
│                                                             │
│  4. Résultat scan stocké dans Harbor DB                    │
│     └─> Visible dans Harbor UI                             │
│                                                             │
│  5. GitLab CI récupère résultat scan                       │
│     ├─> API Harbor : GET /artifacts/{tag}/vulnerabilities  │
│     └─> Si CRITICAL > 0 → Pipeline FAIL                    │
│                                                             │
│  6. Notification développeur                               │
│     ├─> Email : "Image contient 3 CVE critiques"           │
│     ├─> Slack : Lien vers rapport détaillé                 │
│     └─> GitLab Merge Request : Commentaire automatique     │
│                                                             │
│  7. Dev corrige vulnérabilités                             │
│     ├─> Mise à jour packages (apt upgrade, npm update)     │
│     └─> Rebuild image → Nouveau scan → OK ✓                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```


***

## 📍 Cycle de vie : Trivy

### Phase 1 : Installation Trivy (Standalone)

```
1. Téléchargement binaire Trivy
   └─> wget https://github.com/aquasecurity/trivy/releases/download/v0.48.0/trivy_0.48.0_Linux-64bit.tar.gz
   └─> tar -xzf trivy_0.48.0_Linux-64bit.tar.gz
   └─> mv trivy /usr/local/bin/
   └─> chmod +x /usr/local/bin/trivy

2. Installation via package manager (Ubuntu)
   └─> wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | apt-key add -
   └─> echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/trivy.list
   └─> apt update
   └─> apt install trivy

3. Vérification installation
   └─> trivy --version
       Output : Version: 0.48.0

4. Premier scan (test)
   └─> trivy image nginx:alpine
       ├─> Téléchargement database vulnérabilités (500 MB)
       ├─> Cache local : ~/.cache/trivy/
       ├─> Scan image nginx:alpine
       └─> Résultat : 15 vulnérabilités (0 CRITICAL, 2 HIGH, 13 MEDIUM)
```


### Phase 2 : Intégration Trivy dans Harbor

```
1. Installation Harbor avec Trivy
   └─> ./install.sh --with-trivy
       ├─> Pull image goharbor/trivy-adapter-photon:v2.10.0
       ├─> Démarrage container trivy-adapter
       └─> Configuration Harbor Core → Trivy adapter

2. Configuration Trivy dans harbor.yml
   └─> trivy:
         ignore_unfixed: false      # Scanner aussi vulnérabilités non fixées
         skip_update: false          # Toujours update DB
         offline_scan: false         # Mode online (download CVE DB)
         timeout: 5m0s               # Timeout scan 5 minutes

3. Activation Trivy comme scanner par défaut
   └─> Harbor UI → Administration → Interrogation Services
       ├─> Vulnerability Scanners
       ├─> Trivy → Set as Default
       └─> ✅ Scan all artifacts on push

4. Test scan automatique
   └─> docker push harbor.lab.local/library/nginx:alpine
       ├─> Harbor reçoit push
       ├─> Jobservice crée job "SCAN"
       ├─> Trivy-adapter pull image
       ├─> Scan vulnérabilités
       └─> Résultat sauvegardé dans PostgreSQL

5. Consultation résultat
   └─> Harbor UI → Projects → library → Repositories → nginx → Artifacts
       └─> Colonne "Vulnerabilities" :
           ├─> 🔴 2 Critical
           ├─> 🟠 5 High
           ├─> 🟡 15 Medium
           └─> ⚪ 30 Low
```


### Phase 3 : Intégration Trivy dans GitLab CI

```
1. Ajout stage "security-scan" dans .gitlab-ci.yml
   └─> stages:
         - build
         - security-scan
         - deploy

2. Job scan avec Trivy
   └─> security-scan:
         stage: security-scan
         image: aquasec/trivy:latest
         script:
           # Scan image Docker buildée
           - trivy image --exit-code 1 --severity CRITICAL,HIGH $IMAGE_NAME:$IMAGE_TAG
           
           # Export résultat JSON
           - trivy image --format json -o trivy-report.json $IMAGE_NAME:$IMAGE_TAG
         
         artifacts:
           reports:
             container_scanning: trivy-report.json
           paths:
             - trivy-report.json
           expire_in: 1 week
         
         allow_failure: false  # Pipeline FAIL si vulnérabilités trouvées

3. Pipeline exécuté
   └─> Build image OK
   └─> Scan Trivy détecte 1 CVE CRITICAL
   └─> Pipeline FAIL ❌
   └─> Notification développeur

4. Développeur corrige
   └─> Update package vulnérable
   └─> Nouveau commit
   └─> Pipeline rejoué → Scan OK ✓
   └─> Déploiement autorisé
```


### Phase 4 : Scan Filesystem et IaC

```
1. Scan filesystem local (avant build image)
   └─> trivy fs ./
       ├─> Scan package.json (npm)
       ├─> Scan requirements.txt (pip)
       ├─> Scan pom.xml (maven)
       ├─> Scan Gemfile (ruby)
       └─> Détection dependencies vulnérables

2. Scan Terraform (IaC)
   └─> trivy config ./terraform/
       ├─> Détection misconfigurations sécurité
       ├─> AWS S3 bucket public
       ├─> Security group 0.0.0.0/0 ouvert
       ├─> IAM policy trop permissive
       └─> Credentials hardcodés

3. Scan Kubernetes manifests
   └─> trivy config ./k8s/
       ├─> Container running as root
       ├─> Privileged mode activé
       ├─> Resources limits absentes
       └─> SecurityContext manquant

4. Scan Git repository (secrets)
   └─> trivy repo https://gitlab.lab.local/myapp.git
       ├─> Détection secrets hardcodés
       ├─> AWS Access Key trouvée
       ├─> Private SSH key exposée
       └─> API tokens en clair
```


***

## 📍 Architecture Trivy Détaillée

### Diagramme de flux Scan Image Docker

```
┌─────────────────────────────────────────────────────────────┐
│ Déclenchement Scan                                          │
├─────────────────────────────────────────────────────────────┤
│ • docker push harbor.lab.local/prod/myapp:v1.0            │
│ • Harbor reçoit image                                       │
│ • Harbor crée job "SCAN_ARTIFACT"                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Job dispatch
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Trivy Adapter (Harbor)                                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Réception job scan                                     │
│     └─> Job ID : scan-12345                                 │
│     └─> Image : prod/myapp:v1.0                            │
│                                                             │
│  2. Pull image depuis registry local                       │
│     └─> docker pull registry:5000/prod/myapp:v1.0          │
│     └─> Image téléchargée (150 MB)                         │
│                                                             │
│  3. Extraction layers image                                │
│     └─> Décompression tar.gz layers                        │
│     └─> Montage filesystem temporaire /tmp/trivy-xxxxx     │
│                                                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Scan filesystem
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Trivy Scanner Engine                                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  4. Détection OS et version                                │
│     └─> OS : Alpine Linux 3.19                             │
│     └─> Arch : amd64                                        │
│                                                             │
│  5. Scan OS packages (Alpine apk)                          │
│     └─> Lecture /lib/apk/db/installed                      │
│     └─> Packages détectés :                                │
│         ├─> openssl 3.1.4-r0                               │
│         ├─> curl 8.5.0-r0                                  │
│         ├─> nginx 1.24.0-r0                                │
│         └─> ... (50 packages total)                        │
│                                                             │
│  6. Scan application dependencies                          │
│     └─> Détection package managers :                       │
│         ├─> package.json (npm) → 150 packages              │
│         ├─> requirements.txt (pip) → 25 packages           │
│         ├─> go.mod (golang) → 30 modules                   │
│         └─> Gemfile.lock (ruby) → 40 gems                  │
│                                                             │
│  7. Chargement database vulnérabilités                     │
│     └─> ~/.cache/trivy/db/trivy.db (500 MB)               │
│     └─> Dernière mise à jour : 2026-01-17                  │
│     └─> CVE count : 250,000 entrées                        │
│                                                             │
│  8. Matching packages ↔ CVE                                │
│     └─> openssl 3.1.4-r0 → CVE-2024-1234 (CRITICAL)       │
│     └─> curl 8.5.0-r0 → CVE-2024-5678 (HIGH)              │
│     └─> lodash 4.17.20 (npm) → CVE-2021-23337 (HIGH)      │
│                                                             │
│  9. Calcul score sévérité                                  │
│     └─> CVSS Score calculation                             │
│         ├─> CVE-2024-1234 : CVSS 9.8 → CRITICAL           │
│         ├─> CVE-2024-5678 : CVSS 7.5 → HIGH               │
│         └─> CVE-2021-23337 : CVSS 7.4 → HIGH              │
│                                                             │
│  10. Génération rapport JSON                               │
│      └─> {                                                  │
│            "ArtifactName": "prod/myapp:v1.0",              │
│            "Results": [                                     │
│              {                                              │
│                "Target": "alpine:3.19",                     │
│                "Vulnerabilities": [                         │
│                  {                                          │
│                    "VulnerabilityID": "CVE-2024-1234",     │
│                    "PkgName": "openssl",                    │
│                    "InstalledVersion": "3.1.4-r0",          │
│                    "FixedVersion": "3.1.5-r0",              │
│                    "Severity": "CRITICAL",                  │
│                    "Description": "Buffer overflow..."      │
│                  }                                          │
│                ]                                            │
│              }                                              │
│            ]                                                │
│          }                                                  │
│                                                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Résultat scan
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Harbor Database (PostgreSQL)                                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  11. Sauvegarde résultat scan                              │
│      └─> Table : artifact_scan_report                      │
│          ├─> artifact_id : 42                              │
│          ├─> scanner : "Trivy"                             │
│          ├─> scan_status : "Success"                       │
│          ├─> severity_summary :                            │
│          │   {                                              │
│          │     "critical": 1,                              │
│          │     "high": 5,                                   │
│          │     "medium": 20,                               │
│          │     "low": 50                                    │
│          │   }                                              │
│          ├─> vulnerabilities : [... JSON array ...]        │
│          └─> scan_date : 2026-01-17 18:30:00               │
│                                                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Notification
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Harbor Webhook (optionnel)                                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  12. POST webhook vers Slack/Email                         │
│      └─> URL : https://hooks.slack.com/services/xxx        │
│      └─> Payload :                                         │
│          {                                                  │
│            "text": "⚠️ Scan completed: myapp:v1.0",        │
│            "attachments": [{                               │
│              "color": "danger",                            │
│              "fields": [                                    │
│                {"title": "Critical", "value": "1"},        │
│                {"title": "High", "value": "5"}             │
│              ]                                              │
│            }]                                               │
│          }                                                  │
│                                                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Affichage UI
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Harbor Web UI                                               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  • Projects → prod → Repositories → myapp → v1.0          │
│  • Colonne "Vulnerabilities" :                             │
│    └─> 🔴 1 Critical | 🟠 5 High | 🟡 20 Medium | ⚪ 50 Low │
│                                                             │
│  • Click détails → Liste CVE complète                      │
│    ├─> CVE-2024-1234 (CRITICAL) openssl 3.1.4-r0          │
│    │   Fix : Upgrade to 3.1.5-r0                           │
│    │   Link : https://nvd.nist.gov/vuln/detail/CVE-2024... │
│    └─> ...                                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```


### Architecture Database Trivy

```
~/.cache/trivy/
├── db/
│   └── trivy.db              # SQLite database (500 MB)
│       ├─> Table : vulnerabilities
│       │   ├─> CVE-ID
│       │   ├─> Package name
│       │   ├─> Affected versions
│       │   ├─> Fixed version
│       │   ├─> CVSS score
│       │   ├─> Description
│       │   └─> References (NVD, GitHub Advisory...)
│       │
│       ├─> Table : advisories
│       │   └─> OS-specific advisories (Alpine, Debian, Ubuntu...)
│       │
│       └─> Table : metadata
│           └─> DB version, last update timestamp
│
├── fanal/
│   └── fanal.db              # OS packages metadata
│       └─> Alpine, Debian, Ubuntu, RedHat packages
│
└── java-db/
    └── trivy-java.db         # Java vulnerabilities (Maven, Gradle)
```


***

## 📍 Fichiers Configuration Trivy

### Fichier 1 : `trivy.yaml` (Config globale)

**Chemin** : `~/.trivy/trivy.yaml` ou `/etc/trivy/trivy.yaml`
**Rôle** : Configuration Trivy globale
**Généré** : ✅ Manuel ou Ansible

```yaml
# ===================================================================
# Configuration Trivy (optionnel - par défaut tout fonctionne)
# ===================================================================

# ===================================================================
# 1. Cache et Database
# ===================================================================
cache:
  # Répertoire cache (DB vulnérabilités)
  dir: ~/.cache/trivy
  
  # Durée cache (avant re-download DB)
  ttl: 24h

db:
  # Repository DB vulnérabilités
  repository: ghcr.io/aquasecurity/trivy-db
  
  # Skip update DB (utiliser cache local)
  skip-update: false
  
  # Download DB même si à jour
  download-db-only: false

# ===================================================================
# 2. Scan Configuration
# ===================================================================
scan:
  # Ignorer vulnérabilités non fixées
  ignore-unfixed: false
  
  # Scanner uniquement OS packages (ignorer app dependencies)
  # Types : os, library
  scanners:
    - os
    - library
  
  # Sévérités à scanner (UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL)
  severity:
    - CRITICAL
    - HIGH
    - MEDIUM
    - LOW
  
  # Timeout scan
  timeout: 5m0s
  
  # Parallélisme (nombre scans simultanés)
  parallel: 5

# ===================================================================
# 3. Vulnerability Database Sources
# ===================================================================
vulnerability:
  # Type de vuln à détecter
  type:
    - os        # OS packages
    - library   # Application dependencies (npm, pip...)
  
  # Ignorer CVE non fixées
  ignore-unfixed: false

# ===================================================================
# 4. Output Format
# ===================================================================
format: table  # table, json, template, sarif, cyclonedx, spdx

# Template personnalisé (si format=template)
template: |
  {{- range . }}
  {{ .Target }} ({{ .Type }})
  {{- range .Vulnerabilities }}
  - {{ .VulnerabilityID }}: {{ .Title }} ({{ .Severity }})
  {{- end }}
  {{- end }}

# ===================================================================
# 5. Filtres
# ===================================================================
# File .trivyignore pour ignorer CVE spécifiques
# Chemin : ./.trivyignore ou ~/.trivy/.trivyignore

# ===================================================================
# 6. Registry Configuration
# ===================================================================
registry:
  # Authentification registry Docker privé
  # credentials:
  #   - registry: harbor.lab.local
  #     username: admin
  #     password: password
  
  # Skip TLS verify (registry auto-signé)
  insecure: false

# ===================================================================
# 7. Proxy
# ===================================================================
# proxy:
#   http: http://proxy.lab.local:3128
#   https: http://proxy.lab.local:3128
#   no_proxy: localhost,127.0.0.1,.lab.local

# ===================================================================
# 8. Logs
# ===================================================================
log:
  level: info  # debug, info, warn, error, fatal
  format: text  # text, json

# ===================================================================
# 9. Offline Mode
# ===================================================================
# offline-scan: true  # Ne pas download DB (utiliser cache uniquement)
```


***

### Fichier 2 : `.trivyignore` (Ignorer CVE spécifiques)

**Chemin** : `./.trivyignore` (racine projet) ou `~/.trivy/.trivyignore`
**Rôle** : Liste CVE à ignorer (faux positifs, acceptés)
**Généré** : ✅ Manuel

```bash
# ===================================================================
# .trivyignore : Ignorer CVE spécifiques
# ===================================================================

# Format : CVE-YYYY-NNNNN [espace] [commentaire optionnel]

# ===================================================================
# CVE acceptées (risk accepted)
# ===================================================================
CVE-2024-1234  # OpenSSL vulnerability - Risk accepted (low impact)
CVE-2023-5678  # Curl DoS - Fixed in next release

# ===================================================================
# Faux positifs
# ===================================================================
CVE-2022-9999  # False positive - package not used

# ===================================================================
# CVE OS base image (hors contrôle)
# ===================================================================
CVE-2021-1111  # Alpine base image - waiting upstream fix

# ===================================================================
# Pattern matching (wildcard)
# ===================================================================
# CVE-2020-*  # Ignorer toutes CVE 2020 (non recommandé)

# ===================================================================
# Ignorer par package
# ===================================================================
# Format : pkg:package-name@version CVE-YYYY-NNNNN
pkg:npm/lodash@4.17.20 CVE-2021-23337  # Lodash upgrade impossible (breaking change)

# ===================================================================
# Expiration ignore (temporaire)
# ===================================================================
CVE-2024-7777 exp:2026-03-01  # Ignorer jusqu'au 1er mars 2026
```


***

### Fichier 3 : `.gitlab-ci.yml` (Intégration GitLab CI)

**Chemin** : `./.gitlab-ci.yml` (racine projet GitLab)
**Rôle** : Pipeline CI avec Trivy scan
**Généré** : ✅ Manuel

```yaml
# ===================================================================
# GitLab CI avec Trivy Scan
# ===================================================================

stages:
  - build
  - security-scan
  - deploy

variables:
  DOCKER_DRIVER: overlay2
  HARBOR_REGISTRY: harbor.lab.local
  IMAGE_NAME: $HARBOR_REGISTRY/prod/$CI_PROJECT_NAME
  IMAGE_TAG: $CI_COMMIT_TAG

# ===================================================================
# Stage 1 : Build Docker Image
# ===================================================================
build:
  stage: build
  image: docker:24-dind
  services:
    - docker:24-dind
  script:
    # Login Harbor
    - docker login -u $HARBOR_USER -p $HARBOR_PASSWORD $HARBOR_REGISTRY
    
    # Build image
    - docker build -t $IMAGE_NAME:$IMAGE_TAG .
    
    # Push vers Harbor
    - docker push $IMAGE_NAME:$IMAGE_TAG
  
  only:
    - tags

# ===================================================================
# Stage 2 : Trivy Scan Image Docker
# ===================================================================
trivy-scan-image:
  stage: security-scan
  image: aquasec/trivy:latest
  script:
    # Scan image (fail si CRITICAL ou HIGH)
    - trivy image --exit-code 1 --severity CRITICAL,HIGH $IMAGE_NAME:$IMAGE_TAG
    
    # Export rapport JSON
    - trivy image --format json -o trivy-image-report.json $IMAGE_NAME:$IMAGE_TAG
    
    # Export rapport HTML (plus lisible)
    - trivy image --format template --template "@contrib/html.tpl" -o trivy-image-report.html $IMAGE_NAME:$IMAGE_TAG
    
    # Afficher résumé
    - trivy image --format table $IMAGE_NAME:$IMAGE_TAG
  
  artifacts:
    reports:
      container_scanning: trivy-image-report.json
    paths:
      - trivy-image-report.json
      - trivy-image-report.html
    expire_in: 30 days
  
  allow_failure: false  # Pipeline FAIL si vulnérabilités
  
  only:
    - tags

# ===================================================================
# Stage 2b : Trivy Scan Filesystem (dependencies app)
# ===================================================================
trivy-scan-fs:
  stage: security-scan
  image: aquasec/trivy:latest
  script:
    # Scan filesystem projet (package.json, requirements.txt...)
    - trivy fs --exit-code 1 --severity CRITICAL,HIGH ./
    
    # Export rapport JSON
    - trivy fs --format json -o trivy-fs-report.json ./
  
  artifacts:
    reports:
      dependency_scanning: trivy-fs-report.json
    paths:
      - trivy-fs-report.json
    expire_in: 30 days
  
  allow_failure: false
  
  only:
    - merge_requests
    - main

# ===================================================================
# Stage 2c : Trivy Scan IaC (Terraform, Kubernetes)
# ===================================================================
trivy-scan-iac:
  stage: security-scan
  image: aquasec/trivy:latest
  script:
    # Scan Terraform files
    - trivy config --exit-code 1 --severity CRITICAL,HIGH ./terraform/
    
    # Scan Kubernetes manifests
    - trivy config --exit-code 1 --severity CRITICAL,HIGH ./k8s/
    
    # Export rapport JSON
    - trivy config --format json -o trivy-iac-report.json ./
  
  artifacts:
    paths:
      - trivy-iac-report.json
    expire_in: 30 days
  
  allow_failure: true  # Warning seulement (ne pas bloquer)
  
  only:
    - merge_requests
    - main

# ===================================================================
# Stage 2d : Trivy Scan Git Repo (secrets detection)
# ===================================================================
trivy-scan-secrets:
  stage: security-scan
  image: aquasec/trivy:latest
  script:
    # Scan secrets hardcodés dans Git
    - trivy repo --exit-code 1 --scanners secret .
    
    # Export rapport
    - trivy repo --format json --scanners secret -o trivy-secrets-report.json .
  
  artifacts:
    paths:
      - trivy-secrets-report.json
    expire_in: 30 days
  
  allow_failure: false  # FAIL si secrets détectés
  
  only:
    - merge_requests
    - main

# ===================================================================
# Stage 3 : Deploy (si tous scans OK)
# ===================================================================
deploy:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - kubectl set image deployment/myapp myapp=$IMAGE_NAME:$IMAGE_TAG
    - kubectl rollout status deployment/myapp
  
  environment:
    name: production
    url: https://myapp.lab.local
  
  only:
    - tags
  
  when: on_success  # Seulement si stages précédents OK
```


***

### Fichier 4 : `Dockerfile` (Multi-stage avec Trivy)

**Chemin** : `./Dockerfile`
**Rôle** : Dockerfile avec scan Trivy intégré
**Généré** : ✅ Manuel

```dockerfile
# ===================================================================
# Multi-stage Dockerfile avec Trivy scan intégré
# ===================================================================

# ===================================================================
# Stage 1 : Build application
# ===================================================================
FROM node:18-alpine AS builder

WORKDIR /app

# Copier dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copier code source
COPY . .

# Build application
RUN npm run build

# ===================================================================
# Stage 2 : Scan vulnérabilités avec Trivy
# ===================================================================
FROM aquasec/trivy:latest AS trivy-scanner

# Copier filesystem depuis builder
COPY --from=builder /app /scan

# Scan filesystem (fail si CRITICAL)
RUN trivy fs --exit-code 1 --severity CRITICAL /scan

# ===================================================================
# Stage 3 : Image finale (production)
# ===================================================================
FROM nginx:alpine

# Copier artifacts depuis builder (si scan OK)
COPY --from=builder /app/dist /usr/share/nginx/html

# Configuration Nginx
COPY nginx.conf /etc/nginx/nginx.conf

# User non-root (sécurité)
USER nginx

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

# Port
EXPOSE 80

# Entrypoint
CMD ["nginx", "-g", "daemon off;"]
```


***

## 📊 Commandes Trivy

### 🔍 Scan Images Docker

#### Scan image locale

```bash
# Scan simple
trivy image nginx:alpine

# Scan avec sévérités spécifiques
trivy image --severity CRITICAL,HIGH nginx:alpine

# Fail si vulnérabilités trouvées
trivy image --exit-code 1 --severity CRITICAL nginx:alpine

# Ignorer vulnérabilités non fixées
trivy image --ignore-unfixed nginx:alpine

# Scan uniquement OS packages (ignorer dependencies app)
trivy image --scanners vuln nginx:alpine
```


#### Scan image depuis registry privé

```bash
# Harbor avec authentification
trivy image \
  --username admin \
  --password "$HARBOR_PASSWORD" \
  harbor.lab.local/prod/myapp:v1.0

# Avec insecure registry (auto-signé)
trivy image --insecure harbor.lab.local/prod/myapp:v1.0

# Via Docker config (~/.docker/config.json)
trivy image harbor.lab.local/prod/myapp:v1.0
```


#### Export rapports

```bash
# Format JSON
trivy image --format json -o report.json nginx:alpine

# Format HTML
trivy image --format template --template "@contrib/html.tpl" -o report.html nginx:alpine

# Format SARIF (GitHub Security)
trivy image --format sarif -o report.sarif nginx:alpine

# Format CycloneDX SBOM
trivy image --format cyclonedx -o sbom.json nginx:alpine

# Format SPDX SBOM
trivy image --format spdx-json -o sbom.spdx.json nginx:alpine

# Format table (stdout)
trivy image --format table nginx:alpine
```


***

### 📁 Scan Filesystem

#### Scan répertoire projet

```bash
# Scan répertoire courant
trivy fs .

# Scan répertoire spécifique
trivy fs /path/to/project

# Scan avec sévérités
trivy fs --severity CRITICAL,HIGH .

# Scan uniquement dependencies (npm, pip, gem...)
trivy fs --scanners vuln .
```


#### Scan fichiers spécifiques

```bash
# Scan package.json (npm)
trivy fs package.json

# Scan requirements.txt (pip)
trivy fs requirements.txt

# Scan pom.xml (maven)
trivy fs pom.xml

# Scan go.mod (golang)
trivy fs go.mod

# Scan Gemfile.lock (ruby)
trivy fs Gemfile.lock
```


***

### ⚙️ Scan IaC (Infrastructure as Code)

#### Scan Terraform

```bash
# Scan fichiers Terraform
trivy config ./terraform/

# Scan avec sévérités
trivy config --severity CRITICAL,HIGH ./terraform/

# Export rapport JSON
trivy config --format json -o terraform-report.json ./terraform/

# Misconfigurations détectées :
# - AWS S3 bucket public
# - Security group 0.0.0.0/0 ouvert
# - IAM policy trop permissive
# - Encryption disabled
```


#### Scan Kubernetes manifests

```bash
# Scan YAML Kubernetes
trivy config ./k8s/

# Misconfigurations détectées :
# - Container running as root
# - Privileged mode enabled
# - Resources limits missing
# - SecurityContext missing
# - hostNetwork: true
```


#### Scan Docker Compose

```bash
# Scan docker-compose.yml
trivy config docker-compose.yml

# Misconfigurations :
# - Privileged mode
# - Host path mounts
# - Capabilities added
```


***

### 🔐 Scan Secrets (Git Repository)

#### Scan repository Git

```bash
# Scan repo local
trivy repo .

# Scan repo remote
trivy repo https://github.com/user/repo.git

# Scan uniquement secrets (ignorer vulnérabilités)
trivy repo --scanners secret .

# Secrets détectés :
# - AWS Access Key
# - GitHub Token
# - Private SSH Key
# - Database password
# - API keys
```


#### Scan historique Git

```bash
# Scan tous commits Git (détection secrets dans historique)
trivy repo --scanners secret --include-dev-deps .

# Scan branch spécifique
trivy repo --branch main https://github.com/user/repo.git
```


***

### 🗄️ Gestion Database Trivy

#### Update database vulnérabilités

```bash
# Update DB (automatique au premier scan)
trivy image --download-db-only

# Forcer update
trivy image --reset

# Vérifier version DB
trivy --version
# Output :
# Version: 0.48.0
# Vulnerability DB:
#   Version: 2
#   UpdatedAt: 2026-01-17 10:00:00 UTC
#   NextUpdate: 2026-01-18 10:00:00 UTC
```


#### Utiliser DB locale (offline)

```bash
# Télécharger DB
trivy image --download-db-only

# Scan en mode offline
trivy image --skip-db-update --offline-scan nginx:alpine

# Utiliser cache existant
trivy image --skip-db-update nginx:alpine
```


#### Clear cache

```bash
# Nettoyer cache complet
trivy image --clear-cache

# Supprimer cache manuellement
rm -rf ~/.cache/trivy/
```


***

### 📊 Formats Output Avancés

#### Template personnalisé

```bash
# Template simple
trivy image --format template --template "{{ range . }}{{ .Target }}: {{ len .Vulnerabilities }} vulns{{ end }}" nginx:alpine

# Template avec détails
cat > template.tpl <<'EOF'
{{- range . }}
Target: {{ .Target }}
Type: {{ .Type }}
Vulnerabilities:
{{- range .Vulnerabilities }}
  - {{ .VulnerabilityID }} ({{ .Severity }}): {{ .Title }}
    Package: {{ .PkgName }} {{ .InstalledVersion }}
    {{- if .FixedVersion }}
    Fix: Upgrade to {{ .FixedVersion }}
    {{- end }}
{{- end }}
{{- end }}
EOF

trivy image --format template --template "@template.tpl" nginx:alpine
```


#### SBOM (Software Bill of Materials)

```bash
# CycloneDX SBOM
trivy image --format cyclonedx --output sbom.cdx.json nginx:alpine

# SPDX SBOM
trivy image --format spdx-json --output sbom.spdx.json nginx:alpine

# Upload SBOM vers Dependency-Track
curl -X POST "https://dtrack.lab.local/api/v1/bom" \
  -H "X-Api-Key: $DTRACK_API_KEY" \
  -H "Content-Type: multipart/form-data" \
  -F "project=myapp" \
  -F "bom=@sbom.cdx.json"
```


***

### 🎯 Scans Avancés

#### Scan avec filtres

```bash
# Ignorer packages spécifiques
trivy image --ignored-licenses MIT,Apache-2.0 nginx:alpine

# Scan uniquement packages critiques
trivy image --severity CRITICAL nginx:alpine | grep -E "CRITICAL|HIGH"

# Compter vulnérabilités
trivy image --format json nginx:alpine | jq '.Results[].Vulnerabilities | length'
```


#### Scan multi-targets

```bash
# Scan plusieurs images
for image in nginx:alpine alpine:3.19 ubuntu:22.04; do
  echo "Scanning $image..."
  trivy image --severity CRITICAL,HIGH $image
done

# Export multi-reports
trivy image --format json -o nginx-report.json nginx:alpine
trivy image --format json -o alpine-report.json alpine:3.19
trivy image --format json -o ubuntu-report.json ubuntu:22.04
```


#### Scan avec webhook notification

```bash
# Scan + webhook Slack si vulnérabilités
RESULT=$(trivy image --format json nginx:alpine)
CRITICAL=$(echo "$RESULT" | jq '[.Results[].Vulnerabilities[] | select(.Severity=="CRITICAL")] | length')

if [ "$CRITICAL" -gt 0 ]; then
  curl -X POST https://hooks.slack.com/services/xxx \
    -H 'Content-Type: application/json' \
    -d "{\"text\":\"⚠️ $CRITICAL critical vulnerabilities found in nginx:alpine\"}"
fi
```


***

## 🔧 Intégrations Avancées

### 🐳 Docker Build avec Trivy

```dockerfile
# Build avec scan Trivy automatique
docker build --target trivy-scanner -t myapp:scan .

# Si scan OK, build final
docker build -t myapp:v1.0 .
```


### 🔄 Pre-commit Hook (scan avant commit)

**Chemin** : `.git/hooks/pre-commit`

```bash
#!/bin/bash
# ===================================================================
# Pre-commit hook : Scan Trivy avant commit
# ===================================================================

echo "🔍 Scanning for vulnerabilities and secrets..."

# Scan filesystem
trivy fs --severity CRITICAL,HIGH --exit-code 1 .

# Scan secrets
trivy repo --scanners secret --exit-code 1 .

if [ $? -ne 0 ]; then
  echo "❌ Vulnerabilities or secrets detected. Commit aborted."
  exit 1
fi

echo "✓ Scan OK"
exit 0
```

**Activation** :

```bash
chmod +x .git/hooks/pre-commit
```


***

### 🤖 GitHub Actions avec Trivy

**Chemin** : `.github/workflows/trivy-scan.yml`

```yaml
name: Trivy Security Scan

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  trivy-scan:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Build Docker image
        run: docker build -t myapp:${{ github.sha }} .
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'myapp:${{ github.sha }}'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
      
      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'
      
      - name: Fail if vulnerabilities found
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'myapp:${{ github.sha }}'
          exit-code: 1
          severity: 'CRITICAL,HIGH'
```


***

### 📊 Prometheus Exporter (métriques Trivy)

**Installation trivy-exporter** :

```bash
docker run -d --name trivy-exporter \
  -p 9115:9115 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy-exporter:latest
```

**Métriques exposées** :

```bash
curl http://localhost:9115/metrics

# trivy_vulnerabilities_total{severity="CRITICAL"} 5
# trivy_vulnerabilities_total{severity="HIGH"} 20
# trivy_vulnerabilities_total{severity="MEDIUM"} 50
# trivy_scan_duration_seconds 15.3
```

**Configuration Prometheus** :

```yaml
scrape_configs:
  - job_name: 'trivy'
    static_configs:
      - targets: ['localhost:9115']
```


***

## 📋 Troubleshooting Trivy

### ❌ Problème 1 : Database update timeout

```bash
# Symptôme
trivy image nginx:alpine
# Error: failed to download vulnerability DB: timeout

# Solution 1 : Augmenter timeout
export TRIVY_TIMEOUT=15m
trivy image nginx:alpine

# Solution 2 : Utiliser mirror DB
export TRIVY_DB_REPOSITORY=ghcr.io/aquasecurity/trivy-db
trivy image nginx:alpine

# Solution 3 : Download DB manuellement
trivy image --download-db-only
trivy image --skip-db-update nginx:alpine
```


### ❌ Problème 2 : Faux positifs CVE

```bash
# Symptôme
trivy image myapp:v1.0
# CVE-2024-1234 détectée mais package non utilisé

# Solution : Ajouter à .trivyignore
echo "CVE-2024-1234  # False positive - package not used" >> .trivyignore

# Re-scan
trivy image myapp:v1.0
# CVE-2024-1234 ignorée
```


### ❌ Problème 3 : Scan très lent

```bash
# Symptôme
trivy image large-image:latest
# Scan prend 10+ minutes

# Solution 1 : Utiliser cache
trivy image --skip-db-update large-image:latest

# Solution 2 : Scanner uniquement OS (ignorer dependencies)
trivy image --scanners vuln large-image:latest

# Solution 3 : Augmenter parallélisme
export TRIVY_PARALLEL=10
trivy image large-image:latest
```


### ❌ Problème 4 : Registry privé erreur auth

```bash
# Symptôme
trivy image harbor.lab.local/prod/myapp:v1.0
# Error: authentication required

# Solution 1 : Spécifier credentials
trivy image --username admin --password "$PASSWORD" harbor.lab.local/prod/myapp:v1.0

# Solution 2 : Utiliser Docker config
docker login harbor.lab.local
trivy image harbor.lab.local/prod/myapp:v1.0

# Solution 3 : Variable environnement
export TRIVY_USERNAME=admin
export TRIVY_PASSWORD=password
trivy image harbor.lab.local/prod/myapp:v1.0
```


***

## 🎯 Best Practices Trivy

### ✅ Recommandations Production

#### Pipeline CI/CD

- ✅ Scanner **avant** push vers registry
- ✅ Bloquer déploiement si **CRITICAL** détectée
- ✅ Alerter équipe sécu si **HIGH** (ne pas bloquer)
- ✅ Générer rapport SARIF pour GitHub/GitLab Security
- ✅ Archiver rapports (compliance audit)


#### Fréquence scans

- ✅ **Chaque commit** : Scan filesystem (dependencies)
- ✅ **Chaque build** : Scan image Docker
- ✅ **Daily** : Re-scan images production (nouvelles CVE)
- ✅ **Weekly** : Scan IaC (Terraform, K8s manifests)


#### Gestion vulnérabilités

- ✅ Prioriser **CRITICAL** (fix immédiat)
- ✅ **HIGH** : Fix dans 7 jours
- ✅ **MEDIUM** : Fix dans 30 jours
- ✅ **LOW** : À évaluer (peut ignorer si faible impact)
- ✅ Documenter CVE ignorées dans `.trivyignore` avec raison


#### Performance

- ✅ Utiliser cache local (`--skip-db-update`)
- ✅ Scanner uniquement sévérités critiques en CI/CD
- ✅ Mode offline pour builds fréquents
- ✅ Paralléliser scans multi-images

***

## 📚 Références Officielles

- **Documentation Trivy** : https://aquasecurity.github.io/trivy/
- **GitHub Trivy** : https://github.com/aquasecurity/trivy
- **NVD (National Vulnerability Database)** : https://nvd.nist.gov/
- **CVE Database** : https://cve.mitre.org/
- **CVSS Calculator** : https://nvd.nist.gov/vuln-metrics/cvss/v3-calculator

***

**Trivy est maintenant documenté de A à Z !** 🛡️ Sécurité DevSecOps garantie ! 🔒

