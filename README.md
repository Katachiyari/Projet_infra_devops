# 🚀 Projet DevSecOps Lab – Plateforme Automatisée & Sécurisée

![status](https://img.shields.io/badge/status-en%20cours-brightgreen)
![stack](https://img.shields.io/badge/stack-DevSecOps-blueviolet)
![infra](https://img.shields.io/badge/infra-Proxmox%209.1.1-orange)
![automation](https://img.shields.io/badge/automation-100%25%20IaC-success)
![security](https://img.shields.io/badge/security-Shift--Left%20Trivy%20UFW-critical)
![ssot](https://img.shields.io/badge/SSOT-Single%20Source%20of%20Truth-informational)

> Plateforme DevSecOps automatisée : HTTP backend, HTTPS frontend, PKI locale, sécurité by design, tout est piloté par le code.

---

## 🧩 Stack technique & principes clés

- **Proxmox 9.1.1** : Hyperviseur de virtualisation, snapshots, gestion VM cloud-init
- **Terraform** : Provisionnement VMs, réseau, SSH (IaC, SSOT)
- **cloud-init** : Bootstrap OS (durcissement, user ansible, sudoers, qemu-guest-agent)
- **Ansible** : Déploiement idempotent (PKI, DNS, reverse-proxy, Harbor, Portainer, monitoring…)
- **Docker/Compose** : Exécution des services applicatifs
- **Trivy** : Scan vulnérabilités (fail si CRITICAL/HIGH, shift-left security)
- **UFW** : Firewall restrictif sur chaque VM, accès minimal
- **Bind9** : DNS interne, zones dynamiques, SSOT des noms
- **PKI locale** : CA root, wildcard *.lab.local, trust distribué
- **Logs & observabilité** : Nginx JSON, Prometheus, Grafana, Alertmanager

**Philosophie** :
- 100% Infrastructure as Code (IaC)
- Single Source of Truth (SSOT) pour chaque donnée critique (clé SSH, IP, DNS, certs)
- Sécurité by design (TLS, UFW, Trivy, permissions, CI/CD ready)
- Documentation et validation automatisées

---

## 🏗️ Architecture réseau & flux (SSOT)

```
Internet/Client
   │  HTTPS (TLS 1.2/1.3)
   ▼
┌──────────────────────────────┐
│ Nginx Reverse Proxy          │ 172.16.100.253
│ - TLS *.lab.local            │
│ - Headers sécurité, logs     │
│ - Redirection HTTP→HTTPS     │
└──────────────────────────────┘
   │  HTTP interne (backend)
   ▼
┌────────────────────────────────────────────────────────────┐
│ Harbor  | 172.16.100.50:80                                 │
│ Portainer | 172.16.100.50:9000                             │
│ Monitoring | 172.16.100.60:9090/3000/9093                  │
│ (GitLab, Taiga, EdgeDoc à venir)                           │
└────────────────────────────────────────────────────────────┘
```

- **DNS Bind9** : lab.local → reverse-proxy (entrée unique, zones dynamiques)
- **PKI locale** : CA root + wildcard *.lab.local (10 ans, stockage /opt/ca, trust distribué)
- **Sécurité** : UFW restrictif, Trivy, headers, rate-limiting, logs JSON, monitoring Prometheus

---

## ✅ Missions réalisées (détail)

### 0️⃣ PKI CA locale
- Rôle : `Ansible/roles/pki_ca/`
- Génération CA root (4096b, 10 ans), wildcard *.lab.local (825j), stockage sécurisé
- Distribution CA sur toutes VMs (`/usr/local/share/ca-certificates/`)
- Certificats serveurs pour Nginx, validés par la CA
- Scripts de renouvellement, tests automatisés (Ansible)

### 1️⃣ Nginx reverse-proxy (172.16.100.253)
- Rôle : `Ansible/roles/nginx_reverse_proxy/`
- Nginx Docker (`nginx:1.25-alpine`), TLS termination, redirection HTTP→HTTPS
- Upstreams HTTP vers Harbor, Portainer, (GitLab, Taiga, EdgeDoc à venir)
- Headers sécurité (HSTS, X-Frame-Options, X-Content-Type-Options, X-XSS-Protection, Referrer-Policy)
- Rate-limiting, logs JSON, monitoring Prometheus, health endpoint

### 2️⃣ Harbor + Portainer (172.16.100.50)
- Rôles : `Ansible/roles/harbor/`, `Ansible/roles/portainer/`
- Harbor (registre images, HTTP interne, external_url HTTPS)
- Portainer CE (UI Docker, HTTP interne)
- UFW : ports 80/9000 accessibles **uniquement** depuis le reverse-proxy
- Trivy intégré (scan images, fail si vulnérabilités critiques)

### 3️⃣ Monitoring (172.16.100.60)
- Rôle : `Ansible/roles/monitoring/`
- Prometheus, Grafana, Alertmanager (Docker Compose)
- Node Exporter sur chaque VM (systemd)
- Dashboards, alertes, health-checks

---

## 🔁 Flux end-to-end (HTTP backend / HTTPS frontend)

Exemple : `https://harbor.lab.local/` → Harbor.

1. **DNS Bind9** : `harbor.lab.local` → `172.16.100.253` (reverse-proxy)
2. **TLS** : Nginx présente le wildcard `*.lab.local` (CA locale)
3. **Proxy** : Nginx → HTTP → `172.16.100.50:80` (Harbor)
4. **Sécurité** : headers, logs, monitoring

Même logique pour Portainer, GitLab, Taiga, EdgeDoc…

👉 Voir [Docs/stackGlobal/SSOT-DevSecOps-stack.md](Docs/stackGlobal/SSOT-DevSecOps-stack.md) pour tous les flux, troubleshooting, et validation.

---

## 🌐 URLs principales (stack déjà livrée)

> ⚠️ Importe la CA root dans ton navigateur pour éviter les alertes TLS.

- 🔐 [https://harbor.lab.local/](https://harbor.lab.local/)
- 🧭 [https://portainer.lab.local/](https://portainer.lab.local/)
- 📈 [http://prometheus.lab.local:9090/](http://prometheus.lab.local:9090/)
- 📊 [http://grafana.lab.local:3000/](http://grafana.lab.local:3000/)
- 🚨 [http://alertmanager.lab.local:9093/](http://alertmanager.lab.local:9093/)

---

## 🚀 Pipeline IaC & bonnes pratiques

### 🔐 Connexion 100% automatisée
- Clé SSH unique (SSOT) injectée via Terraform → cloud-init → Ansible
- Inventaire dynamique généré par Terraform, consommé par Ansible
- Secrets & state jamais versionnés (`.gitignore`)
- Playbooks idempotents, validés, tests intégrés

### 🧾 Démarrage (happy path)
1. Copier `terraform.tfvars.example` → `terraform.tfvars` et adapter
2. `terraform init`
3. `terraform plan -input=false`
4. `terraform apply -input=false`
5. Dans `Ansible/` :
   - `./bootstrap.sh`
   - `./run-ping-test.sh` (ou `--bastion`)
   - Playbooks applicatifs (PKI, reverse-proxy, Harbor/Portainer, monitoring…)

### 🧑‍💻 Structure des rôles Ansible (exemple)
```
roles/<app>/
├── defaults/main.yml
├── tasks/main.yml
├── tasks/prerequisites.yml
├── tasks/install.yml
├── tasks/configure.yml
├── tasks/deploy.yml
├── tasks/security.yml
├── tasks/validation.yml
├── templates/
├── handlers/main.yml
├── meta/main.yml
```

### 🔒 Sécurité DevSecOps (shift-left)
- Trivy scan images Docker (fail si CRITICAL/HIGH)
- UFW restrictif (ports ouverts uniquement au strict nécessaire)
- Permissions fichiers sensibles (0600, root)
- Headers sécurité Nginx
- SAST/Bandit/Semgrep sur scripts

### 📚 Documentation SSOT
- Vue d’ensemble : [Docs/stackGlobal/SSOT-DevSecOps-stack.md](Docs/stackGlobal/SSOT-DevSecOps-stack.md)
- DNS / Bind9 : [Docs/bind9/bind9.md](Docs/bind9/bind9.md)
- Monitoring : [Docs/stackMonitoring/stackMonitoring.md](Docs/stackMonitoring/stackMonitoring.md)
- GitLab (design & contraintes) : [Docs/gitLab/gitLab.md](Docs/gitLab/gitLab.md)

---

## 🔮 Roadmap (prochaines missions)

> Les prochaines étapes sont déjà spécifiées dans [ia.txt](ia.txt). La stack actuelle a été pensée pour les accueillir **sans refonte**.

### 🚧 Mission 3 – GitLab (à venir)
- VM dédiée (GitLab) avec services HTTP :
  - GitLab web : `172.16.100.40:80`
  - Registry : `172.16.100.40:5050`
- Reverse-proxy Nginx en frontal :
  - `https://gitlab.lab.local/` → backend HTTP GitLab
  - `https://registry.gitlab.lab.local/` → backend HTTP registry
- Intégration GitLab Runner, CI/CD, registry Docker

### 🚧 Mission 4 – Taiga + EdgeDoc (à venir)
- VM applicative partagée (ou dédiée selon design final) :
  - Taiga (gestion de projet agile) en HTTP (port 80)
  - EdgeDoc (docs collaboratives) en HTTP (port 8080)
- Exposition via reverse-proxy :
  - `https://taiga.lab.local/`
  - `https://edgedoc.lab.local/`

**Pattern** : Toujours HTTP interne, HTTPS externe, PKI locale, UFW, Trivy, Ansible idempotent

---

## 🤝 Contribution & extension

- Ajouter une app = nouveau rôle Ansible, entrée Nginx, règle UFW, entrée DNS, doc SSOT
- Respecter la logique SSOT, la sécurité, l’automatisation et la traçabilité

---

Ce README est la vitrine et la boussole du projet : tout y est pour comprendre, déployer, valider, et faire évoluer la stack DevSecOps.

---


