# 🔷 Stack Monitoring : Prometheus + Grafana + Alertmanager


***

## 📍 Explication : Observabilité Infrastructure

### Définition

Une **stack monitoring** regroupe les outils permettant de collecter, stocker, visualiser et alerter sur l'état de l'infrastructure. La stack **Prometheus + Grafana + Alertmanager** est le standard DevOps pour l'observabilité moderne.

### Comparaison des solutions monitoring

| Solution | Type | Stockage | Visualisation | Alertes | Complexité |
| :-- | :-- | :-- | :-- | :-- | :-- |
| **Prometheus + Grafana** | Pull metrics | TSDB local | Dashboards avancés | Alertmanager | Moyenne |
| **Zabbix** | Agent-based | SQL | Intégré | Intégré | Élevée |
| **Nagios** | Check-based | Fichiers | Basique | Intégré | Élevée |
| **Datadog** | SaaS | Cloud | Cloud | Cloud | Faible (\$\$) |
| **ELK Stack** | Logs | Elasticsearch | Kibana | ElastAlert | Très élevée |

### Rôle dans l'architecture SSOT

```
┌─────────────────────────────────────────────────────────────┐
│ SSOT Observabilité Infrastructure                           │
├─────────────────────────────────────────────────────────────┤
│ • Terraform provisionne VM monitoring-stack                 │
│ • Ansible déploie stack Docker Compose (Prometheus/Grafana) │
│ • Ansible installe Node Exporter sur toutes VMs             │
│ • Prometheus auto-découvre targets depuis inventaire        │
│ • Grafana importe dashboards automatiquement                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Architecture Monitoring Centralisée                         │
├─────────────────────────────────────────────────────────────┤
│ Toutes VMs → Node Exporter (9100) → Prometheus (scrape)    │
│ Prometheus (9090) → Grafana (datasource)                   │
│ Prometheus → Alertmanager (9093) → Email/Slack             │
│ Admin → Grafana (3000) → Dashboards temps réel             │
└─────────────────────────────────────────────────────────────┘
```


***

## 📍 Cycle de vie : Stack Monitoring

### Phase 1 : Provisionnement VM (Terraform)

```
1. Définition VM monitoring-stack (SSOT)
   └─> terraform.tfvars
       ├─> IP : 172.16.100.40
       ├─> CPU : 2 cores
       ├─> RAM : 4 GB
       ├─> Disk : 50 GB
       └─> Pool : production

2. Terraform provisionne VM
   └─> terraform apply
       └─> VM créée sur Proxmox
       └─> Cloud-init configure réseau
       └─> SSH ansible fonctionnel

3. VM disponible
   └─> hostname : monitoring.lab.local
   └─> IP : 172.16.100.40
```


### Phase 2 : Configuration DNS (Bind9)

```
1. Ajout enregistrements DNS (SSOT)
   └─> group_vars/dns_hosts.yml
       ├─> monitoring.lab.local → 172.16.100.40
       ├─> grafana.lab.local → CNAME monitoring
       ├─> prometheus.lab.local → CNAME monitoring
       └─> alertmanager.lab.local → CNAME monitoring

2. Application configuration
   └─> ansible-playbook playbooks/bind9.yml
       └─> Reload Bind9

3. Test résolution
   └─> dig monitoring.lab.local @172.16.100.254
       └─> Retourne 172.16.100.40
```


### Phase 3 : Déploiement Stack Monitoring (Ansible)

```
1. Préparation infrastructure (rôle common)
   └─> Installation Docker + Docker Compose
   └─> Création répertoires /data/monitoring
   └─> Configuration firewall UFW

2. Déploiement Prometheus
   ├─> Génération prometheus.yml (targets depuis inventaire)
   ├─> Génération alert-rules.yml
   ├─> Volume persistant /data/prometheus
   └─> Container prometheus:v2.48.0

3. Déploiement Grafana
   ├─> Configuration datasource Prometheus (auto)
   ├─> Import dashboards JSON
   ├─> Volume persistant /data/grafana
   └─> Container grafana:10.2.3

4. Déploiement Alertmanager
   ├─> Configuration alertmanager.yml (SMTP)
   ├─> Volume persistant /data/alertmanager
   └─> Container alertmanager:v0.26.0

5. Stack Docker Compose up
   └─> docker-compose up -d
       ├─> prometheus (port 9090)
       ├─> grafana (port 3000)
       └─> alertmanager (port 9093)
```


### Phase 4 : Installation Node Exporter (Toutes VMs)

```
1. Téléchargement binaire officiel
   └─> node_exporter v1.7.0 (GitHub releases)

2. Installation systemd service
   └─> /etc/systemd/system/node_exporter.service
   └─> systemctl enable --now node_exporter

3. Configuration firewall
   └─> UFW allow from 172.16.100.40 to any port 9100

4. Validation
   └─> curl http://localhost:9100/metrics
       └─> Métriques système disponibles
```


### Phase 5 : Configuration Auto-Discovery

```
1. Ansible génère liste targets Prometheus
   └─> Depuis inventaire groups['all']
   └─> Template prometheus.yml.j2
       └─> static_configs:
             - targets:
                 - 172.16.100.254:9100  # dns-server
                 - 172.16.100.2:9100    # harbor
                 - 172.16.100.20:9100   # tools-manager
                 - 172.16.100.30:9100   # gitlab
                 - 172.16.100.40:9100   # monitoring-stack

2. Prometheus scrape automatiquement
   └─> Toutes les 15 secondes
   └─> Métriques stockées dans TSDB

3. Validation targets
   └─> http://monitoring.lab.local:9090/targets
       └─> Tous targets UP (vert)
```


### Phase 6 : Visualisation Grafana

```
1. Connexion Grafana
   └─> http://grafana.lab.local:3000
   └─> Login : admin / {{ vault_grafana_admin_password }}

2. Datasource Prometheus (auto-configuré)
   └─> URL : http://prometheus:9090
   └─> Access : Server (réseau Docker interne)

3. Dashboards importés automatiquement
   ├─> Node Exporter Full (ID 1860)
   ├─> Docker Containers (ID 193)
   └─> Prometheus Stats (ID 3662)

4. Visualisation temps réel
   └─> CPU, RAM, Disk, Network de toutes VMs
```


### Phase 7 : Configuration Alertes

```
1. Règles alertes Prometheus
   └─> alert-rules.yml
       ├─> InstanceDown (VM inaccessible)
       ├─> HighCPU (>80% pendant 5min)
       ├─> HighMemory (>90%)
       ├─> DiskSpaceLow (<10%)
       └─> ServiceDown (Docker container stop)

2. Alertmanager route notifications
   └─> alertmanager.yml
       ├─> Email (SMTP)
       ├─> Webhook (Slack optionnel)
       └─> Grouping (éviter spam)

3. Test alerte
   └─> Arrêter Node Exporter sur une VM
       └─> Alerte InstanceDown déclenchée
       └─> Email reçu dans les 2 minutes
```


***

## 📍 Architecture SSOT : Stack Monitoring

### Diagramme de flux SSOT

```
┌─────────────────────────────────────────────────────────────┐
│ SSOT Sources Monitoring                                     │
├─────────────────────────────────────────────────────────────┤
│ • terraform.tfvars → VM monitoring-stack                    │
│ • group_vars/monitoring_hosts.yml → Config stack            │
│ • group_vars/dns_hosts.yml → Enregistrements DNS           │
│ • secrets/monitoring.vault → Passwords chiffrés            │
│ • inventory/terraform.generated.yml → Auto-discovery targets│
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Provisionnement VM (Terraform)                              │
├─────────────────────────────────────────────────────────────┤
│ resource "proxmox_virtual_environment_vm" "monitoring" {    │
│   name = "monitoring-stack"                                 │
│   ip   = "172.16.100.40"                                    │
│   cpu  = 2                                                  │
│   mem  = 4096                                               │
│ }                                                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Configuration DNS (Ansible - Bind9)                         │
├─────────────────────────────────────────────────────────────┤
│ monitoring.lab.local     → 172.16.100.40                    │
│ grafana.lab.local        → CNAME monitoring.lab.local       │
│ prometheus.lab.local     → CNAME monitoring.lab.local       │
│ alertmanager.lab.local   → CNAME monitoring.lab.local       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Déploiement Stack (Ansible - Docker Compose)                │
├─────────────────────────────────────────────────────────────┤
│ services:                                                   │
│   prometheus:                                               │
│     image: prom/prometheus:v2.48.0                          │
│     ports: ["9090:9090"]                                    │
│     volumes:                                                │
│       - prometheus.yml (SSOT depuis inventaire)             │
│   grafana:                                                  │
│     image: grafana/grafana:10.2.3                           │
│     ports: ["3000:3000"]                                    │
│     environment:                                            │
│       - GF_SECURITY_ADMIN_PASSWORD={{ vault_password }}    │
│   alertmanager:                                             │
│     image: prom/alertmanager:v0.26.0                        │
│     ports: ["9093:9093"]                                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Installation Node Exporter (Ansible - Toutes VMs)          │
├─────────────────────────────────────────────────────────────┤
│ • Téléchargement binaire officiel                           │
│ • Service systemd                                           │
│ • Firewall (9100 depuis monitoring uniquement)             │
│ • Auto-ajout dans prometheus.yml via templating            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ État Final : Monitoring Opérationnel                        │
├─────────────────────────────────────────────────────────────┤
│ • Prometheus scrape toutes VMs (Node Exporter)             │
│ • Grafana affiche dashboards temps réel                     │
│ • Alertmanager envoie notifications (Email/Slack)           │
│ • Admin accède via http://grafana.lab.local:3000            │
└─────────────────────────────────────────────────────────────┘
```


### Architecture réseau monitoring

```
┌────────────────────────────────────────────────────────────────┐
│                    Réseau Production (vmbr0)                   │
│                      172.16.100.0/24                           │
└────────────────────────────────────────────────────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
    ┌────▼─────┐          ┌─────▼──────┐         ┌─────▼──────┐
    │ harbor   │          │  gitlab    │         │ dns-server │
    │ .100.2   │          │  .100.30   │         │ .100.254   │
    └────┬─────┘          └─────┬──────┘         └─────┬──────┘
         │                      │                       │
         │ Node Exporter:9100   │ Node Exporter:9100    │ Node Exporter:9100
         │                      │                       │
         └──────────────────────┼───────────────────────┘
                                │
                                │ Scrape toutes les 15s
                                │
                    ┌───────────▼────────────┐
                    │  monitoring-stack      │
                    │  172.16.100.40         │
                    ├────────────────────────┤
                    │ Docker Network:        │
                    │ ┌──────────────────┐   │
                    │ │ Prometheus:9090  │───┼──→ Scrape externe:9100
                    │ │  ↓               │   │
                    │ │ Alertmanager:9093│   │
                    │ │  ↑               │   │
                    │ │ Grafana:3000     │   │
                    │ └──────────────────┘   │
                    └────────────────────────┘
                                │
                                │ Accès Admin
                                ▼
                    ┌───────────────────────┐
                    │   Navigateur Web      │
                    │                       │
                    │ grafana.lab.local:3000│
                    └───────────────────────┘
```


***

## 📍 Fichiers et code détaillés

### Fichier 1 : `terraform.tfvars` (Ajout VM monitoring)

**Chemin** : `terraform.tfvars`
**Modification** : Ajout VM `monitoring-stack`
**Versionné** : ❌ Non (secrets)

```hcl
# ===================================================================
# SSOT Infrastructure : Ajout VM monitoring
# ===================================================================

nodes = {
  # Infrastructure existante
  dns-server = {
    ip     = "172.16.100.254"
    cpu    = 1
    mem    = 1024
    disk   = 20
    bridge = "vmbr0"
    pool   = "production"
    tags   = ["dns", "infra"]
  }

  harbor = {
    ip     = "172.16.100.2"
    cpu    = 4
    mem    = 8192
    disk   = 100
    bridge = "vmbr0"
    pool   = "production"
    tags   = ["harbor", "registry", "prod"]
  }

  tools-manager = {
    ip     = "172.16.100.20"
    cpu    = 4
    mem    = 8192
    disk   = 50
    bridge = "vmbr0"
    pool   = "production"
    tags   = ["tools", "docs", "prod"]
  }

  gitlab = {
    ip     = "172.16.100.30"
    cpu    = 4
    mem    = 8192
    disk   = 100
    bridge = "vmbr0"
    pool   = "production"
    tags   = ["git", "ci", "prod"]
  }

  # ===================================================================
  # NOUVEAUTÉ : Stack Monitoring Centralisée
  # ===================================================================
  monitoring-stack = {
    ip     = "172.16.100.40"
    cpu    = 2                    # Suffisant pour Prometheus + Grafana
    mem    = 4096                 # 4 GB RAM
    disk   = 50                   # Métriques + logs
    bridge = "vmbr0"
    pool   = "production"
    tags   = ["monitoring", "observability", "prod"]
  }
}
```


***

### Fichier 2 : `group_vars/monitoring_hosts.yml` (Config SSOT stack)

**Chemin** : `Ansible/group_vars/monitoring_hosts.yml`
**Rôle** : Configuration SSOT stack monitoring
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# SSOT Configuration Stack Monitoring (Prometheus + Grafana)
# ===================================================================

# ===================================================================
# 1. Versions officielles (SSOT)
# ===================================================================
prometheus_version: "v2.48.0"
grafana_version: "10.2.3"
alertmanager_version: "v0.26.0"
node_exporter_version: "1.7.0"

# ===================================================================
# 2. Configuration réseau (SSOT)
# ===================================================================
monitoring_hostname: "monitoring.lab.local"
monitoring_domain: "lab.local"

# Ports exposition
prometheus_port: 9090
grafana_port: 3000
alertmanager_port: 9093
node_exporter_port: 9100

# ===================================================================
# 3. Stockage (SSOT)
# ===================================================================
monitoring_data_volume: "/data/monitoring"
prometheus_data_path: "{{ monitoring_data_volume }}/prometheus"
grafana_data_path: "{{ monitoring_data_volume }}/grafana"
alertmanager_data_path: "{{ monitoring_data_volume }}/alertmanager"

# ===================================================================
# 4. Configuration Prometheus (SSOT)
# ===================================================================
prometheus_retention_time: "15d"        # Rétention 15 jours
prometheus_retention_size: "0"          # Pas de limite taille
prometheus_scrape_interval: "15s"       # Scrape toutes les 15s
prometheus_evaluation_interval: "15s"   # Évaluation règles

# Auto-discovery targets depuis inventaire Ansible
# Généré dynamiquement dans template prometheus.yml.j2
prometheus_scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: node-exporter
    scrape_interval: 15s
    static_configs:
      - targets: []  # Rempli dynamiquement depuis groups['all']
  
  - job_name: docker
    scrape_interval: 30s
    static_configs:
      - targets:
          - 'harbor.lab.local:9323'
          - 'gitlab.lab.local:9323'

# ===================================================================
# 5. Configuration Grafana (SSOT)
# ===================================================================
grafana_admin_user: "admin"
grafana_admin_password: "{{ vault_grafana_admin_password }}"
grafana_allow_sign_up: false
grafana_anonymous_enabled: false

# Datasources (auto-configuré)
grafana_datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    is_default: true
    editable: false

# Dashboards à importer automatiquement (Grafana.com)
grafana_dashboards:
  - dashboard_id: 1860        # Node Exporter Full
    revision: 31
    datasource: Prometheus
  
  - dashboard_id: 193         # Docker Containers
    revision: 1
    datasource: Prometheus
  
  - dashboard_id: 3662        # Prometheus 2.0 Stats
    revision: 2
    datasource: Prometheus

# ===================================================================
# 6. Configuration Alertmanager (SSOT)
# ===================================================================
alertmanager_resolve_timeout: "5m"

# Configuration SMTP (notifications)
alertmanager_smtp_enabled: true
alertmanager_smtp_host: "smtp.lab.local:587"
alertmanager_smtp_from: "alertmanager@lab.local"
alertmanager_smtp_auth_username: "alertmanager"
alertmanager_smtp_auth_password: "{{ vault_alertmanager_smtp_password }}"
alertmanager_smtp_require_tls: false

# Destinataires alertes
alertmanager_receivers:
  - name: email-admin
    email_configs:
      - to: "admin@lab.local"
        send_resolved: true
  
  - name: webhook-slack
    webhook_configs:
      - url: "{{ vault_slack_webhook_url | default('') }}"
        send_resolved: true

# Routing alertes
alertmanager_route:
  receiver: email-admin
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

# ===================================================================
# 7. Règles d'alertes Prometheus (SSOT)
# ===================================================================
prometheus_alert_rules:
  # Alerte instance down
  - alert: InstanceDown
    expr: up == 0
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "Instance {{ $labels.instance }} down"
      description: "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 2 minutes."
  
  # CPU élevé
  - alert: HighCPU
    expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High CPU on {{ $labels.instance }}"
      description: "CPU usage is above 80% (current: {{ $value }}%)"
  
  # Mémoire élevée
  - alert: HighMemory
    expr: (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 < 10
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage on {{ $labels.instance }}"
      description: "Memory available is below 10% (current: {{ $value }}%)"
  
  # Espace disque faible
  - alert: DiskSpaceLow
    expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 10
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Low disk space on {{ $labels.instance }}"
      description: "Disk space available is below 10% (current: {{ $value }}%)"
  
  # Service Docker down
  - alert: DockerServiceDown
    expr: absent(up{job="docker"})
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "Docker service monitoring unavailable"
      description: "Docker metrics endpoint is not responding"

# ===================================================================
# 8. Configuration Node Exporter (SSOT)
# ===================================================================
node_exporter_download_url: "https://github.com/prometheus/node_exporter/releases/download/v{{ node_exporter_version }}/node_exporter-{{ node_exporter_version }}.linux-amd64.tar.gz"
node_exporter_install_dir: "/opt/node_exporter"
node_exporter_user: "node_exporter"
node_exporter_group: "node_exporter"

# Collectors activés (par défaut tous sauf quelques-uns)
node_exporter_enabled_collectors:
  - cpu
  - meminfo
  - diskstats
  - filesystem
  - netdev
  - loadavg
  - time
  - systemd

# ===================================================================
# 9. Configuration Firewall (SSOT)
# ===================================================================
monitoring_firewall_rules:
  # Prometheus
  - port: "{{ prometheus_port }}"
    proto: tcp
    rule: allow
    comment: "Prometheus UI"
  
  # Grafana
  - port: "{{ grafana_port }}"
    proto: tcp
    rule: allow
    comment: "Grafana UI"
  
  # Alertmanager
  - port: "{{ alertmanager_port }}"
    proto: tcp
    rule: allow
    comment: "Alertmanager UI"

# Node Exporter firewall (uniquement depuis monitoring-stack)
node_exporter_firewall_allow_from: "172.16.100.40"

# ===================================================================
# 10. Configuration backup (SSOT)
# ===================================================================
monitoring_backup_enabled: true
monitoring_backup_path: "/backup/monitoring"
monitoring_backup_retention_days: 30

# Cron backup quotidien 2h du matin
monitoring_backup_cron:
  hour: "2"
  minute: "0"
```


***

### Fichier 3 : `secrets/monitoring.vault` (Passwords chiffrés)

**Chemin** : `Ansible/group_vars/secrets/monitoring.vault`
**Rôle** : Secrets Ansible Vault
**Versionné** : ✅ Oui (chiffré)

```yaml
---
# ===================================================================
# Secrets Stack Monitoring (Ansible Vault)
# ===================================================================
# Chiffrer : ansible-vault encrypt secrets/monitoring.vault
# Éditer : ansible-vault edit secrets/monitoring.vault

# Grafana
vault_grafana_admin_password: "Graf@naAdm!n2024SecureP@ss"

# Alertmanager SMTP
vault_alertmanager_smtp_password: "SmtpAl3rtM@nagerPass2024"

# Slack webhook (optionnel)
vault_slack_webhook_url: "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX"
```


***

### Fichier 4 : `group_vars/dns_hosts.yml` (Ajout DNS monitoring)

**Chemin** : `Ansible/group_vars/dns_hosts.yml`
**Modification** : Ajout enregistrements DNS
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# SSOT Configuration Bind9 DNS
# ===================================================================

bind9_zones:
  - name: "lab.local"
    type: master
    file: "db.lab.local"
    records:
      # Infrastructure existante
      - name: "dns"
        type: A
        value: "172.16.100.254"
      
      - name: "harbor"
        type: A
        value: "172.16.100.2"
      
      - name: "registry"
        type: CNAME
        value: "harbor.lab.local."
      
      - name: "tools"
        type: A
        value: "172.16.100.20"
      
      - name: "gitlab"
        type: A
        value: "172.16.100.30"
      
      # ===================================================================
      # NOUVEAUTÉ : Stack Monitoring
      # ===================================================================
      - name: "monitoring"
        type: A
        value: "172.16.100.40"
      
      - name: "grafana"
        type: CNAME
        value: "monitoring.lab.local."
      
      - name: "prometheus"
        type: CNAME
        value: "monitoring.lab.local."
      
      - name: "alertmanager"
        type: CNAME
        value: "monitoring.lab.local."
```


***

### Fichier 5 : `roles/monitoring/defaults/main.yml` (Variables défaut)

**Chemin** : `Ansible/roles/monitoring/defaults/main.yml`
**Rôle** : Variables par défaut (écrasées par group_vars)
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Variables par défaut rôle monitoring
# Ces valeurs sont écrasées par group_vars/monitoring_hosts.yml
# ===================================================================

# Versions
prometheus_version: "v2.48.0"
grafana_version: "10.2.3"
alertmanager_version: "v0.26.0"

# Réseau
monitoring_hostname: "monitoring.lab.local"
prometheus_port: 9090
grafana_port: 3000
alertmanager_port: 9093

# Stockage
monitoring_data_volume: "/data/monitoring"

# Prometheus
prometheus_retention_time: "15d"
prometheus_scrape_interval: "15s"

# Grafana
grafana_admin_user: "admin"
grafana_admin_password: "changeme"  # Écrasé par Vault

# Alertmanager
alertmanager_smtp_enabled: false

# Backup
monitoring_backup_enabled: false
```


***

### Fichier 6 : `roles/monitoring/tasks/main.yml` (Orchestration)

**Chemin** : `Ansible/roles/monitoring/tasks/main.yml`
**Rôle** : Point d'entrée rôle monitoring
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Rôle monitoring : Orchestration déploiement stack (idempotent)
# ===================================================================

- name: Inclure tasks prérequis
  ansible.builtin.import_tasks: prerequisites.yml
  tags: ['monitoring', 'prerequisites']

- name: Inclure tasks Prometheus
  ansible.builtin.import_tasks: prometheus.yml
  tags: ['monitoring', 'prometheus']

- name: Inclure tasks Grafana
  ansible.builtin.import_tasks: grafana.yml
  tags: ['monitoring', 'grafana']

- name: Inclure tasks Alertmanager
  ansible.builtin.import_tasks: alertmanager.yml
  tags: ['monitoring', 'alertmanager']

- name: Inclure tasks déploiement Docker Compose
  ansible.builtin.import_tasks: deploy.yml
  tags: ['monitoring', 'deploy']

- name: Inclure tasks validation
  ansible.builtin.import_tasks: validation.yml
  tags: ['monitoring', 'validation']
```


***

### Fichier 7 : `roles/monitoring/tasks/prerequisites.yml` (Prérequis)

**Chemin** : `Ansible/roles/monitoring/tasks/prerequisites.yml`
**Rôle** : Préparation infrastructure (idempotent)
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Tasks : Prérequis infrastructure monitoring (idempotent)
# ===================================================================

- name: Installer packages requis
  ansible.builtin.apt:
    name:
      - docker.io
      - docker-compose
      - python3-docker
      - python3-requests
      - curl
      - jq
    state: present
    update_cache: true
  tags: ['monitoring', 'packages']

- name: Créer répertoires data (idempotent)
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: root
    group: root
    mode: '0755'
  loop:
    - "{{ monitoring_data_volume }}"
    - "{{ prometheus_data_path }}"
    - "{{ grafana_data_path }}"
    - "{{ alertmanager_data_path }}"
    - "{{ monitoring_data_volume }}/config"
    - "{{ grafana_data_path }}/provisioning/datasources"
    - "{{ grafana_data_path }}/provisioning/dashboards"
  tags: ['monitoring', 'directories']

- name: Configurer permissions Prometheus data
  ansible.builtin.file:
    path: "{{ prometheus_data_path }}"
    owner: "65534"  # UID nobody (Prometheus container)
    group: "65534"
    mode: '0755'
    recurse: true
  tags: ['monitoring', 'permissions']

- name: Configurer permissions Grafana data
  ansible.builtin.file:
    path: "{{ grafana_data_path }}"
    owner: "472"    # UID grafana (Grafana container)
    group: "472"
    mode: '0755'
    recurse: true
  tags: ['monitoring', 'permissions']

- name: Configurer firewall UFW (idempotent)
  community.general.ufw:
    rule: "{{ item.rule }}"
    port: "{{ item.port }}"
    proto: "{{ item.proto }}"
    comment: "{{ item.comment }}"
  loop: "{{ monitoring_firewall_rules }}"
  when: firewall_enabled | default(true)
  tags: ['monitoring', 'firewall']
```


***

### Fichier 8 : `roles/monitoring/tasks/prometheus.yml` (Config Prometheus)

**Chemin** : `Ansible/roles/monitoring/tasks/prometheus.yml`
**Rôle** : Configuration Prometheus (idempotent)
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Tasks : Configuration Prometheus (idempotent)
# ===================================================================

- name: Générer configuration Prometheus (SSOT)
  ansible.builtin.template:
    src: prometheus.yml.j2
    dest: "{{ monitoring_data_volume }}/config/prometheus.yml"
    owner: root
    group: root
    mode: '0644'
  notify: Restart monitoring stack
  tags: ['monitoring', 'prometheus', 'config']

- name: Générer règles d'alertes Prometheus (SSOT)
  ansible.builtin.template:
    src: alert-rules.yml.j2
    dest: "{{ monitoring_data_volume }}/config/alert-rules.yml"
    owner: root
    group: root
    mode: '0644'
  notify: Restart monitoring stack
  tags: ['monitoring', 'prometheus', 'alerts']

- name: Afficher targets Prometheus auto-découverts
  ansible.builtin.debug:
    msg:
      - "=========================================="
      - "Targets Prometheus (auto-discovery)"
      - "=========================================="
      - "{{ groups['all'] | map('extract', hostvars, 'ansible_host') | map('regex_replace', '^(.*)$', '\\1:9100') | list }}"
  tags: ['monitoring', 'prometheus', 'debug']
```


***

### Fichier 9 : `roles/monitoring/templates/prometheus.yml.j2` (Template Prometheus)

**Chemin** : `Ansible/roles/monitoring/templates/prometheus.yml.j2`
**Rôle** : Configuration Prometheus avec auto-discovery
**Versionné** : ✅ Oui

```yaml
# ===================================================================
# Configuration Prometheus (généré par Ansible)
# Généré le : {{ ansible_date_time.iso8601 }}
# ===================================================================

global:
  scrape_interval: {{ prometheus_scrape_interval }}
  evaluation_interval: {{ prometheus_evaluation_interval }}
  external_labels:
    cluster: 'lab-proxmox'
    environment: 'production'

# ===================================================================
# Configuration Alertmanager
# ===================================================================
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - 'alertmanager:{{ alertmanager_port }}'

# ===================================================================
# Règles d'alertes
# ===================================================================
rule_files:
  - '/etc/prometheus/alert-rules.yml'

# ===================================================================
# Scrape configurations (auto-discovery depuis inventaire Ansible)
# ===================================================================
scrape_configs:
  # Prometheus lui-même
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:{{ prometheus_port }}']
        labels:
          instance: 'monitoring-stack'
          service: 'prometheus'

  # ===================================================================
  # Node Exporter (auto-discovery depuis groups['all'])
  # ===================================================================
  - job_name: 'node-exporter'
    scrape_interval: {{ prometheus_scrape_interval }}
    static_configs:
      - targets:
{% for host in groups['all'] %}
          - '{{ hostvars[host].ansible_host }}:{{ node_exporter_port }}'
{% endfor %}
        labels:
          cluster: 'lab-proxmox'

  # ===================================================================
  # Docker metrics (si exposés par Harbor/GitLab)
  # ===================================================================
  - job_name: 'docker'
    scrape_interval: 30s
    static_configs:
      - targets:
          - 'harbor.{{ monitoring_domain }}:9323'
          - 'gitlab.{{ monitoring_domain }}:9323'
        labels:
          cluster: 'lab-proxmox'

  # ===================================================================
  # Blackbox Exporter (monitoring externe - optionnel)
  # ===================================================================
  # - job_name: 'blackbox'
  #   metrics_path: /probe
  #   params:
  #     module: [http_2xx]
  #   static_configs:
  #     - targets:
  #         - http://grafana.{{ monitoring_domain }}:{{ grafana_port }}
  #         - http://harbor.{{ monitoring_domain }}
  #   relabel_configs:
  #     - source_labels: [__address__]
  #       target_label: __param_target
  #     - source_labels: [__param_target]
  #       target_label: instance
  #     - target_label: __address__
  #       replacement: blackbox-exporter:9115
```


***

## 📊 Tableau récapitulatif des fichiers

| Fichier | Chemin | Rôle SSOT | Versionné |
| :-- | :-- | :-- | :-- |
| `terraform.tfvars` | Racine | VM monitoring-stack | ❌ Non |
| `monitoring_hosts.yml` | `Ansible/group_vars/` | Config stack SSOT | ✅ Oui |
| `monitoring.vault` | `Ansible/group_vars/secrets/` | Passwords | ✅ Oui (Vault) |
| `dns_hosts.yml` | `Ansible/group_vars/` | DNS monitoring | ✅ Oui |
| `monitoring/defaults/main.yml` | `Ansible/roles/monitoring/` | Valeurs défaut | ✅ Oui |
| `monitoring/tasks/main.yml` | `Ansible/roles/monitoring/` | Orchestration | ✅ Oui |
| `monitoring/tasks/prerequisites.yml` | `Ansible/roles/monitoring/` | Prérequis | ✅ Oui |
| `monitoring/tasks/prometheus.yml` | `Ansible/roles/monitoring/` | Config Prometheus | ✅ Oui |
| `monitoring/templates/prometheus.yml.j2` | `Ansible/roles/monitoring/templates/` | Template Prometheus | ✅ Oui |
| `monitoring/templates/docker-compose.yml.j2` | `Ansible/roles/monitoring/templates/` | Stack Docker | ✅ Oui |
| `monitoring/templates/alert-rules.yml.j2` | `Ansible/roles/monitoring/templates/` | Alertes | ✅ Oui |
| `monitoring/templates/alertmanager.yml.j2` | `Ansible/roles/monitoring/templates/` | Alertmanager | ✅ Oui |
| `monitoring/templates/grafana-datasources.yml.j2` | `Ansible/roles/monitoring/templates/` | Datasource Grafana | ✅ Oui |
| `node_exporter/tasks/main.yml` | `Ansible/roles/node_exporter/` | Install Node Exporter | ✅ Oui |
| `node_exporter/templates/node_exporter.service.j2` | `Ansible/roles/node_exporter/templates/` | Service systemd | ✅ Oui |
| `playbooks/monitoring.yml` | `Ansible/playbooks/` | Playbook déploiement | ✅ Oui |


***

## 🎯 Workflow Déploiement Complet

### Commandes déploiement

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "Déploiement Stack Monitoring"
echo "=========================================="

# 1. Créer VM monitoring-stack
echo "[1/5] Provisionnement VM (Terraform)..."
terraform apply -target=proxmox_virtual_environment_vm.vm[\"monitoring-stack\"]

echo "Attente cloud-init (60s)..."
sleep 60

# 2. Configuration DNS
echo "[2/5] Ajout enregistrements DNS..."
cd Ansible/
ansible-playbook playbooks/bind9.yml

# 3. Test résolution DNS
echo "[3/5] Test résolution DNS..."
dig monitoring.lab.local @172.16.100.254 +short

# 4. Déploiement stack monitoring
echo "[4/5] Déploiement Prometheus + Grafana + Alertmanager..."
ansible-playbook playbooks/monitoring.yml --ask-vault-pass

# 5. Installation Node Exporter toutes VMs
echo "[5/5] Installation Node Exporter sur toutes VMs..."
ansible-playbook playbooks/monitoring.yml --tags node_exporter

echo ""
echo "=========================================="
echo "✓ Déploiement terminé"
echo "=========================================="
echo "Services disponibles :"
echo "  - Prometheus:    http://monitoring.lab.local:9090"
echo "  - Grafana:       http://grafana.lab.local:3000"
echo "  - Alertmanager:  http://monitoring.lab.local:9093"
echo ""
echo "Identifiants Grafana :"
echo "  - Username: admin"
echo "  - Password: (voir Ansible Vault)"
echo "=========================================="
```


***

