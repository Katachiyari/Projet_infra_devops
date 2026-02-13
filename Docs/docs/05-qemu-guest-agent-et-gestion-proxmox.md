# 🛰️ Qemu Guest Agent et gestion Proxmox

Ce chapitre explique ce qu'est le **Qemu Guest Agent**, pourquoi il est utile et comment il est intégré dans ce projet.

---

## 1️⃣ Qu'est-ce que le Qemu Guest Agent ?

Le **Qemu Guest Agent** est un petit service qui tourne à l'intérieur de la VM et qui permet à l'hyperviseur (ici **Proxmox**) de :

- Récupérer des informations précises sur la VM (IP internes, OS, etc.).
- Réaliser des **arrêts propres** (shutdown) au lieu de couper brutalement l'alimentation.
- Améliorer la **cohérence des sauvegardes** en figeant / coordonnant le système de fichiers.
- Exposer des informations plus fiables dans l'interface Proxmox (ex. IPs affichées dans la vue de la VM).

En résumé :

> Sans guest agent, Proxmox pilote surtout le **matériel virtuel**. Avec le guest agent, il peut aussi dialoguer avec le **système d'exploitation invité**.

---

## 2️⃣ Activation côté Terraform / Proxmox

Dans [main.tf](../../main.tf), le guest agent est activé pour toutes les VMs :

```hcl
agent {
  enabled = true
}
```

Cela :

- Indique à Proxmox que la VM doit utiliser le Qemu Guest Agent.
- Permet à Terraform (via le provider) d'attendre des infos provenant de l'agent (IP, état), si nécessaire.

⚠️ Important : ce bloc **n'installe pas** le binaire `qemu-guest-agent` dans la VM. Il ne fait que déclarer que la VM **est censée** en disposer.

---

## 3️⃣ Installation du Qemu Guest Agent dans les VMs

L'installation logicielle se fait **dans la VM** (Debian dans ce projet). Par exemple via Ansible :

```bash
cd Ansible/

# Installation du package
ANSIBLE_HOST_KEY_CHECKING=False \
ansible all -b -u ansible --private-key=$HOME/.ssh/id_ed25519 \
  -m apt -a 'name=qemu-guest-agent state=present update_cache=yes'

# Démarrage et activation au boot
ANSIBLE_HOST_KEY_CHECKING=False \
ansible all -b -u ansible --private-key=$HOME/.ssh/id_ed25519 \
  -m service -a 'name=qemu-guest-agent state=started enabled=yes'
```

Une fois :

- le bloc `agent { enabled = true }` en place côté Proxmox/Terraform,
- le service `qemu-guest-agent` installé et démarré dans la VM,

l'intégration est complète ✅.

---

## 4️⃣ Vérifications dans l'UI Proxmox

Sur l'interface web Proxmox :

1. Aller sur une VM (ex. `git-lab`).
2. Regarder dans l'onglet **Summary** / **Résumé** :
   - Les **IP internes** de la VM doivent remonter correctement.
3. Utiliser les boutons :
   - `Shutdown` / `Arrêt` devrait demander un arrêt propre au système invité.
   - Les backups peuvent utiliser les fonctionnalités exposées par l'agent pour améliorer la cohérence.

Si les IP ne remontent pas ou si Terraform se plaint de timeouts sur le guest agent, vérifier :

- Que le service est bien actif dans la VM :

  ```bash
  systemctl status qemu-guest-agent
  ```

- Que l'option agent est bien activée dans la config Proxmox (visible aussi dans l'onglet **Options** de la VM).

---

## 5️⃣ Interaction avec Terraform

Le provider `bpg/proxmox` peut, selon les options, attendre que le guest agent :

- Remonte les interfaces réseau.
- Signale que la VM est complètement démarrée.

Dans les logs Terraform, tu peux parfois voir des messages du type :

> timeout while waiting for the QEMU agent on VM "XYZ" to publish the network interfaces

Ces erreurs apparaissent quand :

- `agent.enabled = true` côté Terraform/Proxmox,
- mais que le service `qemu-guest-agent` **n'est pas installé ou pas démarré** dans la VM.

La séquence correcte est donc :

1. Activer `agent { enabled = true }` dans [main.tf](../../main.tf).
2. Appliquer Terraform (`terraform apply`).
3. Installer et démarrer `qemu-guest-agent` via Ansible.
4. Re-lancer un `terraform apply` si nécessaire pour que le provider valide correctement l'état.

---

## 6️⃣ Faut-il toujours activer le Qemu Guest Agent ?

- En **environnement de lab / formation** :
  - C'est un plus appréciable (meilleure visibilité, arrêts propres), mais pas strictement obligatoire.

- En **production** :
  - Fortement recommandé pour :
    - les backups cohérents,
    - les opérations de maintenance,
    - le monitoring / reporting précis.

Dans ce projet, il est activé pour coller aux **bonnes pratiques** et se rapprocher d'un setup de production.

---

## 7️⃣ Lien avec le reste de la stack

Le Qemu Guest Agent vient **compléter** le trio :

- Terraform ➜ crée et décrit les VMs.
- cloud-init ➜ initialise OS, réseau, utilisateur `ansible`.
- Ansible ➜ configure les services applicatifs.

Le guest agent :

- Donne à Proxmox une meilleure visibilité sur ce que fait tout cet écosystème dans la VM.
- Facilite l'exploitation quotidienne (ops) côté hyperviseur.

Pour revenir au flux complet (du terraform apply au ping/pong Ansible), voir :

- [01-introduction-et-architecture.md](01-introduction-et-architecture.md)
- [02-terraform-et-proxmox.md](02-terraform-et-proxmox.md)
- [03-cloud-init-et-ssh.md](03-cloud-init-et-ssh.md)
- [04-ansible-et-test-de-connectivite.md](04-ansible-et-test-de-connectivite.md)
