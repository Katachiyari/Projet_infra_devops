# 🚀 Automatisation Ansible - Projet Infrastructure DevOps

**Version:** 2026-01-16  
**Status:** ✅ Optimisée avec bonnes pratiques officielles

## 📌 Résumé des améliorations

Ce projet a été refactorisé complètement pour respecter les **bonnes pratiques officielles** selon:

- **Bash**: [GNU Bash Manual](https://www.gnu.org/software/bash/manual/)
- **Ansible**: [Ansible Official Documentation](https://docs.ansible.com/)
- **SSH**: [OpenSSH Manual](https://man.openbsd.org/ssh)

### ✨ Améliorations apportées

#### 1. **ssh-preflight.sh** 🔐
- ✅ Logging complet avec niveaux (INFO, DEBUG, WARN, ERROR)
- ✅ Gestion robuste des erreurs et exceptions
- ✅ Meilleure extraction des clés Terraform
- ✅ Validation complète avant SSH agent setup
- ✅ Messages d'erreur explicites avec solutions
- ✅ Support des passphrases SSH
- ✅ Nettoyage automatique des known_hosts

#### 2. **run-ping-test.sh** 🧪
- ✅ Interface CLI améliorée (--help, --bastion, --key, --verbose)
- ✅ Validation des prérequis (ansible-playbook, ssh-keygen, etc.)
- ✅ Vérification de l'inventaire avant exécution
- ✅ Couleurs ANSI pour meilleure lisibilité
- ✅ Logging structuré avec timestamps
- ✅ Gestion d'erreurs avec stack trace
- ✅ Utilisation correcte des arrays bash

#### 3. **bootstrap.sh** 📦
- ✅ Installation automatique d'Ansible
- ✅ Installation des dépendances Python
- ✅ Installation des roles/collections Ansible
- ✅ Validation complète de la setup
- ✅ Vérification SSH avec terraform.tfvars
- ✅ Messages "Next steps" pour guider l'utilisateur
- ✅ Gestion propre du projet_root

#### 4. **ansible.cfg** ⚙️
- ✅ Configuration consolidée (une seule section par type)
- ✅ Logging centralisé dans /tmp/ansible.log
- ✅ Performance optimisée (pipelining=True, forks=5)
- ✅ Callbacks pour affichage amélioré
- ✅ Fact caching pour accélération
- ✅ Paramètres SSH officiels (ControlMaster, ControlPersist)
- ✅ Support ProxyJump pour bastion

#### 5. **validate.sh** ✓
- ✅ Script de validation complet et non-bloquant
- ✅ Vérification système (Python, pip, git, SSH)
- ✅ Vérification Ansible (playbooks, roles, inventory)
- ✅ Vérification SSH avec correspondance terraform.tfvars
- ✅ Vérification des scripts bash
- ✅ Rapport détaillé avec statistiques
- ✅ Suggestions de correction

#### 6. **Documentation** 📚
- ✅ AUTOMATION_GUIDE.md exhaustif
- ✅ Instructions d'installation et configuration
- ✅ Guide d'utilisation de chaque script
- ✅ Architecture et flux d'exécution expliqués
- ✅ Dépannage avec solutions
- ✅ Bonnes pratiques Ansible/SSH

---

## 🚀 Démarrage rapide

### 1. Validation initiale
```bash
cd Ansible/
./validate.sh
```

### 2. Bootstrap l'environnement
```bash
chmod +x bootstrap.sh run-ping-test.sh validate.sh
./bootstrap.sh
```

### 3. Tester la connectivité
```bash
./run-ping-test.sh
```

### 4. Déployer
```bash
./run-taiga-apply.sh
```

---

## 📁 Architecture améliorée

```
Ansible/
├── 📖 AUTOMATION_GUIDE.md        ← Guide complet
├── 📋 README.md                  ← Ce fichier
├── ✓ validate.sh                 ← Validation complète
├── 🚀 run-ping-test.sh           ← Test connectivité (amélioré)
├── 🚀 run-taiga-apply.sh         ← Déploiement Taiga
├── 🚀 bootstrap.sh               ← Setup Ansible (amélioré)
│
├── 📄 ansible.cfg                ← Configuration Ansible (fixée)
├── 📋 requirements.yml           ← Collections/roles
│
├── 🔐 lib/
│   └── ssh-preflight.sh          ← SSH setup (amélioré)
│
├── 📦 inventory/
│   ├── terraform.generated.yml   ← Généré par Terraform
│   ├── hosts.yml                 ← Fallback statique
│   ├── group_vars/
│   │   ├── all.yml
│   │   ├── taiga_hosts.yml
│   │   └── taiga_hosts.vault.yml
│   └── host_vars/
│       └── bind9dns.yml
│
├── 🎭 playbooks/
│   ├── ping-test.yml
│   ├── taiga.yml
│   └── bind9-docker.yml
│
└── 🔧 roles/
    ├── bind9_docker/
    ├── systemli.bind9/
    └── taiga/
```

---

## 🔑 Gestion automatique des clés SSH

### Auto-détection
Le script **ssh-preflight.sh** détecte automatiquement la bonne clé SSH:

```bash
1. Extrait ssh_public_key de terraform.tfvars
2. Cherche dans: ~/.ssh/id_ed25519_common → id_ed25519 → id_rsa
3. Compare type+base64 pour trouver la correspondance
4. Charge dans ssh-agent
```

### Configuration manuelle
```bash
# Vérifier la clé
ssh-keygen -y -f ~/.ssh/id_ed25519_common

# Mettre à jour terraform.tfvars
ssh_public_key = "ssh-ed25519 AAAAC3... vm-common-key"
```

---

## 📊 Logging et débogage

### Activer logs détaillés
```bash
# Variable d'env
LOG_LEVEL=DEBUG ./run-ping-test.sh

# Argument CLI
./run-ping-test.sh --verbose

# Fichier log Ansible
tail -f /tmp/ansible.log
```

### Logs disponibles
- **stdout**: Messages INFO (couleurs ANSI)
- **stderr**: DEBUG, WARN, ERROR
- **/tmp/ansible.log**: Logs Ansible complets

---

## ✅ Validations intégrées

### run-ping-test.sh
1. ✓ Prérequis système (ansible-playbook, ssh-keygen, etc.)
2. ✓ Inventaire valide
3. ✓ SSH preflight checks
4. ✓ Playbook exécution

### bootstrap.sh
1. ✓ Python 3 présent
2. ✓ pip3 disponible
3. ✓ Ansible installé
4. ✓ Collections/roles installés
5. ✓ Playbooks syntaxiquement valides
6. ✓ Clés SSH correspondantes

### validate.sh (standalone)
1. ✓ Système (Python, pip, git, SSH)
2. ✓ Ansible (version, playbooks, roles, inventory)
3. ✓ SSH (clés, terraform.tfvars, permissions)
4. ✓ Configuration (ansible.cfg, variables)
5. ✓ Scripts (exécutabilité, syntaxe bash)
6. ✓ Connectivité réseau (non-bloquant)

---

## 🐛 Dépannage

### "No matching private key found"
```bash
# Vérifier la clé
grep ssh_public_key ../terraform.tfvars
ssh-keygen -y -f ~/.ssh/id_ed25519_common

# Correspondance?
ssh-keygen -y -f ~/.ssh/id_ed25519_common | awk '{print $1" "$2}'
# Doit correspondre à terraform.tfvars
```

### "Permission denied (publickey)"
```bash
# Permissions clés
chmod 600 ~/.ssh/id_ed25519_common
chmod 600 ~/.ssh/id_ed25519

# Test SSH direct
ssh -vvv -i ~/.ssh/id_ed25519_common ansible@172.16.100.254
```

### "SSH agent refused operation"
```bash
# Redémarrer agent
pkill -f ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519_common

# Vérifier
ssh-add -l
```

### Playbook timeout
```bash
# Vérifier connectivité
./run-ping-test.sh

# Logs détaillés
LOG_LEVEL=DEBUG ./run-ping-test.sh -vvvv
```

---

## 📚 Ressources officielles

| Ressource | URL |
|-----------|-----|
| Ansible Docs | https://docs.ansible.com/ |
| Ansible Best Practices | https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html |
| Bash Manual | https://www.gnu.org/software/bash/manual/ |
| SSH Manual | https://man.openbsd.org/ssh |
| ShellCheck | https://www.shellcheck.net/ |

---

## 🎯 Checklist avant production

- [ ] `./validate.sh` ✅ passe toutes les vérifications
- [ ] Clés SSH correspondent entre terraform.tfvars et ~/.ssh/
- [ ] `./run-ping-test.sh` ✅ peut atteindre tous les hôtes
- [ ] Variables vault (taiga_hosts.vault.yml) configurées
- [ ] Playbooks testés en mode `--check`
- [ ] Logs archivés pour audit
- [ ] SSH known_hosts cleanup marche correctement

---

## 🔄 Workflow typique

```bash
# 1. Vérifier setup
./validate.sh

# 2. Bootstrap si première fois
./bootstrap.sh

# 3. Test de connectivité
./run-ping-test.sh

# 4. Dry-run avant déploiement
ansible-playbook playbooks/taiga.yml --check

# 5. Déploiement
./run-taiga-apply.sh

# 6. Vérification post-déploiement
./run-ping-test.sh  # Double-check
```

---

## 📝 Modifications récentes

**2026-01-16 - Refacto complète:**
- ✅ Remplacement ssh-preflight.sh (logging, gestion erreurs)
- ✅ Remplacement run-ping-test.sh (CLI, validations)
- ✅ Remplacement bootstrap.sh (installation, setup)
- ✅ Fixe ansible.cfg (suppression section dupliquée)
- ✅ Ajout validate.sh (validation complète)
- ✅ Ajout AUTOMATION_GUIDE.md (documentation exhaustive)

---

## 👥 Support

Pour les questions ou problèmes:

1. **Consulter** AUTOMATION_GUIDE.md
2. **Exécuter** `LOG_LEVEL=DEBUG ./run-ping-test.sh`
3. **Vérifier** logs: `tail -f /tmp/ansible.log`
4. **Valider** avec: `./validate.sh --verbose`

---

**Maintenant prêt pour une automatisation complète! 🎉**
