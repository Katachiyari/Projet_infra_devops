# 🔐 **Documentation Vault Ansible - Sécurité Secrets (Pédagogie)**

## 🎯 **Pourquoi Vault ? (Problème → Solution)**

**Problème classique** :
```
❌ git commit -m "feat: mdp GitLab = admin123"
→ Secrets en clair GitHub → Compromis
```

**Solution Vault** :
```
✅ ansible-vault encrypt → Chiffre AES-256
✅ git commit → Fichier .yml chiffré (illisible)
✅ ansible-playbook --ask-vault-pass → Déchiffrage runtime
```

**Analogie** : ZIP chiffré → Ouvrir = mot de passe.

## 🛠️ **Workflow Vault Pas à Pas**

### **1. Création (Éditeur)**

```bash
ansible-vault create secrets/gitlab.yml
# → Vim/nano ouvert
# i → INSERT MODE
---
vault_gitlab_root_password: "GitLabRoot2026Secure!"
vault_gitlab_runner_token: "glrt-AbC123def456GHI789"
# ESC → :wq → Mot de passe Vault : [CHOOSE]
```

### **2. Édition (Modifier)**

```bash
ansible-vault edit secrets/gitlab.yml
# Demande mdp → Modif → :wq
```

### **3. Visualiser (Lisibilité)**

```bash
ansible-vault view secrets/gitlab.yml
# Affiche déchiffré (sans modifier)
```

### **4. Déchiffrage (Temporaire)**

```bash
ansible-vault decrypt secrets/gitlab.yml
# Fichier lisible → git commit → re-encrypt
ansible-vault encrypt secrets/gitlab.yml
```

## 📂 **Structure Secrets SSOT**

**`secrets/gitlab.yml`** :
```yaml
---
# GitLab Admin
vault_gitlab_root_password: "GitLabRoot2026ChangeMe!"

# Runner CI/CD (généré post-deploy UI)
vault_gitlab_runner_token: "glrt-AbCdEfGhIjKlMnOpQrStUvWxYz123456789"

# Intégrations (futur)
vault_harbor_username: "gitlab"
vault_harbor_password: "HarborPass456!"
```

**Référence** `defaults/main.yml` :
```yaml
gitlab_root_password: "{{ vault_gitlab_root_password }}"
gitlab_runner_token: "{{ vault_gitlab_runner_token }}"
```

## 🔑 **Usages Playbook**

| Commande | Usage | Demande MDP |
|----------|-------|-------------|
| `--check --ask-vault-pass` | Dry-run | ✅ |
| `--ask-vault-pass` | Déploiement | ✅ |
| `--vault-password-file=vault_pass.txt` | CI/CD | ❌ |
| `--vault-id @prompt` | Multiple Vaults | ✅ |

## 🧪 **Exemple Déploiement GitLab**

```bash
# 1. Dry-run (variables résolues)
ansible-playbook playbooks/gitlab.yml --check --ask-vault-pass

# 2. Déploiement réel
ansible-playbook playbooks/gitlab.yml --ask-vault-pass

# 3. templates/docker-compose.yml contient :
# GITLAB_OMNIBUS_CONFIG: gitlab_rails['initial_root_password'] = "GitLabRoot2026Secure!"
```

## ⚠️ **Bonnes Pratiques (Sécurité)**

```
✅ MDP Vault ≠ MDP GitLab (séparation)
✅ vault_pass.txt → 0600 (CI/CD)
✅ Rotation : ansible-vault edit → changer
✅ Backup : git push (fichier chiffré)
❌ Ne JAMAIS git commit secrets en clair
```

## 🎓 **Pédagogie : Flux Complet**

```
1. Développeur → vault_gitlab_root_password = "secret123"
2. ansible-vault create → Chiffre AES-256
3. git commit/push → Fichier illisible
4. admin1 → git pull → ansible-playbook --ask-vault-pass
5. Jinja2 → {{ vault_gitlab_root_password }} → "secret123" runtime
6. GitLab démarré → root/secret123
```

## 🚀 **Commandes Utilitaires**

```bash
ansible-vault list *.yml           # Lister fichiers chiffrés
ansible-vault rekey secrets/gitlab.yml  # Changer mdp Vault
ansible-vault decrypt secrets/ --output - | grep password  # Peek
```

**Analogie** : `ansible-vault` = `gpg -c` pour YAML.

**Maintenant** : **`ansible-playbook playbooks/gitlab.yml --ask-vault-pass`** → **GitLab LIVE** 🚀. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_5e74f233-dbdf-418d-afa1-e893b6588eda/ecc3caea-4f39-4230-ad18-cc27f35b9c13/https-github-com-katachiyari-p-bz7svhA9SI2Zm9XDbnnP5Q.md)

**"suivant"** post-deploy.