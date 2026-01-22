# 📚 Documentation SSOT Complète - Déploiement GitLab CE

## 🎯 Contexte Pédagogique : Pourquoi Cette Approche ?

**Projet DevSecOps** sur infrastructure existante (Proxmox 9.1.1, Terraform+Ansible). GitLab CE (17.7.0) sur VM `git-lab` (172.16.100.40) intègre flux CI/CD → Harbor → K3s.

**Principes SSOT appliqués** :
- **Single Source Of Truth** : Variables centralisées `defaults/main.yml`
- **Idempotence** : Rejouer playbook = aucun changement
- **Automatisation** : Git push → Pipeline → Déploiement
- **Sécurité** : Vault, UFW, TLS PKI interne, images officielles

## 🏗️ Étape 1 : Initialisation Rôle Ansible

**Objectif** : Générer arborescence standard Ansible Galaxy.

**Pourquoi ?** Séparation responsabilités (MVC Ansible) : variables ↔ tasks ↔ templates ↔ handlers.

```bash
cd Ansible/roles
ansible-galaxy role init gitlab
```

**Résultat** :
```
roles/gitlab/
├── defaults/main.yml    # SSOT variables
├── tasks/main.yml       # Orchestration
├── templates/           # Jinja2 dynamique
└── handlers/main.yml    # Side-effects
```

**Pédagogie** : `ansible-galaxy init` = scaffold standard, évite "réinventer la roue".

## ⚙️ Étape 2 : Variables SSOT (Single Source Of Truth)

**Objectif** : Centraliser **TOUTE** configuration modifiable.

**Pourquoi SSOT ?** Changement `gitlab_version` = 1 ligne → tout se propage (templates, tasks).

**`defaults/main.yml` expliqué** :
```yaml
gitlab_version: "17.7.0-ce.0"           # Image Docker officielle
gitlab_external_url: "https://gitlab.lab.local"  # Nginx RP frontend
gitlab_http_port: 80                    # Backend uniquement
harbor_url: "https://harbor.lab.local"  # Intégration CI/CD
vault_gitlab_root_password: "{{ vault }}" # Secrets chiffrés
```

**Priorités Ansible** : `defaults` < `group_vars` < `--extra-vars`.

## 🎨 Étape 3 : Templates Jinja2 Dynamiques

**Objectif** : Générer configs `/srv/gitlab/` depuis variables SSOT.

**Pourquoi templates ?** 1 template = N environnements (dev/staging/prod).

**`docker-compose.yml.j2` décortiqué** :
```yaml
environment:
  GITLAB_OMNIBUS_CONFIG: |
    external_url '{{ gitlab_external_url }}'     # Jinja2 → https://gitlab.lab.local
    nginx['listen_https'] = false                # TLS → Nginx RP (172.16.100.253)
    registry_external_url '{{ gitlab_registry_external_url }}'  # registry.gitlab.lab.local
```

**Flux** : `{{ var }}` → rendu → `/srv/gitlab/docker-compose.yml` → `docker compose up`.

## 🔄 Étape 4 : Tasks Idempotentes (main.yml)

**Objectif** : Orchestration séquentielle **Docker → Config → Deploy → Sécurité → Validation**.

**Pourquoi idempotence ?** `ansible-playbook` 10x = 0 changement après 1re fois.

**Tasks critiques expliquées** :
```yaml
- name: Docker installé ? → package/state=present
- name: /srv/gitlab existe ? → file/state=directory  
- name: docker-compose.yml changé ? → template + notify
- name: GitLab up (200) ? → uri/until + retries:30
```

**Handlers** (bonus) :
```yaml
- name: restart gitlab
  command: docker compose restart gitlab  # Déclenché par notify
```

## 🌐 Étape 5 : Intégrations Infrastructure

| Service | IP | Rôle Ansible | Config |
|---------|----|--------------|--------|
| **Nginx RP** | 172.16.100.253 | `nginx_reverse_proxy` | Backend `gitlab.lab.local → 172.16.100.40:80` |
| **BIND9 DNS** | 172.16.100.254 | `bind9_docker` | `gitlab.lab.local A 172.16.100.253` |
| **Harbor** | 172.16.100.50 | `harbor` | Registry push CI/CD |
| **Prometheus** | 172.16.100.60 | `monitoring` | Scrape metrics port 9090 |

## 🔐 Étape 6 : Sécurisation DevSecOps

```
Secrets → Ansible Vault (secrets/gitlab.yml)
Réseau → UFW : 80/22/5050/9090 + from 172.16.100.253
TLS → PKI interne (pki_ca.yml → gitlab.lab.local.crt)
Images → Officielles gitlab/gitlab-ce (pas DHI dispo)
```

## 🚀 Étape 7 : Playbook Orchestration

**`playbooks/gitlab.yml`** :
```yaml
---
- name: Déployer GitLab CE
  hosts: gitlab_hosts
  roles: [gitlab]

- name: Nginx RP GitLab
  hosts: reverse_proxy_hosts  
  roles: [nginx_reverse_proxy]

- name: DNS gitlab.lab.local
  hosts: bind9_hosts
  roles: [bind9_docker]
```

## 📊 Flux Complet DevOps

```
Dev PC → git push ssh://git@gitlab.lab.local
  ↓ HTTPS gitlab.lab.local (Nginx RP 253)
GitLab (40) → .gitlab-ci.yml → Runner Docker-in-Docker
  ↓ Trivy scan → docker push harbor.lab.local/gitlab-builds/app:1.0
K3s (250) ← Deploy helm/argocd
Prometheus (60) ← Metrics pipeline
Slack/Email ← Notifications
```

## ✅ Checklist Déploiement

```
[x] Étape 1 : ansible-galaxy role init gitlab
[x] Étape 2 : defaults/main.yml SSOT
[x] Étape 3 : templates/docker-compose.yml.j2 + runner.toml.j2
[x] Étape 4 : tasks/main.yml (50 lignes idempotentes)
[ ] Étape 5 : git commit/push → admin1
[ ] Étape 6 : ansible-playbook playbooks/gitlab.yml --ask-vault-pass
[ ] Étape 7 : curl https://gitlab.lab.local → HTTP 200
```

## 🎓 Leçons Pédagogiques

1. **SSOT > Copier/Coller** : 1 variable = N fichiers
2. **Idempotence = Confiance** : Rejouer sans peur
3. **Handlers = Clean** : Restart seulement si changement
4. **Templates Jinja2 = Puissance** : Statique → Dynamique
5. **Vault + UFW = Sécurité** : Shift-left dès IaC

**Temps total** : 15min déploiement, ∞ réutilisation. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_5e74f233-dbdf-418d-afa1-e893b6588eda/ecc3caea-4f39-4230-ad18-cc27f35b9c13/https-github-com-katachiyari-p-bz7svhA9SI2Zm9XDbnnP5Q.md)

**Prochaine** : **"suivant"** pour handlers + playbook final.