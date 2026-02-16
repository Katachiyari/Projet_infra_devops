## 📖 Documentation Étape 4 : Test Runner avec image Python Hardened

**Objectif** : valider de bout en bout qu'un runner `docker` exécute un job CI réel.

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
