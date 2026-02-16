## 📖 Documentation Étape 3 : Templates Jinja2 (SSOT)

**Objectif** : générer une configuration GitLab + Runner cohérente, à partir des variables SSOT, sans duplication des secrets.

**Principe** : les templates `.j2` rendent les fichiers finaux (`docker-compose.yml`, `config.toml`) avec les variables Ansible.

### Fichiers clés

- `Ansible/roles/gitlab/templates/docker-compose.yml.j2`
- `Ansible/roles/gitlab/templates/runner-config.toml.j2`

### Points importants validés

1. **URL runner**
- Le runner contacte GitLab via :
```toml
url = "https://git-lab.lab.local"
```

2. **Token runner (best practice SSOT)**
- Le secret est stocké dans Vault :
```yaml
vault_gitlab_runner_token: "glrt-..."
```
- Le rôle mappe ensuite vers la variable runtime :
```yaml
gitlab_runner_token: "{{ vault_gitlab_runner_token | default('') }}"
```
- Le template écrit le token dans `config.toml` :
```toml
token = "glrt-..."
```

3. **Docker executor**
```toml
executor = "docker"
[runners.docker]
  image = "docker:27-dind"
  privileged = true
  volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]
```

### Vérification rapide

```bash
ssh -i ~/.ssh/id_ed25519_admin1_nopass -o IdentitiesOnly=yes ansible@172.16.100.40 "sudo sed -n '1,140p' /srv/gitlab/runner/config.toml"
```

Attendu : présence de `token = "glrt-..."`.

### Erreurs rencontrées et interprétation

- `jsonschema ... /runners/0/token ... got 0`
- Cause : token absent dans `config.toml`.
- Correctif : mapping Vault -> `gitlab_runner_token` + replay playbook.

### Prochaine étape

Exécuter un pipeline smoke test dans un projet GitLab avec un job taggé `docker`.
