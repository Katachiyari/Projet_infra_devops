# Documentation Tools-Manager (SSOT)

## Vue d'ensemble

**Hôte**: `tools-manager`  
**IP**: `172.16.100.20`  
**OS**: Ubuntu (via cloud-init)  
**Rôle**: Hébergement des outils de gestion de projet et documentation collaborative

## Services déployés

### 1. EdgeDoc (HedgeDoc)

#### Description
Éditeur Markdown collaboratif en temps réel, fork de CodiMD. Permet la création et l'édition partagée de notes, documentation technique, et présentations.

#### Architecture
- **Image principale**: `quay.io/hedgedoc/hedgedoc:latest`
- **Base de données**: MariaDB 10.11
- **Stack**: Docker Compose avec 2 services (app + db)

#### Configuration réseau
- **Port hôte**: 8080 (mappé vers 3000 interne)
- **URL publique**: `https://edgedoc.lab.local`
- **Accès**: Via reverse proxy Nginx sur `172.16.100.253:443`

#### Base de données MariaDB
```yaml
Service: edgedoc-db
Image: mariadb:10.11
Conteneur: edgedoc-db
Port interne: 3306
Database: hedgedoc
User: hedgedoc
```

**Variables d'environnement DB**:
- `MARIADB_DATABASE`: hedgedoc
- `MARIADB_USER`: hedgedoc
- `MARIADB_PASSWORD`: hedgedocpass (à changer en production)
- `MARIADB_ROOT_PASSWORD`: hedgedocrootpass (à changer en production)

#### Service HedgeDoc
```yaml
Conteneur: edgedoc
Port: 8080:3000
Dépendances: edgedoc-db
Healthcheck: curl -f http://localhost:3000/api/status
```

**Variables d'environnement App**:
- `NODE_ENV`: production
- `CMD_DOMAIN`: edgedoc.lab.local
- `CMD_DB_URL`: mysql://hedgedoc:hedgedocpass@edgedoc-db:3306/hedgedoc
- `CMD_DB_DIALECT`: mariadb
- `CMD_ALLOW_ANONYMOUS`: true
- `CMD_ALLOW_ANONYMOUS_EDITS`: true
- `CMD_DEFAULT_PERMISSION`: freely
- `CMD_SESSION_SECRET`: please-change-me (à changer)

#### Volumes persistants
```bash
/opt/edgedoc/
├── uploads/          # Fichiers uploadés (UID 1000:1000, 0775)
├── db-data/          # Données MariaDB (UID 999:999, 0755)
└── docker-compose.yml
```

#### Déploiement Ansible
- **Rôle**: `Ansible/roles/edgedoc/`
- **Playbook**: `Ansible/playbooks/edgedoc.yml`
- **Inventaire**: `tools_hosts` group
- **Variables par défaut**: `Ansible/roles/edgedoc/defaults/main.yml`

**Structure du rôle**:
```
edgedoc/
├── defaults/
│   └── main.yml          # Variables DB, ports, domaine
├── tasks/
│   └── main.yml          # Création dirs, permissions, deploy compose
└── templates/
    └── docker-compose.yml.j2
```

#### Configuration DNS (BIND9)
```yaml
# Ansible/inventory/host_vars/bind9dns.yml
edgedoc.lab.local → 172.16.100.253 (reverse-proxy)
```

#### Configuration reverse proxy
```yaml
# Ansible/inventory/host_vars/reverse-proxy.yml
edgedoc:
  host: "172.16.100.20"
  port: 8080
```

**Bloc Nginx**:
```nginx
upstream edgedoc {
    server 172.16.100.20:8080;
}

server {
    listen 443 ssl http2;
    server_name edgedoc.lab.local;
    
    location / {
        proxy_pass http://edgedoc;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

#### Commandes utiles
```bash
# Déployer EdgeDoc
ansible-playbook -i Ansible/inventory/hosts.yml \
  Ansible/playbooks/edgedoc.yml --limit tools_hosts

# Vérifier les conteneurs
ssh tools-manager "docker ps | grep edgedoc"

# Logs application
ssh tools-manager "docker logs edgedoc"

# Logs base de données
ssh tools-manager "docker logs edgedoc-db"

# Accès MariaDB
ssh tools-manager "docker exec -it edgedoc-db mysql -uhedgedoc -p"

# Test local
ssh tools-manager "curl -I http://localhost:8080"

# Test via proxy
curl -I -k https://edgedoc.lab.local
```

#### Migrations et initialisation
Au premier démarrage, HedgeDoc exécute automatiquement les migrations Sequelize sur la base MariaDB. Les logs affichent l'avancement :
```
== 20150702001020-update-to-0_3_1: migrating
== 20150702001020-update-to-0_3_1: migrated
...
All migrations performed successfully
HTTP Server listening at 0.0.0.0:3000
```

#### Sécurité et bonnes pratiques
1. **Modifier les mots de passe**: Changer `edgedoc_db_password`, `edgedoc_db_root_password`, `CMD_SESSION_SECRET` via Ansible Vault
2. **Authentification**: Configurer OAuth/LDAP si accès restreint requis (désactiver anonymous)
3. **Backups**: Sauvegarder `/opt/edgedoc/db-data` (volumes MariaDB) et `/opt/edgedoc/uploads`
4. **Monitoring**: Scraper `/api/status` pour healthchecks externes

---

### 2. Taiga

#### Description
Plateforme de gestion de projets agile open-source. Supporte Scrum, Kanban, avec tableaux de bord, user stories, sprints, et intégrations GitHub/GitLab.

#### Architecture
Stack complète Docker Compose avec 9 services :
- Frontend (Angular)
- Backend (Django/Python)
- Async workers
- Events (websockets temps réel)
- Gateway (Nginx interne)
- PostgreSQL
- 2x RabbitMQ (async + events)
- Protected (documents)

#### Configuration réseau
- **Port hôte**: 9000 (gateway Nginx interne)
- **URL publique**: `https://taiga.lab.local`
- **Accès**: Via reverse proxy Nginx sur `172.16.100.253:443`

#### Services et conteneurs

##### Frontend
```yaml
Conteneur: src-taiga-front-1
Image: taigaio/taiga-front:latest
Port interne: 80
Volume: Statique généré au build
```

**Configuration frontend** (`/usr/share/nginx/html/conf.json`):
```json
{
    "api": "https://taiga.lab.local/api/v1/",
    "eventsUrl": "wss://taiga.lab.local/events",
    "baseHref": "/",
    "defaultLanguage": "en",
    "defaultTheme": "taiga",
    "defaultLoginEnabled": true,
    "publicRegisterEnabled": false
}
```

**IMPORTANT**: Le `conf.json` doit pointer vers le domaine public `https://taiga.lab.local` et non l'IP interne, sinon page blanche dans le navigateur (API calls échouent).

##### Backend (API)
```yaml
Conteneur: src-taiga-back-1
Image: taigaio/taiga-back:latest
Port interne: 8000
Dépendances: PostgreSQL, RabbitMQ
```

##### Async Workers
```yaml
Conteneur: src-taiga-async-1
Image: taigaio/taiga-back:latest
Commande: /taiga-back/docker/async_entrypoint.sh
Dépendances: RabbitMQ async
```

##### Events (WebSockets)
```yaml
Conteneur: src-taiga-events-1
Image: taigaio/taiga-events:latest
Port interne: 8888
Dépendances: RabbitMQ events
```

##### Gateway (Nginx interne)
```yaml
Conteneur: src-taiga-gateway-1
Image: nginx:1.19-alpine
Port: 9000:80
Rôle: Routage entre frontend/backend/events
```

##### Base de données
```yaml
Conteneur: src-taiga-db-1
Image: postgres:12.3
Port interne: 5432
Healthcheck: pg_isready
```

##### RabbitMQ (2 instances)
```yaml
# Async tasks
Conteneur: src-taiga-async-rabbitmq-1
Image: rabbitmq:3.8-management-alpine
Ports: 5672, 15672 (management)

# Events temps réel
Conteneur: src-taiga-events-rabbitmq-1
Image: rabbitmq:3.8-management-alpine
Ports: 5672, 15672 (management)
```

##### Protected (documents)
```yaml
Conteneur: src-taiga-protected-1
Image: taigaio/taiga-protected:latest
Port interne: 8003
```

#### Volumes persistants
```bash
# Volumes Docker nommés
src_taiga-db-data                    # PostgreSQL data
src_taiga-static-data                # Fichiers statiques (uploads, avatars)
src_taiga-async-rabbitmq-data       # RabbitMQ async
src_taiga-events-rabbitmq-data      # RabbitMQ events
```

#### Configuration DNS (BIND9)
```yaml
# Ansible/inventory/host_vars/bind9dns.yml
taiga.lab.local → 172.16.100.253 (reverse-proxy)
```

#### Configuration reverse proxy
```yaml
# Ansible/inventory/host_vars/reverse-proxy.yml
taiga:
  host: "172.16.100.20"
  port: 9000
```

**Bloc Nginx**:
```nginx
upstream taiga {
    server 172.16.100.20:9000;
}

server {
    listen 443 ssl http2;
    server_name taiga.lab.local;
    
    location / {
        proxy_pass http://taiga;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # WebSockets pour events temps réel
    location /events {
        proxy_pass http://taiga;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

#### Déploiement
- **Playbook Ansible**: `Ansible/playbooks/taiga.yml`
- **Inventaire**: `tools_hosts` group
- **Note**: Stack déployée manuellement initialement, à idempotentiser via rôle Ansible si modifications nécessaires

#### Commandes utiles
```bash
# Vérifier tous les conteneurs Taiga
ssh tools-manager "docker ps | grep taiga"

# Logs gateway (point d'entrée)
ssh tools-manager "docker logs src-taiga-gateway-1"

# Logs backend API
ssh tools-manager "docker logs src-taiga-back-1"

# Logs frontend
ssh tools-manager "docker logs src-taiga-front-1"

# Logs events (websockets)
ssh tools-manager "docker logs src-taiga-events-1"

# Vérifier conf.json frontend
ssh tools-manager "docker exec src-taiga-front-1 cat /usr/share/nginx/html/conf.json"

# Test local gateway
ssh tools-manager "curl -I http://localhost:9000"

# Test via proxy
curl -I -k https://taiga.lab.local
```

#### Troubleshooting : Page blanche

**Symptôme**: Le navigateur charge la page Taiga mais affiche uniquement une page blanche.

**Cause**: Le fichier `conf.json` du frontend pointe vers l'IP interne (`http://172.16.100.20:9000/api/v1/`) au lieu du domaine public. Les appels API depuis le navigateur échouent (CORS / accès réseau privé).

**Solution**: Corriger le `conf.json` dans le conteneur frontend :
```bash
ssh tools-manager
docker exec src-taiga-front-1 sh -c 'cat > /usr/share/nginx/html/conf.json << EOF
{
    "api": "https://taiga.lab.local/api/v1/",
    "eventsUrl": "wss://taiga.lab.local/events",
    ...
}
EOF'
```

**Vérification**:
```bash
# Depuis le poste client
curl -s https://taiga.lab.local/conf.json -k | grep api
# Doit afficher: "api": "https://taiga.lab.local/api/v1/"
```

**Permanentisation**: Monter un volume ou reconstruire l'image frontend avec le bon conf.json.

#### Sécurité et bonnes pratiques
1. **Variables d'environnement**: Centraliser secrets (DB passwords, Django SECRET_KEY) via fichiers `.env` ou Ansible Vault
2. **Enregistrement public**: `publicRegisterEnabled: false` par défaut, gérer users via admin
3. **Backups**: Sauvegarder volumes PostgreSQL (`src_taiga-db-data`) et statiques (`src_taiga-static-data`)
4. **Monitoring**: Scraper `/api/v1/stats` pour métriques applicatives
5. **Updates**: Suivre les releases Taiga et reconstruire images régulièrement

---

## Configuration globale tools-manager

### Réseau
```yaml
Interface: ens18
IP: 172.16.100.20/24
Gateway: 172.16.100.1
DNS: 172.16.100.254 (BIND9 sur bind9dns)
```

### Firewall (UFW)
```bash
# Ports ouverts
22/tcp   - SSH (depuis LAN uniquement)
8080/tcp - EdgeDoc (accès local + reverse proxy)
9000/tcp - Taiga gateway (accès local + reverse proxy)

# Règles par défaut
ufw default deny incoming
ufw default allow outgoing
ufw allow from 172.16.100.0/24 to any port 22
ufw allow from 172.16.100.0/24 to any port 8080
ufw allow from 172.16.100.0/24 to any port 9000
```

### Docker
- **Version**: Docker Engine 24+ avec Docker Compose v2
- **Socket**: `/var/run/docker.sock`
- **Volumes root**: `/var/lib/docker/volumes/`
- **Réseaux**: Bridges Docker par défaut + réseaux dédiés par stack (edgedoc_edgedoc_net, src_default)

### Ansible
- **User SSH**: ansible (avec sudo NOPASSWD)
- **Inventaire**: `Ansible/inventory/hosts.yml` → groupe `tools_hosts`
- **Host vars**: `Ansible/inventory/host_vars/tools-manager.yml` (si nécessaire)

### DNS (BIND9)
Zones gérées sur `bind9dns` (172.16.100.254) :
```
edgedoc.lab.local  A  172.16.100.253
taiga.lab.local    A  172.16.100.253
```

Les deux services passent par le reverse proxy pour terminaison SSL et headers de sécurité.

### Reverse Proxy (Nginx)
Hôte: `reverse-proxy` (172.16.100.253)

**Backends tools-manager**:
```yaml
edgedoc:
  host: 172.16.100.20
  port: 8080
taiga:
  host: 172.16.100.20
  port: 9000
```

**Headers ajoutés par le proxy**:
- `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- `X-Frame-Options: SAMEORIGIN`
- `X-Content-Type-Options: nosniff`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: strict-origin-when-cross-origin`

**Certificat SSL**: Wildcard `*.lab.local` auto-signé
- Cert: `/etc/nginx/ssl/wildcard.lab.local.crt`
- Key: `/etc/nginx/ssl/wildcard.lab.local.key`
- CA: `/etc/nginx/ssl/root-ca.crt`

**Note certificat**: Navigateurs affichent avertissement (non reconnu par CA publique). Pour usage interne, importer `root-ca.crt` dans le store de confiance du poste client.

---

## Workflows de déploiement

### Déploiement complet tools-manager
```bash
cd /home/admin1/Documents/Projet_infra_devops

# 1. Déployer EdgeDoc
ansible-playbook -i Ansible/inventory/hosts.yml \
  Ansible/playbooks/edgedoc.yml --limit tools_hosts

# 2. Vérifier Taiga (déjà déployé)
ansible -i Ansible/inventory/hosts.yml tools-manager -b -m shell \
  -a "docker ps | grep taiga"

# 3. Corriger conf.json Taiga si nécessaire (page blanche)
ansible -i Ansible/inventory/hosts.yml tools-manager -b -m shell \
  -a "docker exec src-taiga-front-1 cat /usr/share/nginx/html/conf.json | grep api"

# 4. Redéployer reverse proxy (si backends modifiés)
ansible-playbook -i Ansible/inventory/hosts.yml \
  Ansible/playbooks/nginx_reverse_proxy.yml --limit reverse-proxy

# 5. Recharger BIND9 (si nouvelles entrées DNS)
ansible-playbook -i Ansible/inventory/hosts.yml \
  Ansible/playbooks/bind9-container.yml --limit bind9_hosts
```

### Tests de validation
```bash
# EdgeDoc
curl -I -k https://edgedoc.lab.local
# Attendu: HTTP/2 200, hedgedoc-version: 1.10.5

# Taiga
curl -I -k https://taiga.lab.local
# Attendu: HTTP/2 200, content-type: text/html

# Vérifier conf.json Taiga
curl -s https://taiga.lab.local/conf.json -k | jq .api
# Attendu: "https://taiga.lab.local/api/v1/"

# DNS resolution
nslookup edgedoc.lab.local 172.16.100.254
nslookup taiga.lab.local 172.16.100.254
# Attendu: 172.16.100.253 (reverse-proxy)
```

---

## Maintenance et opérations

### Backups

#### EdgeDoc
```bash
# Backup MariaDB
ssh tools-manager "docker exec edgedoc-db mysqldump -uhedgedoc -phedgedocpass hedgedoc > /tmp/edgedoc_db_$(date +%F).sql"
scp tools-manager:/tmp/edgedoc_db_*.sql /backup/edgedoc/

# Backup uploads
ssh tools-manager "tar czf /tmp/edgedoc_uploads_$(date +%F).tar.gz /opt/edgedoc/uploads"
scp tools-manager:/tmp/edgedoc_uploads_*.tar.gz /backup/edgedoc/
```

#### Taiga
```bash
# Backup PostgreSQL
ssh tools-manager "docker exec src-taiga-db-1 pg_dump -U postgres taiga > /tmp/taiga_db_$(date +%F).sql"
scp tools-manager:/tmp/taiga_db_*.sql /backup/taiga/

# Backup volumes
ssh tools-manager "docker run --rm -v src_taiga-static-data:/data -v /tmp:/backup ubuntu tar czf /backup/taiga_static_$(date +%F).tar.gz /data"
scp tools-manager:/tmp/taiga_static_*.tar.gz /backup/taiga/
```

### Restauration

#### EdgeDoc
```bash
# Restore DB
scp /backup/edgedoc/edgedoc_db_2026-01-21.sql tools-manager:/tmp/
ssh tools-manager "docker exec -i edgedoc-db mysql -uhedgedoc -phedgedocpass hedgedoc < /tmp/edgedoc_db_2026-01-21.sql"

# Restore uploads
scp /backup/edgedoc/edgedoc_uploads_2026-01-21.tar.gz tools-manager:/tmp/
ssh tools-manager "tar xzf /tmp/edgedoc_uploads_*.tar.gz -C /"
```

#### Taiga
```bash
# Restore DB
scp /backup/taiga/taiga_db_2026-01-21.sql tools-manager:/tmp/
ssh tools-manager "docker exec -i src-taiga-db-1 psql -U postgres taiga < /tmp/taiga_db_2026-01-21.sql"

# Restore static
scp /backup/taiga/taiga_static_2026-01-21.tar.gz tools-manager:/tmp/
ssh tools-manager "docker run --rm -v src_taiga-static-data:/data -v /tmp:/backup ubuntu tar xzf /backup/taiga_static_*.tar.gz -C /"
```

### Mises à jour

#### EdgeDoc
```bash
# Pull nouvelles images
ssh tools-manager "cd /opt/edgedoc && docker compose pull"

# Recreate conteneurs
ssh tools-manager "cd /opt/edgedoc && docker compose up -d"

# Vérifier migrations
ssh tools-manager "docker logs edgedoc | tail -20"
```

#### Taiga
```bash
# Localiser docker-compose.yml
ssh tools-manager "find /home -name docker-compose.yml -path '*/taiga/*' 2>/dev/null"

# Pull et recreate
ssh tools-manager "cd /path/to/taiga && docker compose pull && docker compose up -d"

# Vérifier tous les services
ssh tools-manager "docker ps | grep taiga"
```

### Monitoring

#### Métriques à surveiller
```bash
# EdgeDoc
curl -s https://edgedoc.lab.local/api/status -k | jq .
# → Vérifier status, uptime

# Taiga
curl -s https://taiga.lab.local/api/v1/stats -k | jq .
# → Projets actifs, utilisateurs

# Conteneurs
ssh tools-manager "docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' | grep -E 'edgedoc|taiga'"

# Volumes
ssh tools-manager "df -h | grep -E 'docker|opt'"
```

#### Alertes recommandées
- Conteneurs down (healthcheck failed)
- Utilisation disque > 80% sur volumes
- MariaDB/PostgreSQL connexions max atteintes
- RabbitMQ queue buildup (Taiga)
- Temps de réponse API > 2s

---

## Évolutions futures

### EdgeDoc
1. **Authentification externe**: Configurer LDAP/OAuth (Keycloak, GitLab, etc.)
2. **Stockage S3**: Migrer uploads vers MinIO ou S3 pour scalabilité
3. **Haute disponibilité**: Multi-instances app avec load balancer + DB répliquée
4. **Secrets management**: Ansible Vault pour passwords et session secret

### Taiga
1. **Rôle Ansible**: Créer rôle idempotent pour déploiement/config Taiga
2. **Intégrations**: GitLab webhook pour sync issues/commits
3. **Notifications**: SMTP pour emails (invitations, notifications)
4. **Plugins**: Activer GitHub/GitLab importers si besoin
5. **Scaling**: Augmenter workers async si charge élevée

### Infrastructure
1. **Monitoring centralisé**: Exporter métriques vers Prometheus (déjà sur 172.16.100.60)
2. **Logs agrégés**: Loki + Promtail pour centralisation logs
3. **Certificats**: Let's Encrypt via DNS challenge ou CA interne avec PKI
4. **Backups automatisés**: Cron + script Ansible pour backups quotidiens vers NFS/S3

---

## Références

### Documentation officielle
- **HedgeDoc**: https://docs.hedgedoc.org/
- **Taiga**: https://docs.taiga.io/
- **Docker Compose**: https://docs.docker.com/compose/
- **MariaDB**: https://mariadb.org/documentation/
- **PostgreSQL**: https://www.postgresql.org/docs/

### Playbooks et rôles Ansible
```
Ansible/
├── playbooks/
│   ├── edgedoc.yml
│   ├── taiga.yml
│   ├── nginx_reverse_proxy.yml
│   └── bind9-container.yml
├── roles/
│   ├── edgedoc/
│   │   ├── defaults/main.yml
│   │   ├── tasks/main.yml
│   │   └── templates/docker-compose.yml.j2
│   └── nginx_reverse_proxy/
│       ├── defaults/main.yml
│       ├── tasks/
│       ├── templates/nginx.conf.j2
│       └── templates/docker-compose.yml.j2
└── inventory/
    ├── hosts.yml
    └── host_vars/
        ├── tools-manager.yml
        ├── reverse-proxy.yml
        └── bind9dns.yml
```

### URLs internes
- EdgeDoc local: http://172.16.100.20:8080
- Taiga local: http://172.16.100.20:9000
- MariaDB (EdgeDoc): 172.16.100.20:3306 (docker network interne uniquement)
- PostgreSQL (Taiga): 172.16.100.20:5432 (docker network interne uniquement)

### URLs publiques (via reverse proxy)
- EdgeDoc: https://edgedoc.lab.local
- Taiga: https://taiga.lab.local

---

**Dernière mise à jour**: 21 janvier 2026  
**Mainteneur**: Infrastructure Lab  
**Version**: 1.0
