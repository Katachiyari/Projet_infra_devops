# 🔷 Code Complet : Stack Monitoring


***

## 📦 Fichiers Templates et Tasks

### Fichier 10 : `roles/monitoring/tasks/grafana.yml` (Config Grafana)

**Chemin** : `Ansible/roles/monitoring/tasks/grafana.yml`
**Rôle** : Configuration Grafana (idempotent)
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Tasks : Configuration Grafana (idempotent)
# ===================================================================

- name: Créer répertoire provisioning Grafana datasources
  ansible.builtin.file:
    path: "{{ grafana_data_path }}/provisioning/datasources"
    state: directory
    owner: "472"
    group: "472"
    mode: '0755'
  tags: ['monitoring', 'grafana', 'provisioning']

- name: Créer répertoire provisioning Grafana dashboards
  ansible.builtin.file:
    path: "{{ grafana_data_path }}/provisioning/dashboards"
    state: directory
    owner: "472"
    group: "472"
    mode: '0755'
  tags: ['monitoring', 'grafana', 'provisioning']

- name: Générer configuration datasource Prometheus (SSOT)
  ansible.builtin.template:
    src: grafana-datasources.yml.j2
    dest: "{{ grafana_data_path }}/provisioning/datasources/prometheus.yml"
    owner: "472"
    group: "472"
    mode: '0644'
  notify: Restart monitoring stack
  tags: ['monitoring', 'grafana', 'datasource']

- name: Générer configuration provisioning dashboards (SSOT)
  ansible.builtin.template:
    src: grafana-dashboards-provisioning.yml.j2
    dest: "{{ grafana_data_path }}/provisioning/dashboards/default.yml"
    owner: "472"
    group: "472"
    mode: '0644'
  notify: Restart monitoring stack
  tags: ['monitoring', 'grafana', 'dashboards']

- name: Créer répertoire dashboards JSON
  ansible.builtin.file:
    path: "{{ monitoring_data_volume }}/dashboards"
    state: directory
    owner: "472"
    group: "472"
    mode: '0755'
  tags: ['monitoring', 'grafana', 'dashboards']

- name: Télécharger dashboards Grafana officiels
  ansible.builtin.get_url:
    url: "https://grafana.com/api/dashboards/{{ item.dashboard_id }}/revisions/{{ item.revision }}/download"
    dest: "{{ monitoring_data_volume }}/dashboards/{{ item.dashboard_id }}.json"
    owner: "472"
    group: "472"
    mode: '0644'
  loop: "{{ grafana_dashboards }}"
  register: dashboard_download
  failed_when: false
  tags: ['monitoring', 'grafana', 'dashboards']

- name: Afficher résultat téléchargement dashboards
  ansible.builtin.debug:
    msg: "Dashboard {{ item.item.dashboard_id }} : {{ 'OK' if item.status_code == 200 else 'ÉCHEC' }}"
  loop: "{{ dashboard_download.results }}"
  when: dashboard_download is defined
  tags: ['monitoring', 'grafana', 'dashboards']
```


***

### Fichier 11 : `roles/monitoring/tasks/alertmanager.yml` (Config Alertmanager)

**Chemin** : `Ansible/roles/monitoring/tasks/alertmanager.yml`
**Rôle** : Configuration Alertmanager (idempotent)
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Tasks : Configuration Alertmanager (idempotent)
# ===================================================================

- name: Générer configuration Alertmanager (SSOT)
  ansible.builtin.template:
    src: alertmanager.yml.j2
    dest: "{{ monitoring_data_volume }}/config/alertmanager.yml"
    owner: root
    group: root
    mode: '0644'
  notify: Restart monitoring stack
  tags: ['monitoring', 'alertmanager', 'config']

- name: Valider configuration Alertmanager (syntax check)
  ansible.builtin.command:
    cmd: >
      docker run --rm
      -v {{ monitoring_data_volume }}/config/alertmanager.yml:/alertmanager.yml
      prom/alertmanager:{{ alertmanager_version }}
      amtool check-config /alertmanager.yml
  register: alertmanager_validation
  changed_when: false
  failed_when: alertmanager_validation.rc != 0
  tags: ['monitoring', 'alertmanager', 'validation']

- name: Afficher résultat validation Alertmanager
  ansible.builtin.debug:
    msg: "✓ Configuration Alertmanager valide"
  when: alertmanager_validation.rc == 0
  tags: ['monitoring', 'alertmanager', 'validation']
```


***

### Fichier 12 : `roles/monitoring/tasks/deploy.yml` (Déploiement Docker Compose)

**Chemin** : `Ansible/roles/monitoring/tasks/deploy.yml`
**Rôle** : Déploiement stack Docker Compose (idempotent)
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Tasks : Déploiement Docker Compose (idempotent)
# ===================================================================

- name: Générer docker-compose.yml (SSOT)
  ansible.builtin.template:
    src: docker-compose.yml.j2
    dest: "{{ monitoring_data_volume }}/docker-compose.yml"
    owner: root
    group: root
    mode: '0644'
  notify: Restart monitoring stack
  tags: ['monitoring', 'deploy']

- name: Valider docker-compose.yml (syntax check)
  ansible.builtin.command:
    cmd: docker-compose -f {{ monitoring_data_volume }}/docker-compose.yml config
  args:
    chdir: "{{ monitoring_data_volume }}"
  register: compose_validation
  changed_when: false
  failed_when: compose_validation.rc != 0
  tags: ['monitoring', 'deploy', 'validation']

- name: Démarrer stack monitoring (idempotent)
  community.docker.docker_compose:
    project_src: "{{ monitoring_data_volume }}"
    state: present
    pull: true
    remove_orphans: true
  register: compose_result
  tags: ['monitoring', 'deploy']

- name: Attendre démarrage services (health check)
  ansible.builtin.wait_for:
    host: "{{ monitoring_hostname }}"
    port: "{{ item }}"
    state: started
    delay: 5
    timeout: 120
  loop:
    - "{{ prometheus_port }}"
    - "{{ grafana_port }}"
    - "{{ alertmanager_port }}"
  tags: ['monitoring', 'deploy', 'healthcheck']

- name: Afficher résultat déploiement
  ansible.builtin.debug:
    msg:
      - "=========================================="
      - "Stack Monitoring déployée avec succès"
      - "=========================================="
      - "Prometheus:   http://{{ monitoring_hostname }}:{{ prometheus_port }}"
      - "Grafana:      http://grafana.{{ monitoring_domain }}:{{ grafana_port }}"
      - "Alertmanager: http://{{ monitoring_hostname }}:{{ alertmanager_port }}"
      - "=========================================="
  tags: ['monitoring', 'deploy']
```


***

### Fichier 13 : `roles/monitoring/tasks/validation.yml` (Tests validation)

**Chemin** : `Ansible/roles/monitoring/tasks/validation.yml`
**Rôle** : Validation déploiement (idempotent)
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Tasks : Validation déploiement stack (idempotent)
# ===================================================================

- name: Test API Prometheus (health check)
  ansible.builtin.uri:
    url: "http://{{ monitoring_hostname }}:{{ prometheus_port }}/-/healthy"
    method: GET
    status_code: 200
  register: prometheus_health
  retries: 3
  delay: 10
  until: prometheus_health.status == 200
  tags: ['monitoring', 'validation']

- name: Test API Grafana (health check)
  ansible.builtin.uri:
    url: "http://grafana.{{ monitoring_domain }}:{{ grafana_port }}/api/health"
    method: GET
    status_code: 200
  register: grafana_health
  retries: 3
  delay: 10
  until: grafana_health.status == 200
  tags: ['monitoring', 'validation']

- name: Test API Alertmanager (health check)
  ansible.builtin.uri:
    url: "http://{{ monitoring_hostname }}:{{ alertmanager_port }}/-/healthy"
    method: GET
    status_code: 200
  register: alertmanager_health
  retries: 3
  delay: 10
  until: alertmanager_health.status == 200
  tags: ['monitoring', 'validation']

- name: Récupérer targets Prometheus
  ansible.builtin.uri:
    url: "http://{{ monitoring_hostname }}:{{ prometheus_port }}/api/v1/targets"
    method: GET
    return_content: true
  register: prometheus_targets
  tags: ['monitoring', 'validation']

- name: Compter targets UP
  ansible.builtin.set_fact:
    targets_up: "{{ prometheus_targets.json.data.activeTargets | selectattr('health', 'equalto', 'up') | list | length }}"
    targets_total: "{{ prometheus_targets.json.data.activeTargets | length }}"
  tags: ['monitoring', 'validation']

- name: Afficher état targets Prometheus
  ansible.builtin.debug:
    msg:
      - "=========================================="
      - "État Prometheus Targets"
      - "=========================================="
      - "Targets UP:    {{ targets_up }}/{{ targets_total }}"
      - "Targets DOWN:  {{ targets_total | int - targets_up | int }}"
      - "=========================================="
  tags: ['monitoring', 'validation']

- name: Vérifier datasource Grafana (Prometheus)
  ansible.builtin.uri:
    url: "http://grafana.{{ monitoring_domain }}:{{ grafana_port }}/api/datasources"
    method: GET
    user: "{{ grafana_admin_user }}"
    password: "{{ grafana_admin_password }}"
    force_basic_auth: true
    return_content: true
  register: grafana_datasources
  tags: ['monitoring', 'validation']

- name: Afficher datasources Grafana
  ansible.builtin.debug:
    msg: "Datasources configurés : {{ grafana_datasources.json | map(attribute='name') | list }}"
  tags: ['monitoring', 'validation']

- name: Récapitulatif validation
  ansible.builtin.debug:
    msg:
      - ""
      - "=========================================="
      - "✓ Validation Stack Monitoring Réussie"
      - "=========================================="
      - "Prometheus:    {{ 'OK' if prometheus_health.status == 200 else 'FAIL' }}"
      - "Grafana:       {{ 'OK' if grafana_health.status == 200 else 'FAIL' }}"
      - "Alertmanager:  {{ 'OK' if alertmanager_health.status == 200 else 'FAIL' }}"
      - "Targets UP:    {{ targets_up }}/{{ targets_total }}"
      - "Datasources:   {{ grafana_datasources.json | length }}"
      - "=========================================="
      - ""
      - "Accès Web :"
      - "  • Prometheus:    http://{{ monitoring_hostname }}:{{ prometheus_port }}"
      - "  • Grafana:       http://grafana.{{ monitoring_domain }}:{{ grafana_port }}"
      - "  • Alertmanager:  http://{{ monitoring_hostname }}:{{ alertmanager_port }}"
      - ""
      - "Identifiants Grafana :"
      - "  • Username: {{ grafana_admin_user }}"
      - "  • Password: (Ansible Vault)"
      - "=========================================="
  tags: ['monitoring', 'validation']
```


***

### Fichier 14 : `roles/monitoring/templates/docker-compose.yml.j2` (Stack complète)

**Chemin** : `Ansible/roles/monitoring/templates/docker-compose.yml.j2`
**Rôle** : Docker Compose stack monitoring
**Versionné** : ✅ Oui

```yaml
# ===================================================================
# Docker Compose : Stack Monitoring (Prometheus + Grafana + Alertmanager)
# Généré par Ansible le : {{ ansible_date_time.iso8601 }}
# ===================================================================

version: '3.8'

# ===================================================================
# Réseaux Docker
# ===================================================================
networks:
  monitoring:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

# ===================================================================
# Volumes persistants
# ===================================================================
volumes:
  prometheus_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: {{ prometheus_data_path }}
  
  grafana_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: {{ grafana_data_path }}
  
  alertmanager_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: {{ alertmanager_data_path }}

# ===================================================================
# Services
# ===================================================================
services:
  
  # =================================================================
  # Prometheus : Collecte et stockage métriques
  # =================================================================
  prometheus:
    image: prom/prometheus:{{ prometheus_version }}
    container_name: prometheus
    restart: unless-stopped
    user: "65534:65534"  # nobody:nogroup (sécurité)
    
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time={{ prometheus_retention_time }}'
      - '--storage.tsdb.retention.size={{ prometheus_retention_size }}'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'
    
    ports:
      - "{{ prometheus_port }}:9090"
    
    volumes:
      - prometheus_data:/prometheus
      - {{ monitoring_data_volume }}/config/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - {{ monitoring_data_volume }}/config/alert-rules.yml:/etc/prometheus/alert-rules.yml:ro
    
    networks:
      monitoring:
        ipv4_address: 172.20.0.10
    
    labels:
      - "com.monitoring.service=prometheus"
      - "com.monitoring.description=Metrics collection and storage"
    
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:9090/-/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
  
  # =================================================================
  # Grafana : Visualisation dashboards
  # =================================================================
  grafana:
    image: grafana/grafana:{{ grafana_version }}
    container_name: grafana
    restart: unless-stopped
    user: "472:472"  # grafana user (sécurité)
    
    environment:
      # Configuration admin
      - GF_SECURITY_ADMIN_USER={{ grafana_admin_user }}
      - GF_SECURITY_ADMIN_PASSWORD={{ grafana_admin_password }}
      
      # Configuration serveur
      - GF_SERVER_ROOT_URL=http://grafana.{{ monitoring_domain }}:{{ grafana_port }}
      - GF_SERVER_DOMAIN=grafana.{{ monitoring_domain }}
      
      # Sécurité
      - GF_USERS_ALLOW_SIGN_UP={{ grafana_allow_sign_up | lower }}
      - GF_AUTH_ANONYMOUS_ENABLED={{ grafana_anonymous_enabled | lower }}
      - GF_AUTH_DISABLE_LOGIN_FORM=false
      
      # Datasources et dashboards (provisioning automatique)
      - GF_PATHS_PROVISIONING=/etc/grafana/provisioning
      
      # Logs
      - GF_LOG_MODE=console
      - GF_LOG_LEVEL=info
      
      # Performance
      - GF_DATABASE_TYPE=sqlite3
      - GF_DATABASE_PATH=/var/lib/grafana/grafana.db
    
    ports:
      - "{{ grafana_port }}:3000"
    
    volumes:
      - grafana_data:/var/lib/grafana
      - {{ grafana_data_path }}/provisioning:/etc/grafana/provisioning:ro
      - {{ monitoring_data_volume }}/dashboards:/var/lib/grafana/dashboards:ro
    
    networks:
      monitoring:
        ipv4_address: 172.20.0.20
    
    depends_on:
      - prometheus
    
    labels:
      - "com.monitoring.service=grafana"
      - "com.monitoring.description=Metrics visualization dashboards"
    
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
  
  # =================================================================
  # Alertmanager : Gestion alertes et notifications
  # =================================================================
  alertmanager:
    image: prom/alertmanager:{{ alertmanager_version }}
    container_name: alertmanager
    restart: unless-stopped
    user: "65534:65534"  # nobody:nogroup (sécurité)
    
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--web.external-url=http://{{ monitoring_hostname }}:{{ alertmanager_port }}'
    
    ports:
      - "{{ alertmanager_port }}:9093"
    
    volumes:
      - alertmanager_data:/alertmanager
      - {{ monitoring_data_volume }}/config/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
    
    networks:
      monitoring:
        ipv4_address: 172.20.0.30
    
    labels:
      - "com.monitoring.service=alertmanager"
      - "com.monitoring.description=Alert routing and notifications"
    
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:9093/-/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```


***

### Fichier 15 : `roles/monitoring/templates/alert-rules.yml.j2` (Règles alertes)

**Chemin** : `Ansible/roles/monitoring/templates/alert-rules.yml.j2`
**Rôle** : Règles d'alertes Prometheus
**Versionné** : ✅ Oui

```yaml
# ===================================================================
# Règles d'alertes Prometheus (généré par Ansible)
# Généré le : {{ ansible_date_time.iso8601 }}
# ===================================================================

groups:
  # =================================================================
  # Groupe : Disponibilité infrastructure
  # =================================================================
  - name: infrastructure_availability
    interval: 30s
    rules:
{% for rule in prometheus_alert_rules | selectattr('alert', 'equalto', 'InstanceDown') %}
      - alert: {{ rule.alert }}
        expr: {{ rule.expr }}
        for: {{ rule.for }}
        labels:
{% for key, value in rule.labels.items() %}
          {{ key }}: {{ value }}
{% endfor %}
        annotations:
{% for key, value in rule.annotations.items() %}
          {{ key }}: "{{ value }}"
{% endfor %}
{% endfor %}

  # =================================================================
  # Groupe : Ressources système (CPU, RAM, Disk)
  # =================================================================
  - name: system_resources
    interval: 1m
    rules:
{% for rule in prometheus_alert_rules | rejectattr('alert', 'equalto', 'InstanceDown') | rejectattr('alert', 'equalto', 'DockerServiceDown') %}
      - alert: {{ rule.alert }}
        expr: {{ rule.expr }}
        for: {{ rule.for }}
        labels:
{% for key, value in rule.labels.items() %}
          {{ key }}: {{ value }}
{% endfor %}
        annotations:
{% for key, value in rule.annotations.items() %}
          {{ key }}: "{{ value }}"
{% endfor %}

{% endfor %}

  # =================================================================
  # Groupe : Services applicatifs
  # =================================================================
  - name: application_services
    interval: 1m
    rules:
{% for rule in prometheus_alert_rules | selectattr('alert', 'equalto', 'DockerServiceDown') %}
      - alert: {{ rule.alert }}
        expr: {{ rule.expr }}
        for: {{ rule.for }}
        labels:
{% for key, value in rule.labels.items() %}
          {{ key }}: {{ value }}
{% endfor %}
        annotations:
{% for key, value in rule.annotations.items() %}
          {{ key }}: "{{ value }}"
{% endfor %}
{% endfor %}

  # =================================================================
  # Groupe : Monitoring interne (méta-monitoring)
  # =================================================================
  - name: monitoring_health
    interval: 1m
    rules:
      - alert: PrometheusDown
        expr: up{job="prometheus"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Prometheus is down"
          description: "Prometheus monitoring service is not reachable"
      
      - alert: AlertmanagerDown
        expr: up{job="alertmanager"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Alertmanager is down"
          description: "Alertmanager service is not reachable"
      
      - alert: PrometheusTSDBReloadsFailing
        expr: increase(prometheus_tsdb_reloads_failures_total[1h]) > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Prometheus TSDB reloads failing"
          description: "Prometheus has issues reloading TSDB"
      
      - alert: PrometheusTargetScrapeSlow
        expr: prometheus_target_interval_length_seconds{quantile="0.9"} > 60
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Prometheus scrape duration too high"
          description: "Prometheus is taking more than 60s to scrape targets"
```


***

### Fichier 16 : `roles/monitoring/templates/alertmanager.yml.j2` (Config Alertmanager)

**Chemin** : `Ansible/roles/monitoring/templates/alertmanager.yml.j2`
**Rôle** : Configuration Alertmanager
**Versionné** : ✅ Oui

```yaml
# ===================================================================
# Configuration Alertmanager (généré par Ansible)
# Généré le : {{ ansible_date_time.iso8601 }}
# ===================================================================

global:
  resolve_timeout: {{ alertmanager_resolve_timeout }}
{% if alertmanager_smtp_enabled %}
  
  # Configuration SMTP (notifications email)
  smtp_smarthost: '{{ alertmanager_smtp_host }}'
  smtp_from: '{{ alertmanager_smtp_from }}'
  smtp_auth_username: '{{ alertmanager_smtp_auth_username }}'
  smtp_auth_password: '{{ alertmanager_smtp_auth_password }}'
  smtp_require_tls: {{ alertmanager_smtp_require_tls | lower }}
{% endif %}

# ===================================================================
# Templates notifications
# ===================================================================
templates:
  - '/etc/alertmanager/*.tmpl'

# ===================================================================
# Routing des alertes
# ===================================================================
route:
  receiver: '{{ alertmanager_route.receiver }}'
  group_by: {{ alertmanager_route.group_by | to_json }}
  group_wait: {{ alertmanager_route.group_wait }}
  group_interval: {{ alertmanager_route.group_interval }}
  repeat_interval: {{ alertmanager_route.repeat_interval }}
  
  # Routes spécifiques par sévérité
  routes:
    # Alertes critiques (envoi immédiat)
    - match:
        severity: critical
      receiver: email-admin
      group_wait: 10s
      repeat_interval: 1h
    
    # Alertes warning (groupées)
    - match:
        severity: warning
      receiver: email-admin
      group_wait: 30s
      repeat_interval: 4h
    
    # Webhook Slack (si configuré)
{% if vault_slack_webhook_url is defined and vault_slack_webhook_url != '' %}
    - match_re:
        severity: (critical|warning)
      receiver: webhook-slack
      continue: true  # Envoyer aussi aux autres receivers
{% endif %}

# ===================================================================
# Inhibitions (supprimer alertes redondantes)
# ===================================================================
inhibit_rules:
  # Si instance down, ignorer toutes les autres alertes de cette instance
  - source_match:
      alertname: InstanceDown
    target_match_re:
      alertname: (HighCPU|HighMemory|DiskSpaceLow)
    equal: ['instance']
  
  # Si alerte critique active, ignorer warnings similaires
  - source_match:
      severity: critical
    target_match:
      severity: warning
    equal: ['alertname', 'instance']

# ===================================================================
# Receivers (destinations notifications)
# ===================================================================
receivers:
{% for receiver in alertmanager_receivers %}
  - name: '{{ receiver.name }}'
{% if receiver.email_configs is defined %}
    email_configs:
{% for email in receiver.email_configs %}
      - to: '{{ email.to }}'
        send_resolved: {{ email.send_resolved | default(true) | lower }}
        headers:
          Subject: '[ALERT] {{ '{{' }} .GroupLabels.alertname {{ '}}' }} - {{ '{{' }} .GroupLabels.instance {{ '}}' }}'
        html: |
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              body { font-family: Arial, sans-serif; }
              .critical { color: #d9534f; font-weight: bold; }
              .warning { color: #f0ad4e; font-weight: bold; }
              .info { color: #5bc0de; }
              .resolved { color: #5cb85c; }
            </style>
          </head>
          <body>
            <h2 class="{{ '{{' }} .Status {{ '}}' }}">
              {{ '{{' }} if eq .Status "firing" {{ '}}' }}🔥 Alerte Active{{ '{{' }} else {{ '}}' }}✅ Alerte Résolue{{ '{{' }} end {{ '}}' }}
            </h2>
            <p><strong>Nombre d'alertes:</strong> {{ '{{' }} .Alerts | len {{ '}}' }}</p>
            {{ '{{' }} range .Alerts {{ '}}' }}
            <hr>
            <h3 class="{{ '{{' }} .Labels.severity {{ '}}' }}">{{ '{{' }} .Labels.alertname {{ '}}' }}</h3>
            <p><strong>Instance:</strong> {{ '{{' }} .Labels.instance {{ '}}' }}</p>
            <p><strong>Sévérité:</strong> {{ '{{' }} .Labels.severity {{ '}}' }}</p>
            <p><strong>Description:</strong> {{ '{{' }} .Annotations.description {{ '}}' }}</p>
            <p><strong>Début:</strong> {{ '{{' }} .StartsAt.Format "2006-01-02 15:04:05" {{ '}}' }}</p>
            {{ '{{' }} if .EndsAt {{ '}}' }}<p><strong>Fin:</strong> {{ '{{' }} .EndsAt.Format "2006-01-02 15:04:05" {{ '}}' }}</p>{{ '{{' }} end {{ '}}' }}
            {{ '{{' }} end {{ '}}' }}
            <hr>
            <p><small>Envoyé par Alertmanager - {{ monitoring_hostname }}</small></p>
          </body>
          </html>
{% endfor %}
{% endif %}
{% if receiver.webhook_configs is defined %}
    webhook_configs:
{% for webhook in receiver.webhook_configs %}
      - url: '{{ webhook.url }}'
        send_resolved: {{ webhook.send_resolved | default(true) | lower }}
        http_config:
          follow_redirects: true
{% endfor %}
{% endif %}

{% endfor %}
```


***

### Fichier 17 : `roles/monitoring/templates/grafana-datasources.yml.j2` (Datasource Prometheus)

**Chemin** : `Ansible/roles/monitoring/templates/grafana-datasources.yml.j2`
**Rôle** : Configuration datasource Grafana
**Versionné** : ✅ Oui

```yaml
# ===================================================================
# Grafana Datasources Provisioning (généré par Ansible)
# Généré le : {{ ansible_date_time.iso8601 }}
# ===================================================================

apiVersion: 1

# ===================================================================
# Liste des datasources
# ===================================================================
datasources:
{% for datasource in grafana_datasources %}
  - name: {{ datasource.name }}
    type: {{ datasource.type }}
    access: {{ datasource.access }}
    url: {{ datasource.url }}
    isDefault: {{ datasource.is_default | default(false) | lower }}
    editable: {{ datasource.editable | default(false) | lower }}
    version: 1
    
    # Options JSON spécifiques Prometheus
    jsonData:
      timeInterval: "15s"
      queryTimeout: "60s"
      httpMethod: "POST"
      manageAlerts: true
      prometheusType: "Prometheus"
      prometheusVersion: "{{ prometheus_version }}"
      cacheLevel: "High"
      incrementalQuerying: true
      disableRecordingRules: false
    
    # Options sécurité
    secureJsonFields: {}
    
{% endfor %}

# ===================================================================
# Configuration datasource Alertmanager (optionnel)
# ===================================================================
  - name: Alertmanager
    type: alertmanager
    access: proxy
    url: http://alertmanager:{{ alertmanager_port }}
    isDefault: false
    editable: false
    version: 1
    jsonData:
      implementation: prometheus
```


***

### Fichier 18 : `roles/monitoring/templates/grafana-dashboards-provisioning.yml.j2` (Provisioning dashboards)

**Chemin** : `Ansible/roles/monitoring/templates/grafana-dashboards-provisioning.yml.j2`
**Rôle** : Configuration provisioning dashboards Grafana
**Versionné** : ✅ Oui

```yaml
# ===================================================================
# Grafana Dashboards Provisioning (généré par Ansible)
# Généré le : {{ ansible_date_time.iso8601 }}
# ===================================================================

apiVersion: 1

# ===================================================================
# Providers dashboards
# ===================================================================
providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
      foldersFromFilesStructure: false
```


***

### Fichier 19 : `roles/monitoring/handlers/main.yml` (Handlers)

**Chemin** : `Ansible/roles/monitoring/handlers/main.yml`
**Rôle** : Handlers restart services
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Handlers : Restart services monitoring
# ===================================================================

- name: Restart monitoring stack
  community.docker.docker_compose:
    project_src: "{{ monitoring_data_volume }}"
    state: present
    restarted: true
  listen: "Restart monitoring stack"

- name: Reload Prometheus
  ansible.builtin.uri:
    url: "http://{{ monitoring_hostname }}:{{ prometheus_port }}/-/reload"
    method: POST
    status_code: 200
  listen: "Reload Prometheus"
  failed_when: false

- name: Reload Alertmanager
  ansible.builtin.uri:
    url: "http://{{ monitoring_hostname }}:{{ alertmanager_port }}/-/reload"
    method: POST
    status_code: 200
  listen: "Reload Alertmanager"
  failed_when: false
```


***

### Fichier 20 : `roles/node_exporter/defaults/main.yml` (Variables Node Exporter)

**Chemin** : `Ansible/roles/node_exporter/defaults/main.yml`
**Rôle** : Variables par défaut Node Exporter
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Variables par défaut rôle node_exporter
# ===================================================================

node_exporter_version: "1.7.0"
node_exporter_port: 9100

node_exporter_download_url: "https://github.com/prometheus/node_exporter/releases/download/v{{ node_exporter_version }}/node_exporter-{{ node_exporter_version }}.linux-amd64.tar.gz"

node_exporter_install_dir: "/opt/node_exporter"
node_exporter_binary_path: "/usr/local/bin/node_exporter"

node_exporter_user: "node_exporter"
node_exporter_group: "node_exporter"

# Collectors activés (tous par défaut)
node_exporter_enabled_collectors:
  - cpu
  - meminfo
  - diskstats
  - filesystem
  - netdev
  - loadavg
  - time
  - systemd
  - hwmon
  - netstat

# Firewall (autoriser uniquement depuis monitoring-stack)
node_exporter_firewall_allow_from: "172.16.100.40"
```


***

### Fichier 21 : `roles/node_exporter/tasks/main.yml` (Installation Node Exporter)

**Chemin** : `Ansible/roles/node_exporter/tasks/main.yml`
**Rôle** : Installation Node Exporter (idempotent)
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Rôle node_exporter : Installation Node Exporter (idempotent)
# ===================================================================

- name: Créer utilisateur système node_exporter
  ansible.builtin.user:
    name: "{{ node_exporter_user }}"
    system: true
    shell: /usr/sbin/nologin
    home: "{{ node_exporter_install_dir }}"
    create_home: false
  tags: ['node_exporter', 'user']

- name: Créer groupe node_exporter
  ansible.builtin.group:
    name: "{{ node_exporter_group }}"
    system: true
  tags: ['node_exporter', 'user']

- name: Vérifier si Node Exporter déjà installé
  ansible.builtin.stat:
    path: "{{ node_exporter_binary_path }}"
  register: node_exporter_binary
  tags: ['node_exporter', 'install']

- name: Récupérer version installée
  ansible.builtin.command:
    cmd: "{{ node_exporter_binary_path }} --version"
  register: installed_version
  changed_when: false
  failed_when: false
  when: node_exporter_binary.stat.exists
  tags: ['node_exporter', 'install']

- name: Télécharger Node Exporter (si absent ou version différente)
  ansible.builtin.get_url:
    url: "{{ node_exporter_download_url }}"
    dest: "/tmp/node_exporter.tar.gz"
    mode: '0644'
  when: >
    not node_exporter_binary.stat.exists or
    node_exporter_version not in installed_version.stdout
  tags: ['node_exporter', 'install']

- name: Créer répertoire installation temporaire
  ansible.builtin.file:
    path: /tmp/node_exporter_extract
    state: directory
    mode: '0755'
  when: >
    not node_exporter_binary.stat.exists or
    node_exporter_version not in installed_version.stdout
  tags: ['node_exporter', 'install']

- name: Extraire archive Node Exporter
  ansible.builtin.unarchive:
    src: /tmp/node_exporter.tar.gz
    dest: /tmp/node_exporter_extract
    remote_src: true
    extra_opts: ['--strip-components=1']
  when: >
    not node_exporter_binary.stat.exists or
    node_exporter_version not in installed_version.stdout
  tags: ['node_exporter', 'install']

- name: Copier binaire Node Exporter
  ansible.builtin.copy:
    src: /tmp/node_exporter_extract/node_exporter
    dest: "{{ node_exporter_binary_path }}"
    owner: root
    group: root
    mode: '0755'
    remote_src: true
  when: >
    not node_exporter_binary.stat.exists or
    node_exporter_version not in installed_version.stdout
  notify: Restart node_exporter
  tags: ['node_exporter', 'install']

- name: Nettoyer fichiers temporaires
  ansible.builtin.file:
    path: "{{ item }}"
    state: absent
  loop:
    - /tmp/node_exporter.tar.gz
    - /tmp/node_exporter_extract
  when: >
    not node_exporter_binary.stat.exists or
    node_exporter_version not in installed_version.stdout
  tags: ['node_exporter', 'install']

- name: Générer service systemd Node Exporter
  ansible.builtin.template:
    src: node_exporter.service.j2
    dest: /etc/systemd/system/node_exporter.service
    owner: root
    group: root
    mode: '0644'
  notify: 
    - Reload systemd
    - Restart node_exporter
  tags: ['node_exporter', 'systemd']

- name: Activer et démarrer service Node Exporter (idempotent)
  ansible.builtin.systemd:
    name: node_exporter
    state: started
    enabled: true
    daemon_reload: true
  tags: ['node_exporter', 'systemd']

- name: Configurer firewall UFW (autoriser depuis monitoring-stack uniquement)
  community.general.ufw:
    rule: allow
    from_ip: "{{ node_exporter_firewall_allow_from }}"
    to_port: "{{ node_exporter_port }}"
    proto: tcp
    comment: "Node Exporter metrics (Prometheus)"
  when: firewall_enabled | default(true)
  tags: ['node_exporter', 'firewall']

- name: Attendre démarrage Node Exporter
  ansible.builtin.wait_for:
    port: "{{ node_exporter_port }}"
    state: started
    delay: 2
    timeout: 30
  tags: ['node_exporter', 'validation']

- name: Test endpoint metrics Node Exporter
  ansible.builtin.uri:
    url: "http://localhost:{{ node_exporter_port }}/metrics"
    method: GET
    status_code: 200
    return_content: true
  register: node_exporter_metrics
  failed_when: "'node_cpu_seconds_total' not in node_exporter_metrics.content"
  tags: ['node_exporter', 'validation']

- name: Afficher résultat installation Node Exporter
  ansible.builtin.debug:
    msg:
      - "=========================================="
      - "✓ Node Exporter installé avec succès"
      - "=========================================="
      - "Version:     {{ node_exporter_version }}"
      - "Port:        {{ node_exporter_port }}"
      - "Endpoint:    http://{{ ansible_host }}:{{ node_exporter_port }}/metrics"
      - "Métriques:   {{ node_exporter_metrics.content.split('\n') | select('match', '^node_') | list | length }} disponibles"
      - "=========================================="
  tags: ['node_exporter', 'validation']
```


***

### Fichier 22 : `roles/node_exporter/templates/node_exporter.service.j2` (Service systemd)

**Chemin** : `Ansible/roles/node_exporter/templates/node_exporter.service.j2`
**Rôle** : Service systemd Node Exporter
**Versionné** : ✅ Oui

```ini
# ===================================================================
# Service systemd : Node Exporter
# Généré par Ansible le : {{ ansible_date_time.iso8601 }}
# ===================================================================

[Unit]
Description=Prometheus Node Exporter
Documentation=https://github.com/prometheus/node_exporter
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User={{ node_exporter_user }}
Group={{ node_exporter_group }}

# Commande de démarrage
ExecStart={{ node_exporter_binary_path }} \
{% for collector in node_exporter_enabled_collectors %}
  --collector.{{ collector }} \
{% endfor %}
  --web.listen-address=:{{ node_exporter_port }} \
  --web.telemetry-path=/metrics \
  --log.level=info

# Redémarrage automatique
Restart=on-failure
RestartSec=5s

# Limites ressources
LimitNOFILE=65536
MemoryLimit=128M

# Sécurité (hardening systemd)
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadOnlyPaths=/
ReadWritePaths=/proc /sys

# Logs
StandardOutput=journal
StandardError=journal
SyslogIdentifier=node_exporter

[Install]
WantedBy=multi-user.target
```


***

### Fichier 23 : `roles/node_exporter/handlers/main.yml` (Handlers Node Exporter)

**Chemin** : `Ansible/roles/node_exporter/handlers/main.yml`
**Rôle** : Handlers Node Exporter
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Handlers : Node Exporter
# ===================================================================

- name: Reload systemd
  ansible.builtin.systemd:
    daemon_reload: true
  listen: "Reload systemd"

- name: Restart node_exporter
  ansible.builtin.systemd:
    name: node_exporter
    state: restarted
  listen: "Restart node_exporter"
```


***

### Fichier 24 : `playbooks/monitoring.yml` (Playbook principal)

**Chemin** : `Ansible/playbooks/monitoring.yml`
**Rôle** : Playbook déploiement complet
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Playbook : Déploiement Stack Monitoring Complète
# ===================================================================

# =================================================================
# Play 1 : Déploiement stack monitoring (Prometheus + Grafana)
# =================================================================
- name: Déploiement Stack Monitoring sur monitoring-stack
  hosts: monitoring_hosts
  become: true
  gather_facts: true
  
  vars_files:
    - ../group_vars/monitoring_hosts.yml
    - ../group_vars/secrets/monitoring.vault
  
  pre_tasks:
    - name: Afficher informations déploiement
      ansible.builtin.debug:
        msg:
          - "=========================================="
          - "Déploiement Stack Monitoring"
          - "=========================================="
          - "Host:        {{ inventory_hostname }}"
          - "IP:          {{ ansible_host }}"
          - "Prometheus:  {{ prometheus_version }}"
          - "Grafana:     {{ grafana_version }}"
          - "Alertmanager: {{ alertmanager_version }}"
          - "=========================================="
      tags: ['always']
  
  roles:
    - role: common
      tags: ['common', 'prerequisites']
    
    - role: monitoring
      tags: ['monitoring', 'stack']
  
  post_tasks:
    - name: Afficher URLs accès services
      ansible.builtin.debug:
        msg:
          - ""
          - "=========================================="
          - "✓ Stack Monitoring déployée"
          - "=========================================="
          - "Prometheus:    http://{{ monitoring_hostname }}:{{ prometheus_port }}"
          - "Grafana:       http://grafana.{{ monitoring_domain }}:{{ grafana_port }}"
          - "                 Username: {{ grafana_admin_user }}"
          - "                 Password: (Ansible Vault)"
          - "Alertmanager:  http://{{ monitoring_hostname }}:{{ alertmanager_port }}"
          - "=========================================="
      tags: ['always']

# =================================================================
# Play 2 : Installation Node Exporter sur TOUTES les VMs
# =================================================================
- name: Installation Node Exporter sur toutes les VMs
  hosts: all
  become: true
  gather_facts: true
  
  vars_files:
    - ../group_vars/monitoring_hosts.yml
  
  pre_tasks:
    - name: Afficher hosts cibles Node Exporter
      ansible.builtin.debug:
        msg: "Installation Node Exporter sur {{ inventory_hostname }} ({{ ansible_host }})"
      tags: ['always']
  
  roles:
    - role: node_exporter
      tags: ['node_exporter']
  
  post_tasks:
    - name: Récapitulatif Node Exporter
      ansible.builtin.debug:
        msg:
          - "✓ Node Exporter installé sur {{ inventory_hostname }}"
          - "  Endpoint: http://{{ ansible_host }}:{{ node_exporter_port }}/metrics"
      tags: ['always']

# =================================================================
# Play 3 : Validation finale (depuis localhost)
# =================================================================
- name: Validation déploiement complet
  hosts: localhost
  connection: local
  gather_facts: false
  
  vars:
    monitoring_host: "{{ hostvars[groups['monitoring_hosts'][0]].ansible_host }}"
    all_hosts: "{{ groups['all'] }}"
  
  tasks:
    - name: Test résolution DNS monitoring
      ansible.builtin.command:
        cmd: "dig +short monitoring.lab.local @172.16.100.254"
      register: dns_test
      changed_when: false
      failed_when: monitoring_host not in dns_test.stdout
      tags: ['validation', 'dns']
    
    - name: Test Prometheus targets
      ansible.builtin.uri:
        url: "http://{{ monitoring_host }}:9090/api/v1/targets"
        method: GET
        return_content: true
      register: targets_check
      tags: ['validation', 'prometheus']
    
    - name: Compter targets UP
      ansible.builtin.set_fact:
        targets_up: "{{ targets_check.json.data.activeTargets | selectattr('health', 'equalto', 'up') | list | length }}"
        targets_total: "{{ targets_check.json.data.activeTargets | length }}"
      tags: ['validation', 'prometheus']
    
    - name: Afficher résultat final
      ansible.builtin.debug:
        msg:
          - ""
          - "=========================================="
          - "✓✓✓ DÉPLOIEMENT RÉUSSI ✓✓✓"
          - "=========================================="
          - "DNS:              OK ({{ dns_test.stdout }})"
          - "Prometheus:       UP"
          - "Grafana:          UP"
          - "Alertmanager:     UP"
          - "Node Exporters:   {{ targets_up }}/{{ targets_total }} UP"
          - ""
          - "Prochaines étapes :"
          - "  1. Accéder Grafana : http://grafana.lab.local:3000"
          - "  2. Vérifier dashboards importés"
          - "  3. Configurer alertes email/Slack"
          - "  4. Ajouter règles alertes personnalisées"
          - "=========================================="
      tags: ['validation']
```


***

### Fichier 25 : `docs/monitoring-stack.md` (Documentation complète)

**Chemin** : `docs/monitoring-stack.md`
**Rôle** : Documentation utilisateur
**Versionné** : ✅ Oui

```markdown
# Documentation Stack Monitoring

## Vue d'ensemble

Stack monitoring centralisée basée sur **Prometheus + Grafana + Alertmanager** déployée sur une VM unique `monitoring-stack`.

---

## Architecture

```

monitoring-stack (172.16.100.40)
├── Prometheus:9090    → Collecte métriques (scraping)
├── Grafana:3000       → Visualisation dashboards
└── Alertmanager:9093  → Notifications alertes

Toutes VMs → Node Exporter:9100 → Métriques système

```

---

## Accès Services

| Service | URL | Authentification |
|---------|-----|------------------|
| **Prometheus** | http://monitoring.lab.local:9090 | Aucune |
| **Grafana** | http://grafana.lab.local:3000 | admin / (Vault) |
| **Alertmanager** | http://monitoring.lab.local:9093 | Aucune |

---

## Dashboards Grafana Disponibles

### 1. Node Exporter Full (ID 1860)
**Métriques** : CPU, RAM, Disk, Network, Load  
**Usage** : Vue d'ensemble santé VMs  
**URL** : Grafana → Dashboards → Node Exporter Full

### 2. Docker Containers (ID 193)
**Métriques** : Containers Docker (CPU, RAM, réseau)  
**Usage** : Monitoring services Docker (Harbor, GitLab)  
**URL** : Grafana → Dashboards → Docker Containers

### 3. Prometheus Stats (ID 3662)
**Métriques** : Prometheus interne (scrape duration, TSDB)  
**Usage** : Monitoring du monitoring (méta)  
**URL** : Grafana → Dashboards → Prometheus Stats

---

## Métriques Collectées

### Node Exporter (toutes VMs)
- `node_cpu_seconds_total` : Utilisation CPU
- `node_memory_MemAvailable_bytes` : RAM disponible
- `node_filesystem_avail_bytes` : Espace disque
- `node_network_receive_bytes_total` : Trafic réseau RX
- `node_network_transmit_bytes_total` : Trafic réseau TX
- `node_load1`, `node_load5`, `node_load15` : Load average

### Docker (Harbor, GitLab)
- `engine_daemon_container_states_containers` : État containers
- `container_cpu_usage_seconds_total` : CPU containers
- `container_memory_usage_bytes` : RAM containers

---

## Alertes Configurées

### Critiques (notification immédiate)

#### InstanceDown
**Condition** : `up == 0` pendant 2 minutes  
**Action** : Email + Slack (si configuré)  
**Description** : VM inaccessible (Node Exporter down)

#### PrometheusDown
**Condition** : Prometheus injoignable pendant 2 minutes  
**Action** : Email critique  
**Description** : Perte du monitoring central

### Warnings (notification groupée)

#### HighCPU
**Condition** : CPU >80% pendant 5 minutes  
**Action** : Email groupé (4h repeat)  
**Description** : Utilisation CPU anormalement haute

#### HighMemory
**Condition** : RAM disponible <10% pendant 5 minutes  
**Action** : Email groupé  
**Description** : Risque OOM (Out Of Memory)

#### DiskSpaceLow
**Condition** : Espace disque <10% pendant 5 minutes  
**Action** : Email groupé  
**Description** : Risque saturation disque

---

## Commandes Maintenance

### Vérifier état stack
```bash
ssh monitoring-stack
cd /data/monitoring
docker-compose ps
```


### Restart services

```bash
# Restart complet stack
docker-compose restart

# Restart service spécifique
docker-compose restart prometheus
docker-compose restart grafana
```


### Reload configuration Prometheus (sans restart)

```bash
curl -X POST http://monitoring.lab.local:9090/-/reload
```


### Vérifier targets Prometheus

```bash
curl http://monitoring.lab.local:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'
```


### Logs containers

```bash
# Prometheus
docker-compose logs -f prometheus

# Grafana
docker-compose logs -f grafana

# Alertmanager
docker-compose logs -f alertmanager
```


### Backup configuration

```bash
# Backup manuel
tar -czf /backup/monitoring-$(date +%Y%m%d).tar.gz /data/monitoring/config

# Backup automatique (cron quotidien 2h)
# Voir: /etc/cron.d/monitoring-backup
```


---

## Ajout Métriques Personnalisées

### 1. Ajouter job Prometheus

Éditer `/data/monitoring/config/prometheus.yml` :

```yaml
scrape_configs:
  - job_name: 'mon-app'
    static_configs:
      - targets: ['mon-app.lab.local:9090']
```

Reload Prometheus :

```bash
curl -X POST http://monitoring.lab.local:9090/-/reload
```


### 2. Créer dashboard Grafana

1. Accéder Grafana → Dashboards → New Dashboard
2. Add Visualization
3. Query : `rate(mon_app_requests_total[5m])`
4. Save Dashboard

---

## Ajout Règle Alerte Personnalisée

Éditer `/data/monitoring/config/alert-rules.yml` :

```yaml
groups:
  - name: custom_alerts
    rules:
      - alert: MonAppDown
        expr: up{job="mon-app"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Mon App est down"
          description: "Mon App ne répond plus depuis 2 minutes"
```

Reload Prometheus :

```bash
curl -X POST http://monitoring.lab.local:9090/-/reload
```


---

## Configuration Notifications Slack

### 1. Créer Webhook Slack

1. Accéder https://api.slack.com/apps
2. Create New App → Incoming Webhooks
3. Copier Webhook URL

### 2. Configurer Alertmanager

Éditer `group_vars/secrets/monitoring.vault` :

```yaml
vault_slack_webhook_url: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

Rejouer Ansible :

```bash
ansible-playbook playbooks/monitoring.yml --tags alertmanager --ask-vault-pass
```


---

## Troubleshooting

### Prometheus ne scrape pas les targets

**Symptôme** : Targets en état "DOWN" dans Prometheus
**Cause** : Firewall bloque port 9100
**Solution** :

```bash
# Sur chaque VM
sudo ufw allow from 172.16.100.40 to any port 9100
sudo systemctl status node_exporter
```


### Grafana dashboards vides

**Symptôme** : Dashboards affichent "No Data"
**Cause** : Datasource Prometheus mal configuré
**Solution** :

```bash
# Vérifier datasource
curl -u admin:password http://grafana.lab.local:3000/api/datasources

# Reconfigurer si nécessaire
ansible-playbook playbooks/monitoring.yml --tags grafana --ask-vault-pass
```


### Alertes email non reçues

**Symptôme** : Alertes actives mais pas d'email
**Cause** : Configuration SMTP incorrecte
**Solution** :

```bash
# Vérifier config Alertmanager
docker exec alertmanager amtool config show

# Tester email manuellement
curl -XPOST http://monitoring.lab.local:9093/api/v1/alerts -d '[{"labels":{"alertname":"test"}}]'
```


### Prometheus TSDB corruption

**Symptôme** : Erreur "corrupted chunk" dans logs
**Cause** : Arrêt brutal VM ou disque plein
**Solution** :

```bash
# Arrêter Prometheus
docker-compose stop prometheus

# Nettoyer TSDB
docker run --rm -v /data/monitoring/prometheus:/prometheus prom/prometheus:v2.48.0 \
  promtool tsdb clean -r /prometheus

# Redémarrer
docker-compose start prometheus
```


---

## Métriques Importantes à Surveiller

### Infra générale

- Load average (`node_load1`) : <nombre de CPU
- RAM disponible (`node_memory_MemAvailable_bytes`) : >10%
- Disk usage (`node_filesystem_avail_bytes`) : >10%


### Monitoring interne

- Prometheus scrape duration (`prometheus_target_interval_length_seconds`) : <60s
- Prometheus TSDB size (`prometheus_tsdb_storage_blocks_bytes`) : <80% disque


### Applications

- Harbor registry : `registry_http_requests_total`
- GitLab CI jobs : `gitlab_runner_jobs`

---

## Sécurité

### Authentification Grafana

- Authentification admin obligatoire
- Pas de signup public (`allow_sign_up: false`)
- Pas d'accès anonyme


### Firewall

- Prometheus:9090 → Ouvert (lecture seule)
- Grafana:3000 → Ouvert (auth requise)
- Alertmanager:9093 → Ouvert (lecture seule)
- Node Exporter:9100 → Fermé (sauf depuis monitoring-stack)


### Secrets

- Passwords Grafana → Ansible Vault
- SMTP passwords → Ansible Vault
- Webhook URLs → Ansible Vault

---

## Upgrade Versions

### Prometheus

```bash
# Modifier group_vars/monitoring_hosts.yml
prometheus_version: "v2.49.0"

# Rejouer Ansible
ansible-playbook playbooks/monitoring.yml --tags prometheus --ask-vault-pass
```


### Grafana

```bash
# Modifier group_vars/monitoring_hosts.yml
grafana_version: "10.3.0"

# Rejouer Ansible (attention : backup avant)
ansible-playbook playbooks/monitoring.yml --tags grafana --ask-vault-pass
```


---

## Références

- **Prometheus** : https://prometheus.io/docs/prometheus/latest/
- **Grafana** : https://grafana.com/docs/grafana/latest/
- **Alertmanager** : https://prometheus.io/docs/alerting/latest/alertmanager/
- **Node Exporter** : https://github.com/prometheus/node_exporter
- **PromQL** : https://prometheus.io/docs/prometheus/latest/querying/basics/

```

***

## 🎯 Récapitulatif Final

Vous avez maintenant **TOUS les fichiers code complet** pour déployer la stack monitoring :

### ✅ Fichiers livrés (25 fichiers)

1. ✅ `terraform.tfvars` (ajout VM)
2. ✅ `group_vars/monitoring_hosts.yml` (SSOT config)
3. ✅ `secrets/monitoring.vault` (passwords)
4. ✅ `group_vars/dns_hosts.yml` (DNS)
5. ✅ `roles/monitoring/defaults/main.yml`
6. ✅ `roles/monitoring/tasks/main.yml`
7. ✅ `roles/monitoring/tasks/prerequisites.yml`
8. ✅ `roles/monitoring/tasks/prometheus.yml`
9. ✅ `roles/monitoring/tasks/grafana.yml`
10. ✅ `roles/monitoring/tasks/alertmanager.yml`
11. ✅ `roles/monitoring/tasks/deploy.yml`
12. ✅ `roles/monitoring/tasks/validation.yml`
13. ✅ `roles/monitoring/templates/docker-compose.yml.j2`
14. ✅ `roles/monitoring/templates/prometheus.yml.j2`
15. ✅ `roles/monitoring/templates/alert-rules.yml.j2`
16. ✅ `roles/monitoring/templates/alertmanager.yml.j2`
17. ✅ `roles/monitoring/templates/grafana-datasources.yml.j2`
18. ✅ `roles/monitoring/templates/grafana-dashboards-provisioning.yml.j2`
19. ✅ `roles/monitoring/handlers/main.yml`
20. ✅ `roles/node_exporter/defaults/main.yml`
21. ✅ `roles/node_exporter/tasks/main.yml`
22. ✅ `roles/node_exporter/templates/node_exporter.service.j2`
23. ✅ `roles/node_exporter/handlers/main.yml`
24. ✅ `playbooks/monitoring.yml`
25. ✅ `docs/monitoring-stack.md`

### 🚀 Commandes déploiement

```bash
# 1. Créer VM
terraform apply -target=proxmox_virtual_environment_vm.vm[\"monitoring-stack\"]
sleep 60

# 2. Déployer stack
cd Ansible/
ansible-playbook playbooks/monitoring.yml --ask-vault-pass

# 3. Valider
curl http://monitoring.lab.local:9090/targets
curl http://grafana.lab.local:3000/api/health
```

**Tout est prêt pour déployer !** 🎉

