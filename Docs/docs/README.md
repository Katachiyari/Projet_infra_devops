# 📚 Documentation du projet Infra

Bienvenue dans la documentation détaillée du projet **Terraform + Proxmox + cloud-init + Ansible**.

- 🎯 Objectif : partir de zéro et arriver à `ansible all -m ping` qui répond "pong" sur toutes les VMs.
- 🧩 Composants : Proxmox, Terraform, cloud-init, Qemu Guest Agent, Ansible.
- 👥 Public visé : débutants motivés en infra / DevOps, avec un ton professionnel.

## 🗂 Plan de la doc

1. [01-introduction-et-architecture.md](01-introduction-et-architecture.md)  
   👉 Contexte du projet, objectifs, vue d'ensemble de l'architecture.

2. [02-terraform-et-proxmox.md](02-terraform-et-proxmox.md)  
   👉 Création des VMs Proxmox avec Terraform, variables essentielles, provider et ressources clés.

3. [03-cloud-init-et-ssh.md](03-cloud-init-et-ssh.md)  
   👉 Rôle de cloud-init, création de l'utilisateur `ansible`, gestion de la clé SSH et du réseau.

4. [04-ansible-et-test-de-connectivite.md](04-ansible-et-test-de-connectivite.md)  
   👉 Organisation du répertoire Ansible, scripts d'automatisation et arrivée au fameux ping/pong.

5. [05-qemu-guest-agent-et-gestion-proxmox.md](05-qemu-guest-agent-et-gestion-proxmox.md)  
   👉 Pourquoi et comment activer le Qemu Guest Agent, interactions avancées avec Proxmox.

6. [06-modes-d-acces-a-proxmox.md](06-modes-d-acces-a-proxmox.md)  
   👉 Accès à Proxmox : interface web, API, SSH, et bonnes pratiques de sécurité.

7. [monitoring-stack.md](monitoring-stack.md)  
   👉 Déploiement complet de la stack monitoring (Prometheus, Grafana, Alertmanager, Node Exporter) et intégration DNS.

---

Pour une vue d'ensemble rapide du projet, tu peux aussi consulter :
- [README.md](../../README.md) à la racine (vision globale)
- [Ansible/README.md](../../Ansible/README.md) pour la partie automatisation Ansible.
