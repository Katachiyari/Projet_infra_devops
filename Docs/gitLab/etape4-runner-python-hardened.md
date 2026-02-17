## 📖 Documentation Étape 4 : Test Runner avec image Python Hardened

**Objectif** : valider de bout en bout qu'un runner `docker` exécute un job CI réel.

## 0. Déployer le runner

Avant de tester un pipeline, il faut comprendre où le runner est déclaré dans votre code.

### Les 5 fichiers à lire (ordre recommandé)

1. `Ansible/playbooks/gitlab.yml`
- Lance le rôle `gitlab` sur `gitlab_hosts`.

2. `Ansible/secrets/gitlab.yml` (ou `Ansible/secrets/gitlab.yml.example`)
- Contient le secret `vault_gitlab_runner_token`.

3. `Ansible/roles/gitlab/defaults/main.yml`
- Définit les variables runner (`executor`, image, concurrence, token).

4. `Ansible/roles/gitlab/templates/docker-compose.yml.j2`
- Déclare le service conteneur `gitlab-runner`.

5. `Ansible/roles/gitlab/templates/runner-config.toml.j2`
- Génère le `config.toml` réel avec `[[runners]]`.

### Flux simple (ce qui se passe vraiment)

1. Vous mettez le token dans Vault (`vault_gitlab_runner_token`).
2. Le rôle mappe ce token vers `gitlab_runner_token`.
3. Ansible rend `runner-config.toml.j2` en `config.toml`.
4. Le conteneur `gitlab-runner` démarre avec ce `config.toml`.
5. Le runner apparaît `Online` dans GitLab UI.

### Extraits minimaux à expliquer dans la doc

```yaml
# Ansible/roles/gitlab/defaults/main.yml
gitlab_runner_executor: "docker"
gitlab_runner_docker_image: "docker:27-dind"
gitlab_runner_concurrent: 4
gitlab_runner_token: "{{ vault_gitlab_runner_token | default('') }}"
```

```toml
# Ansible/roles/gitlab/templates/runner-config.toml.j2
[[runners]]
  name = "gitlab-runner"
  url = "{{ gitlab_scheme }}://{{ gitlab_fqdn }}"
  token = "{{ gitlab_runner_token }}"
  executor = "{{ gitlab_runner_executor }}"
  [runners.docker]
    image = "{{ gitlab_runner_docker_image }}"
    privileged = true
    volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]
```

### Déploiement / mise à jour du runner

```bash
cd /media/james/DATA2/Projet_infra_devops/Ansible
ansible-playbook -i inventory/hosts.yml playbooks/gitlab.yml --limit gitlab_hosts -u ansible --private-key ~/.ssh/id_ed25519_admin1_nopass --ask-vault-pass
```

### Vérifications après déploiement

```bash
# config rendue sur la VM GitLab
ssh -i ~/.ssh/id_ed25519_admin1_nopass -o IdentitiesOnly=yes ansible@172.16.100.40 "sudo sed -n '1,140p' /srv/gitlab/runner/config.toml"

# état du runner dans le conteneur
ssh -i ~/.ssh/id_ed25519_admin1_nopass -o IdentitiesOnly=yes ansible@172.16.100.40 "sudo docker exec gitlab-runner gitlab-runner verify"
```

Attendu : `Verifying runner... is valid`.

## 1. Préparer le projet GitLab

Créer un projet vide (ex: `python_hardened`) dans GitLab.

## 2. Vérifier la connectivité avant clone

### HTTPS GitLab (avec CA interne)
```bash
curl --cacert /media/james/DATA2/Projet_infra_devops/root-ca.crt -I --connect-timeout 5 https://git-lab.lab.local/users/sign_in
```
Attendu : HTTP `200` ou `302`.

### SSH GitLab direct (port 2222 sur la VM GitLab)
```bash
nc -vz 172.16.100.40 2222
```
Attendu : `succeeded`.

## 3. Créer une clé SSH dédiée GitLab

```bash
ssh-keygen -t ed25519 -f ~/.ssh/gitlab_lab -C "gitlab_lab" -N ""
cat ~/.ssh/gitlab_lab.pub
```

Ajouter la clé publique dans GitLab :
- `User -> Preferences -> SSH Keys` (ou clé de déploiement projet selon besoin)

## 4. Cloner le repo via SSH

```bash
cd /media/james/DATA2
GIT_SSH_COMMAND='ssh -i ~/.ssh/gitlab_lab -o IdentitiesOnly=yes -p 2222' \
git clone ssh://git@172.16.100.40:2222/root/python_hardened.git
```

Si le dépôt est vide, le message est normal.

## 5. Ajouter le pipeline smoke test

Créer `.gitlab-ci.yml` :

```yaml
stages:
  - test

python_hardened_smoke:
  stage: test
  tags:
    - docker
  image: cgr.dev/chainguard/python:latest-dev
  script:
    - python -V
    - python -c "print('runner + python hardened OK')"
```

## 6. Commit et push

```bash
cd /media/james/DATA2/python_hardened
git add .gitlab-ci.yml
git commit -m "ci: smoke test with hardened python image"
GIT_SSH_COMMAND='ssh -i ~/.ssh/gitlab_lab -o IdentitiesOnly=yes -p 2222' git push -u origin main
```

## 7. Validation finale

Dans GitLab :
- `CI/CD -> Pipelines`
- Le job `python_hardened_smoke` doit passer en vert.

Contrôle runner côté serveur :
```bash
sudo docker exec gitlab-runner gitlab-runner verify
```
Attendu : `Verifying runner... is valid`.

---

### Dépannage rapide

- Clone HTTPS qui bloque : vérifier CA et auth (`GIT_SSL_CAINFO`, PAT/user).
- `Connection refused` sur `git-lab.lab.local:2222` : utiliser `172.16.100.40:2222` (SSH GitLab direct).
- Jobs en `pending` : vérifier tags (`docker`) et état runner `Online`.
