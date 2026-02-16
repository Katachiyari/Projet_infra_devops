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

---

## 📖 Mise à jour (2026-02-16) : Runner Docker GitLab validé (mode pas à pas)

**Objectif** : connecter un runner Docker `instance` sur `git-lab.lab.local` avec Vault + Ansible, en suivant une méthode proche des bonnes pratiques officielles GitLab Runner.

### Étapes validées

1. **Créer un Instance Runner dans l'UI GitLab**
   - `Admin Area -> CI/CD -> Runners -> New instance runner`
   - Tags utilisés : `docker,prod-like`
   - Option `Run untagged jobs` : désactivée
   - Récupération du **Runner authentication token** (`glrt-...`)

2. **Stocker le token dans Vault**
   - Fichier : `Ansible/secrets/gitlab.yml`
   - Variable source de vérité :
   ```yaml
   vault_gitlab_runner_token: "glrt-..."
   ```

3. **Mapper automatiquement le token Vault vers la variable runtime**
   - Fichier : `Ansible/roles/gitlab/defaults/main.yml`
   ```yaml
   gitlab_runner_token: "{{ vault_gitlab_runner_token | default('') }}"
   ```
   - But : éviter la duplication manuelle des variables et garder une SSOT claire.

4. **Rejouer le playbook GitLab**
   ```bash
   cd /media/james/DATA2/Projet_infra_devops/Ansible
   ANSIBLE_LOCAL_TEMP=/tmp/.ansible/local \
   ANSIBLE_REMOTE_TMP=/tmp/.ansible/tmp \
   ANSIBLE_FACT_PATH=/tmp/.ansible/facts \
   ansible-playbook -i inventory/hosts.yml playbooks/gitlab.yml \
     --limit gitlab_hosts \
     -u ansible --private-key ~/.ssh/id_ed25519_admin1_nopass \
     --ask-vault-pass
   ```

5. **Contrôler la configuration runner**
   - Fichier cible : `/srv/gitlab/runner/config.toml`
   - Vérifier la présence de :
   ```toml
   token = "glrt-..."
   ```

6. **Vérifier le lien runner <-> GitLab**
   ```bash
   sudo docker exec gitlab-runner gitlab-runner verify
   ```
   - Résultat attendu :
   - `Verifying runner... is valid`
   - UI GitLab : runner en état `Online`.

### Dépannage rencontré (et résolution)

- **Erreur** : `jsonschema ... /runners/0/token ... got 0`
  - Cause : token absent/variable non mappée dans `config.toml`.
  - Correctif : mapping `gitlab_runner_token` depuis `vault_gitlab_runner_token`.

- **Erreur Ansible** : `Failed to create temporary directory`
  - Correctif : utiliser `ANSIBLE_LOCAL_TEMP`, `ANSIBLE_REMOTE_TMP`, `ANSIBLE_FACT_PATH` sous `/tmp`.

---

**Prochaines docs** :
- `Docs/gitLab/etape3.md` : templates GitLab/Runner (SSOT + token Vault).
- `Docs/gitLab/etape4-runner-python-hardened.md` : test end-to-end runner avec image Python hardened.
