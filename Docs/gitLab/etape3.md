## 📖 Documentation Étape 3 : Templates Jinja2 (SSOT)

**Objectif** : Fournir configurations dynamiques pour stack Docker GitLab+Runner, paramétrées par variables SSOT de l'étape 2.

**Principe** : Templates `.j2` utilisent syntaxe Jinja2 (`{{ var }}`, `| lower`) pour substitution automatique. Idempotents via `notify: restart`.

### Architecture Templates

| Fichier | Rôle | Variables Clés |
|---------|------|----------------|
| `docker-compose.yml.j2` | Stack complète (GitLab Omnibus + Runner) | `gitlab_version`, `external_url`, ports, volumes `/srv/` |
| `runner-config.toml.j2` | Config Runner (executor Docker-in-Docker) | `gitlab_runner_token`, `concurrent=4`, `privileged=true` |

### Points Techniques SSOT

**1. GitLab Omnibus (Tout-en-un)** :
```
- Rails + Gitaly + PostgreSQL + Redis + Sidekiq + Registry + Nginx interne
- `external_url` → Génère URLs automatiques (Webhooks, CI/CD)
- `nginx['listen_https'] = false` → TLS terminaison sur Nginx RP externe
```

**2. Persistance Docker** :
```
volumes:
  - /srv/gitlab/config:/etc/gitlab     # gitlab.rb généré
  - /srv/gitlab/data:/var/opt/gitlab   # Repos Git + PostgreSQL
  - /srv/gitlab-runner:/etc/gitlab-runner  # Tokens runners
```

**3. Runner Docker-in-Docker (DiD)** :
```
executor: "docker", image: "docker:27-dind"
privileged: true, volumes: ["/var/run/docker.sock"]
→ Build/push images vers Harbor (172.16.100.50)
```

### Contenu `docker-compose.yml.j2` (Extrait Critique)

```yaml
environment:
  GITLAB_OMNIBUS_CONFIG: |
    external_url '{{ gitlab_external_url }}'        # https://gitlab.lab.local
    nginx['listen_port'] = {{ gitlab_http_port }}   # 80 (backend)
    gitlab_rails['initial_root_password'] = '{{ gitlab_root_password }}'
    registry_external_url '{{ gitlab_registry_external_url }}'  # registry.gitlab.lab.local
```

### Contenu `runner-config.toml.j2` (Extrait Critique)

```toml
[[runners]]
  url = "{{ gitlab_external_url }}"
  token = "{{ vault_gitlab_runner_token }}"
  executor = "docker"
  image = "{{ gitlab_runner_docker_image }}"  # docker:27-dind
  privileged = true
```

### Bonnes Pratiques DevSecOps

- **Images officielles** : `gitlab/gitlab-ce:17.7.0-ce.0` (priorité espace) [docs.gitlab](https://docs.gitlab.com/runner/install/docker/)
- **Sécurité** : `shm_size: '256m'`, `restart: unless-stopped`, réseau isolé `bridge`
- **Monitoring** : Prometheus export `9090`, `node_exporter` activé
- **Intégrations** : Prêt Harbor push, K3s deploy, metrics Prometheus

### Vérification Syntaxe

```bash
cd Ansible/roles/gitlab
# Test rendu Jinja2
ansible-playbook --syntax-check tasks/main.yml
docker-compose -f /tmp/test.yml config  # Après template
```

**Flux SSOT** : Variables (Étape 2) → Templates (Étape 3) → Fichiers `/srv/gitlab/` → `docker compose up`.

**Prochaine** : Étape 4 Tasks (tapez "suivant"). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_5e74f233-dbdf-418d-afa1-e893b6588eda/ecc3caea-4f39-4230-ad18-cc27f35b9c13/https-github-com-katachiyari-p-bz7svhA9SI2Zm9XDbnnP5Q.md)