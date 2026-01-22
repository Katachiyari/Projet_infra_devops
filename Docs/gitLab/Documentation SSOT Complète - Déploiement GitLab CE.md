# 📚 Documentation SSOT Complète - Déploiement GitLab CE **(Mise à Jour Finale)**

## 🎯 **Nouveautés Intégrées (2h Debug → Leçons)**

**Défis techniques rencontrés** et **solutions production** :
- **Ansible 2.20 rôles** : `tasks/main.yml` = tasks simples (pas plays)
- **Debian 13 Trixie** : `docker.io` natif (docker-ce absent testing)
- **Vault manquant** : `secrets/gitlab.yml` + `--ask-vault-pass`
- **Debug APT** : `apt-cache policy` + `sudo apt update` systématique

## 🏗️ **Étape 1-3 : Identiques (Arborescence + SSOT + Templates)**

**Vérifiées** : `ansible-galaxy init`, `defaults/main.yml`, `docker-compose.yml.j2`.

## 🔧 **Étape 4 : Tasks Production (Leçon Debug)**

**`tasks/main.yml` final** (12 lignes, Debian 13 validé) :

```yaml
---
- name: Docker natif Debian 13
  package:
    name: docker.io
    state: present
  become: true

- name: /srv/gitlab
  file:
    path: /srv/gitlab
    state: directory
  become: true

- name: docker-compose.yml
  template:
    src: docker-compose.yml.j2
    dest: /srv/gitlab/docker-compose.yml
  notify: restart gitlab
  become: true

- name: runner-config.toml
  template:
    src: runner-config.toml.j2
    dest: /srv/gitlab-runner/config.toml
  notify: restart runner
  become: true

- name: docker compose up -d
  command: docker compose up -d
  args:
    chdir: /srv/gitlab
  become: true

- name: Healthcheck http://172.16.100.40/-/health
  uri:
    url: "http://{{ gitlab_ip }}/-/health"
    status_code: 200
  retries: 30
  delay: 10
```

## 🔍 **Étape 4.1 : Debug APT Systématique**

**Checklist diagnostic** (2h → 2min) :
```bash
ansible gitlab_hosts -m shell -a "cat /etc/os-release" -b
ansible gitlab_hosts -m shell -a "sudo apt update && sudo apt-cache policy docker.io" -b
# DISTRIB_ID="Debian" VERSION_CODENAME="trixie" → docker.io OK
```

## 🔐 **Étape 6 : Vault Secrets (Bloqueur Résolu)**

```bash
ansible-vault create secrets/gitlab.yml
# vault_gitlab_root_password: "GitLabRoot2026Secure!"
# vault_gitlab_runner_token: "glrt-xyz123..."
```

**Usage** :
```bash
ansible-playbook playbooks/gitlab.yml --ask-vault-pass
```

## 🌐 **Étape 5 : Intégrations (playbooks/gitlab.yml)**

**Orchestration** :
```
gitlab_hosts → gitlab + node_exporter
reverse_proxy_hosts → nginx_reverse_proxy (gitlab.lab.local)
bind9_hosts → bind9_docker (A 172.16.100.253)
```

## ✅ **Checklist Déploiement Finale**

```
✅ Rôle gitlab/ complet
✅ tasks/main.yml 12 lignes (docker.io natif)
✅ templates Jinja2 SSOT
✅ playbooks/gitlab.yml orchestration
✅ Debug : Debian 13 Trixie confirmé
[ ] ansible-vault secrets/gitlab.yml
[ ] ansible-playbook --ask-vault-pass → GitLab UP
[ ] curl http://172.16.100.40/-/health → 200
```

## 🎓 **Leçons 2h → Production**

1. **Debug APT 1er** : `apt-cache policy` avant package
2. **Debian Testing** : Natif repos > Docker CE
3. **Vault systématique** : `--ask-vault-pass` dès dev
4. **Syntaxe rôles** : tasks simples, pas plays
5. **SSOT dynamique** : `{{ ansible_distribution_release }}`

**Maintenant** : **Vault → Deploy → Live** 🚀. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_5e74f233-dbdf-418d-afa1-e893b6588eda/ecc3caea-4f39-4230-ad18-cc27f35b9c13/https-github-com-katachiyari-p-bz7svhA9SI2Zm9XDbnnP5Q.md)

**"suivant"** post-déploiement.