# 🔐 Modes d’accès à Proxmox

Ce chapitre résume les différents moyens d’accéder à **Proxmox** dans le cadre de ce projet, et à quoi ils servent.

---

## 1️⃣ Interface web Proxmox (GUI)

- URL typique : `https://10.250.250.4:8006/`
- Authentification avec utilisateur Proxmox (ex. `root@pam` ou un compte dédié).

Usage principal :

- Créer et gérer les **templates** (ex. le template cloud-init `9000`).
- Visualiser et administrer les VMs (console, ressources, disques, snapshots, backups).
- Vérifier l’état du **Qemu Guest Agent** (IPs remontées, etc.).
- Superviser les tâches, les logs et les ressources du node.

C’est l’outil le plus intuitif pour comprendre visuellement ce que Terraform et Ansible font.

---

## 2️⃣ API HTTPs Proxmox

- Endpoint typique : `https://10.250.250.4:8006/api2/json`
- Authentification par **API token**, par exemple :
  - User : `terraform-jdk@pve4`
  - Token ID : `jdk-token`

Dans ce projet, l’API est principalement utilisée via :

- Le **provider Terraform `bpg/proxmox`** (voir [provider.tf](../provider.tf)).
- D’anciens scripts ponctuels (par ex. pour détruire des VMs par ID) utilisés lors des phases de debugging.

Avantages :

- Automatisation complète (pas besoin de session web manuelle).
- Intégration facile avec des outils IaC comme Terraform.

Bonnes pratiques 🔒 :

- Créer un **token dédié** à Terraform, avec des droits limités.
- Éviter d’utiliser le compte `root` directement dans les outils.

---

## 3️⃣ Accès SSH au node Proxmox

L’accès SSH au **node Proxmox** (ex. `pve4`) peut servir à :

- Déboguer des problèmes bas niveau (logs système, stockage, réseau).
- Interagir avec `qm` et autres outils CLI Proxmox.

Ce projet **n’en dépend plus directement** pour le flux normal, puisque :

- Le provider `bpg/proxmox` est configuré pour utiliser uniquement l’API HTTPs + token.
- Les fonctionnalités cloud-init et Qemu Guest Agent sont gérées via l’API.

C’est donc un accès plutôt "ops / admin" que "pipeline".

---

## 4️⃣ Accès SSH aux VMs (via Ansible ou direct)

C’est là que se joue la majorité du travail au quotidien :

- Utilisateur : `ansible`
- Authentification : **clé SSH** injectée par cloud-init (voir [03-cloud-init-et-ssh.md](03-cloud-init-et-ssh.md)).

Deux grandes manières de s’y connecter :

1. **SSH direct** :

   ```bash
   ssh -i ~/.ssh/id_ed25519 ansible@172.16.100.40
   ```

2. **Via Ansible** (recommandé pour l’admin de masse) :

   ```bash
   cd Ansible/
   ANSIBLE_HOST_KEY_CHECKING=False \
   ansible all -i inventory/terraform.generated.yml \
     -u ansible --private-key=$HOME/.ssh/id_ed25519 -m ping
   ```

La logique est la même :

- IPs et utilisateur `ansible` fournis par Terraform + cloud-init.
- Clé privée locale qui doit correspondre à `ssh_public_key` dans `terraform.tfvars`.

---

## 5️⃣ Résumé : qui fait quoi ?

- 🌐 **Interface web Proxmox** :
  - Création/gestion manuelle des templates et VMs.
  - Visualisation et supervision.

- 🧩 **API HTTPs Proxmox** :
  - Pilotée principalement par **Terraform** pour créer/détruire/update les VMs.

- 💻 **SSH vers le node Proxmox** :
  - Administration système du node lui-même (moins utilisé dans le flux standard du projet).

- 🔑 **SSH vers les VMs (via Ansible ou direct)** :
  - Administration du contenu des VMs.
  - Configuration applicative orchestrée par **Ansible**.

---

## 6️⃣ Lien avec le reste de la documentation

Pour replacer ces modes d’accès dans le flux global :

- Création des VMs ➜ [02-terraform-et-proxmox.md](02-terraform-et-proxmox.md)
- Initialisation réseau + SSH ➜ [03-cloud-init-et-ssh.md](03-cloud-init-et-ssh.md)
- Ping/pong Ansible ➜ [04-ansible-et-test-de-connectivite.md](04-ansible-et-test-de-connectivite.md)
- Intégration avancée avec l’hyperviseur ➜ [05-qemu-guest-agent-et-gestion-proxmox.md](05-qemu-guest-agent-et-gestion-proxmox.md)
