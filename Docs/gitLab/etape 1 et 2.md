## 📖 Documentation Étape 1 : Création Rôle Ansible GitLab

**Objectif** : Générer arborescence standard Ansible pour rôle `gitlab` (idempotent).

**Principe** : `ansible-galaxy role init` crée structure hiérarchique avec séparation des responsabilités (variables, tasks, templates, handlers).

### Exécution Détaillée

1. **Positionnement** :
   ```bash
   cd Ansible/roles
   ```

2. **Génération** :
   ```bash
   ansible-galaxy role init gitlab
   ```

3. **Résultat** : Arborescence complète générée :
   ```
   gitlab/
   ├── defaults/main.yml       # Variables par défaut (SSOT)
   ├── handlers/main.yml       # Actions post-task (restart)
   ├── tasks/main.yml          # Séquence d'exécution
   ├── templates/              # Configs dynamiques Jinja2
   ├── files/                  # Fichiers statiques
   ├── meta/main.yml           # Métadonnées/dépendances
   └── vars/main.yml           # Variables fixes
   ```

**Avantages** : Idempotence native, modularité, réutilisabilité sur multiples environnements.

**Vérification** :
```bash
tree gitlab/
ansible gitlab_hosts -m ping  # Test connectivité VM
```

## 📖 Documentation Étape 2 : Variables SSOT (Single Source Of Truth)

**Objectif** : Centraliser configuration GitLab (versions, réseau, intégrations, secrets) dans `defaults/main.yml`.

**Principe** : Variables par défaut surchargées par `group_vars`, `host_vars` ou `--extra-vars`. Priorité : `defaults` < `vars` < `group_vars`.

### Structure Variables

| Catégorie | Exemples | Rôle |
|-----------|----------|------|
| **Versions** | `gitlab_version: "17.7.0-ce.0"` | Image Docker officielle |
| **Réseau** | `gitlab_external_url: "https://gitlab.lab.local"` | URL publique (Nginx RP) |
| **Ports** | `gitlab_http_port: 80` | Backend HTTP uniquement |
| **Intégrations** | `harbor_url: "https://harbor.lab.local"` | Flux CI/CD vers Harbor/K3s |
| **Secrets** | `{{ vault_gitlab_root_password }}` | Ansible Vault chiffré |
| **Persistance** | `gitlab_data_dir: "/srv/gitlab/data"` | Volumes Docker persistants |

### Contenu Complet `defaults/main.yml`

```yaml
---
# GitLab CE officiel (pas DHI disponible)
gitlab_version: "17.7.0-ce.0"
gitlab_runner_version: "alpine-v17.7.0"  # Officielle Alpine

# Réseau SSOT
gitlab_hostname: "gitlab.lab.local"
gitlab_ip: "172.16.100.40"
gitlab_external_url: "https://{{ gitlab_hostname }}"

# Ports backend (exposition via Nginx RP 253)
gitlab_http_port: 80
gitlab_ssh_port: 22
gitlab_registry_port: 5050

# Infrastructure existante
harbor_url: "https://harbor.lab.local"
prometheus_url: "http://172.16.100.60:9090"

# Secrets Vault
gitlab_root_password: "{{ vault_gitlab_root_password }}"

# Persistance /srv/
gitlab_data_dir: "/srv/gitlab/data"
gitlab_config_dir: "/srv/gitlab/config"

# Tuning interne
gitlab_redis_maxmemory: "256mb"
gitlab_runner_concurrent: 4
```

### Bonnes Pratiques

- **Idempotence** : Tests `changed_when: false` dans tasks.
- **Sécurité** : Secrets Vault, UFW restreint, TLS PKI interne.
- **SSOT** : Une seule source, réutilisable Terraform/Ansible.

**Vérification** :
```bash
ansible-inventory --list gitlab_hosts | jq '.gitlab_hosts[0].gitlab_ip'
# "172.16.100.40"
```

**Prochaine** : Étape 3 Templates (tapez "suivant"). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_5e74f233-dbdf-418d-afa1-e893b6588eda/ecc3caea-4f39-4230-ad18-cc27f35b9c13/https-github-com-katachiyari-p-bz7svhA9SI2Zm9XDbnnP5Q.md)