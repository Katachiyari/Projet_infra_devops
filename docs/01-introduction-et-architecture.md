# 🧭 Introduction et architecture globale

## 1️⃣ Contexte et objectifs du projet

Ce projet a été conçu pour automatiser **de bout en bout** la création et la gestion d'une infrastructure sur **Proxmox**, en utilisant :

- **Terraform** 🏗️ pour créer et détruire les VMs de manière déclarative.
- **cloud-init** 🍼 pour initialiser les VMs (utilisateur, SSH, paquets de base).
- **Ansible** 🤖 pour configurer et administrer les services applicatifs.
- **Qemu Guest Agent** 🛰️ pour améliorer l'intégration entre Proxmox et les VMs.

🎯 Objectif final :

> Partir d'un Proxmox fonctionnel et arriver à un `ansible all -m ping` **réussi** sur toutes les VMs, avec une stack propre, reproductible et documentée.


## 2️⃣ Vue d'ensemble de l'architecture

### Composants principaux

- **Proxmox VE**
  - Hyperviseur qui héberge les VMs (node `pve4`).
  - Fournit une **API HTTPs** et une interface web d'administration.

- **Terraform**
  - Utilise le provider `bpg/proxmox`.
  - Crée des VMs en clonant un template (ID `9000`).
  - Configure l'IP, le bridge, les ressources (CPU, RAM, disque) et l'initialisation via cloud-init.

- **cloud-init / Initialisation Proxmox**
  - Configure l'utilisateur `ansible`.
  - Injecte la clé publique SSH.
  - Gère la configuration réseau (IP statique + gateway).

- **Ansible**
  - S'appuie sur un inventaire généré automatiquement par Terraform.
  - Se connecte en SSH avec l'utilisateur `ansible` et une clé privée.
  - Teste la connectivité avec le module `ping`.

- **Qemu Guest Agent**
  - Service tournant dans la VM.
  - Permet à Proxmox de récupérer des infos précises (IP réelles, état OS) et de faire des opérations plus propres (shutdown, backups, etc.).


## 3️⃣ Flux global (du zéro au ping/pong)

1. **Préparation côté Proxmox**
   - Création d'un **template de VM** (id `9000`) compatible cloud-init.
   - Création d'un **API token** pour Terraform.

2. **Terraform**
   - Configuration du provider Proxmox dans [provider.tf](../provider.tf).
   - Définition des VMs (noms, IPs, ressources) dans [variables.tf](../variables.tf) et `terraform.tfvars`.
   - Ressource principale : [main.tf](../main.tf) avec `proxmox_virtual_environment_vm`.

3. **Initialisation cloud-init**
   - Terraform passe les paramètres d'initialisation (réseau + utilisateur) via le bloc `initialization`.
   - Optionnellement, un fichier cloud-init détaillé est disponible dans [cloud-init/user-data.yaml.tftpl](../cloud-init/user-data.yaml.tftpl).

4. **Génération de l'inventaire Ansible**
   - Terraform produit un fichier d'inventaire dans [Ansible/inventory/terraform.generated.yml](../Ansible/inventory/terraform.generated.yml).

5. **Ansible**
   - Tests de connectivité avec [Ansible/run-ping-test.sh](../Ansible/run-ping-test.sh) ou une commande `ansible all -m ping`.
   - Déploiement d'applications et de services via les playbooks dans [Ansible/playbooks](../Ansible/playbooks).

6. **Qemu Guest Agent**
   - Activé dans [main.tf](../main.tf) via le bloc `agent { enabled = true }`.
   - Installé et démarré dans les VMs (via Ansible) pour une meilleure intégration Proxmox.


## 4️⃣ Fichiers essentiels de l'infrastructure

### Côté Terraform / Proxmox

- [provider.tf](../provider.tf)  
  ➜ Déclare le provider Proxmox et configure l'accès API (endpoint + token).

- [variables.tf](../variables.tf)  
  ➜ Déclare les variables : endpoint, token, datastore, gateway, map des VMs, etc.

- `terraform.tfvars` (non versionné)  
  ➜ Fournit les valeurs réelles : IPs, token Proxmox, clé publique SSH, etc.

- [main.tf](../main.tf)  
  ➜ Ressource `proxmox_virtual_environment_vm` qui décrit chaque VM :
  - clonage du template,
  - config CPU/RAM/disque,
  - bridge réseau,
  - bloc `initialization` (IP + utilisateur `ansible` + clé SSH),
  - bloc `agent` pour Qemu Guest Agent.

- [cloud-init/user-data.yaml.tftpl](../cloud-init/user-data.yaml.tftpl)  
  ➜ Modèle cloud-init plus avancé (packages, sshd, sudo, etc.), utilisé comme référence.

### Côté Ansible

- [Ansible/ansible.cfg](../Ansible/ansible.cfg)  
  ➜ Paramètres globaux Ansible (inventaires, utilisateur par défaut, SSH, logs).

- [Ansible/inventory/terraform.generated.yml](../Ansible/inventory/terraform.generated.yml)  
  ➜ Inventaire dynamique généré par Terraform, basé sur les IPs définies.

- [Ansible/lib/ssh-preflight.sh](../Ansible/lib/ssh-preflight.sh)  
  ➜ Préparation SSH : choix de la bonne clé, nettoyage `known_hosts`, gestion d'`ssh-agent`.

- [Ansible/run-ping-test.sh](../Ansible/run-ping-test.sh)  
  ➜ Script haut niveau pour tester la connectivité SSH + Ansible sur toutes les VMs.

- [Ansible/bootstrap.sh](../Ansible/bootstrap.sh) et [Ansible/validate.sh](../Ansible/validate.sh)  
  ➜ Mise en place de l'environnement Ansible et validation globale.


## 5️⃣ Comment lire la suite de la documentation

- Si tu découvres complètement Terraform + Proxmox : commence par 👉 [02-terraform-et-proxmox.md](02-terraform-et-proxmox.md).
- Si tu veux comprendre comment l'utilisateur `ansible` + SSH sont mis en place : 👉 [03-cloud-init-et-ssh.md](03-cloud-init-et-ssh.md).
- Si ton but est juste d'arriver au `ansible all -m ping` fonctionnel : 👉 [04-ansible-et-test-de-connectivite.md](04-ansible-et-test-de-connectivite.md).
- Pour les fonctionnalités avancées (Qemu Agent, intégration Proxmox) : 👉 [05-qemu-guest-agent-et-gestion-proxmox.md](05-qemu-guest-agent-et-gestion-proxmox.md) et [06-modes-d-acces-a-proxmox.md](06-modes-d-acces-a-proxmox.md).
