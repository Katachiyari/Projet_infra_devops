# 🚀 Projet Infra DevSecOps – Proxmox · Terraform · Ansible

![status](https://img.shields.io/badge/status-en%20cours-brightgreen)
![stack](https://img.shields.io/badge/stack-DevSecOps-blueviolet)
![infra](https://img.shields.io/badge/infra-Proxmox%209.1.1-orange)
![automation](https://img.shields.io/badge/automation-100%25%20IaC-success)

> Esprit startup, infra codée, sécurisée et reproductible. Toute la plateforme est pensée **HTTP backend / HTTPS frontend** avec une **PKI locale** et un **reverse-proxy Nginx** comme porte d’entrée unique.

---

## 🧩 Vision globale

Ce dépôt décrit une stack DevSecOps complète sur Proxmox :

- **Terraform** : crée les VMs, configure réseau & SSH (utilisateur `ansible` + clé publique).
- **cloud-init** : bootstrap unique des OS (qemu-guest-agent, durcissement SSH, sudoers).
- **Ansible** : déploie les services applicatifs de façon **idempotente** (DNS, PKI, reverse-proxy, Harbor/Portainer, monitoring, …).
- **Docker / Docker Compose** : exécution des services.
- **Trivy** : scan systématique des images (CRITICAL/HIGH = ❌).

Le tout est structuré autour d’un principe fort : **SSOT (Single Source of Truth)**. Une seule source pour chaque vérité (clé SSH, IPs, DNS, certificats…), tout le reste est dérivé automatiquement.

---

## 🏗️ Architecture actuelle (missions réalisées)

Architecture réseau : `172.16.100.0/24` – domaine : `lab.local`.

### ✅ Mission 0 – PKI CA locale

- Rôle : `Ansible/roles/pki_ca/`.
- Génération de la **Lab Root CA** (`root-ca.crt/key`) et du certificat wildcard `*.lab.local`.
- Installation de la CA dans le trust système des VMs.
- Tous les certificats serveurs (Nginx) sont émis par cette CA.

👉 Détails : PKI et flux TLS documentés dans [Docs/stackGlobal/SSOT-DevSecOps-stack.md](Docs/stackGlobal/SSOT-DevSecOps-stack.md).

### ✅ Mission 1 – Reverse-proxy Nginx (172.16.100.253)

- Rôle : `Ansible/roles/nginx_reverse_proxy/`.
- Nginx en conteneur (`nginx:1.25-alpine`) avec :
	- Terminaison TLS pour `*.lab.local` (certificat wildcard).
	- Redirection **HTTP → HTTPS**.
	- En-têtes de sécurité (HSTS, X-Frame-Options, X-Content-Type-Options, X-XSS-Protection, Referrer-Policy…).
	- Rate-limiting et logs JSON.
- Upstreams HTTP vers les backends : Harbor, Portainer, (futur GitLab, Taiga, EdgeDoc…).

### ✅ Mission 2 – Harbor + Portainer (172.16.100.50)

- Rôles : `Ansible/roles/harbor/` et `Ansible/roles/portainer/`.
- **Harbor** (registre d’images, HTTP interne) :
	- Exposé en HTTP sur `172.16.100.50:80`.
	- `external_url` = `https://harbor.lab.local` (via Nginx).
- **Portainer CE** (UI Docker, HTTP interne) :
	- Exposé en HTTP sur `172.16.100.50:9000`.
- **Sécurité** :
	- UFW sur la VM autorise 80/9000 **uniquement** depuis `172.16.100.253` (reverse-proxy).
	- Trivy intégré dans les rôles pour scanner les images clés.

### ✅ Stack monitoring (172.16.100.60)

- Rôle : `Ansible/roles/monitoring/`.
- VM `monitoring-stack` avec :
	- **Prometheus** : `http://prometheus.lab.local:9090/`.
	- **Grafana** : `http://grafana.lab.local:3000/`.
	- **Alertmanager** : `http://alertmanager.lab.local:9093/`.
- **Node Exporter** déployé sur les VMs pour exposer les métriques système.

---

## 🔁 Flux end-to-end (HTTP backend / HTTPS frontend)

Exemple : `https://harbor.lab.local/` → Harbor.

1. **DNS Bind9** renvoie `harbor.lab.local` → `172.16.100.253` (reverse-proxy).
2. Le navigateur se connecte en **HTTPS** à Nginx qui présente le wildcard `*.lab.local` (signé par la Lab Root CA).
3. Nginx proxifie en **HTTP** vers `172.16.100.50:80` (Harbor backend).
4. La réponse revient chiffrée vers le client.

Même logique pour `https://portainer.lab.local/` → `172.16.100.50:9000`.

👉 La doc détaillée (DNS, flux, troubleshooting) est dans [Docs/stackGlobal/SSOT-DevSecOps-stack.md](Docs/stackGlobal/SSOT-DevSecOps-stack.md).

---

## ⚙️ Pipeline IaC de bout en bout

### 🔐 Connexion 100% automatisée

1. **SSOT clé SSH** : `keys/…ed25519.pub` référencée dans `terraform.tfvars` (`ssh_public_key`).
2. **Terraform** crée les VMs Proxmox et pousse la clé via `initialization.user_account`.
3. **cloud-init** fait le bootstrap (packages, sshd, sudoers) sans recréer l’utilisateur.
4. **Terraform** génère l’inventaire Ansible : `Ansible/inventory/terraform.generated.yml`.

### 🧾 Fichiers sensibles

- Secrets non versionnés : `terraform.tfvars`, autres `*.tfvars`.
- State non versionné : `*.tfstate*` (idéalement backend distant).

### 🚀 Démarrage (happy path)

1. Copier `terraform.tfvars.example` → `terraform.tfvars` et adapter.
2. `terraform init`
3. `terraform plan -input=false`
4. `terraform apply -input=false`
5. Dans `Ansible/` :
	 - `./bootstrap.sh`
	 - `./run-ping-test.sh` (ou `--bastion` selon ton contexte)
	 - Playbooks applicatifs (PKI, reverse-proxy, Harbor/Portainer, monitoring…).

Astuce : `terraform plan -var-file=terraform.tfvars -input=false` pour forcer le var-file.

---

## 📚 Documentation SSOT

- Vue d’ensemble DevSecOps (PKI, Nginx, Harbor/Portainer, monitoring, DNS, flux) :
	- [Docs/stackGlobal/SSOT-DevSecOps-stack.md](Docs/stackGlobal/SSOT-DevSecOps-stack.md)
- DNS / Bind9 :
	- [Docs/bind9/bind9.md](Docs/bind9/bind9.md)
- Monitoring stack :
	- [Docs/stackMonitoring/stackMonitoring.md](Docs/stackMonitoring/stackMonitoring.md)
- GitLab (design & contraintes, en amont de la Mission 3) :
	- [Docs/gitLab/gitLab.md](Docs/gitLab/gitLab.md)

---

## 🌐 URLs principales (stack déjà livrée)

Une fois la stack déployée **et la CA importée dans le navigateur** :

- 🔐 Harbor : `https://harbor.lab.local/`
- 🧭 Portainer : `https://portainer.lab.local/`
- 📈 Prometheus : `http://prometheus.lab.local:9090/`
- 📊 Grafana : `http://grafana.lab.local:3000/`
- 🚨 Alertmanager : `http://alertmanager.lab.local:9093/`

---

## 🔮 Roadmap – Missions à venir (ia.txt)

> Les prochaines étapes sont déjà spécifiées dans [ia.txt](ia.txt). La stack actuelle a été pensée pour les accueillir **sans refonte**.

### 🚧 Mission 3 – GitLab (à venir)

- VM dédiée (GitLab) avec services HTTP :
	- GitLab web : `172.16.100.40:80`.
	- Registry : `172.16.100.40:5050`.
- Reverse-proxy Nginx en frontal :
	- `https://gitlab.lab.local/` → backend HTTP GitLab.
	- `https://registry.gitlab.lab.local/` → backend HTTP registry.
- Intégration GitLab Runner, CI/CD, registry Docker.

### 🚧 Mission 4 – Taiga + EdgeDoc (à venir)

- VM applicative partagée (ou dédiée selon design final) :
	- Taiga (gestion de projet agile) en HTTP (port 80).
	- EdgeDoc (docs collaboratives) en HTTP (port 8080).
- Exposition via reverse-proxy :
	- `https://taiga.lab.local/`.
	- `https://edgedoc.lab.local/`.

Les mêmes patterns s’appliquent : **HTTP interne, HTTPS externe, PKI locale, Trivy, UFW restrictif, Ansible idempotent**.

---

## 🤝 Contribuer / Faire évoluer la stack

- Ajouter une nouvelle appli = ajouter **une mission** :
	- Rôle Ansible dédié (`roles/<app>/`).
	- Backends HTTP sécurisés via UFW.
	- Entrée Nginx dans le reverse-proxy.
	- Entrées DNS Bind9 cohérentes.
- Garder la logique SSOT :
	- Terraform pour l’infra & inventaire.
	- Ansible pour la configuration.
	- Docs sous `Docs/` comme vérité fonctionnelle.

Cette base est prête pour des features plus « startup » : CI/CD GitLab, intégration Harbor, scans Trivy en pipeline, dashboards Grafana pour l’observabilité, etc. Let’s build on top 🚀
