# 🤖 Ansible et test de connectivité (ping/pong)

Ce chapitre explique comment est organisée la partie **Ansible** du projet et comment on arrive à un `ansible all -m ping` qui fonctionne sur toutes les VMs.

---

## 1️⃣ Organisation du répertoire Ansible

Le répertoire principal est [Ansible/](../Ansible/README.md). Sa structure (simplifiée) :

```text
Ansible/
├── ansible.cfg
├── README.md
├── AUTOMATION_GUIDE.md
├── bootstrap.sh
├── validate.sh
├── run-ping-test.sh
├── run-taiga-apply.sh
│
├── inventory/
│   ├── terraform.generated.yml
│   ├── hosts.yml
│   ├── group_vars/
│   └── host_vars/
│
├── lib/
│   └── ssh-preflight.sh
│
├── playbooks/
│   ├── ping-test.yml
│   ├── taiga.yml
│   └── bind9-docker.yml
└── roles/
    └── ...
``

Les fichiers essentiels :

- [Ansible/ansible.cfg](../Ansible/ansible.cfg)  
  ➜ Fichier de configuration central (inventaires, `remote_user`, options SSH, logs, etc.).

- [Ansible/inventory/terraform.generated.yml](../Ansible/inventory/terraform.generated.yml)  
  ➜ Inventaire généré par Terraform, listant les hôtes et leurs IPs.

- [Ansible/lib/ssh-preflight.sh](../Ansible/lib/ssh-preflight.sh)  
  ➜ Script avancé de préparation SSH (clé, known_hosts, ssh-agent).

- [Ansible/run-ping-test.sh](../Ansible/run-ping-test.sh)  
  ➜ Script d'orchestration pour tester la connectivité Ansible.

---

## 2️⃣ Préparation de l'environnement Ansible

Dans [Ansible/README.md](../Ansible/README.md), le workflow recommandé est :

1. **Validation initiale** ✅

   ```bash
   cd Ansible/
   ./validate.sh
   ```

   Ce script vérifie :
   - la présence de Python, pip, git, ansible,
   - la cohérence des inventaires et scripts,
   - la configuration SSH (clé vs terraform.tfvars).

2. **Bootstrap de l'environnement** 🚀

   ```bash
   chmod +x bootstrap.sh run-ping-test.sh validate.sh
   ./bootstrap.sh
   ```

   Ce script :
   - installe ou valide Ansible,
   - installe les rôles/collections définis dans `requirements.yml`,
   - vérifie les playbooks,
   - prépare l'environnement pour les exécutions ultérieures.

---

## 3️⃣ Test de connectivité avec `run-ping-test.sh`

Le script [Ansible/run-ping-test.sh](../Ansible/run-ping-test.sh) fournit une interface haut niveau :

```bash
cd Ansible/
./run-ping-test.sh
```

Il se charge de :

1. Vérifier les prérequis (binaire `ansible`, `ansible-inventory`, outils SSH, etc.).
2. Valider l'inventaire (notamment `inventory/terraform.generated.yml`).
3. Lancer un **SSH preflight** via [lib/ssh-preflight.sh](../Ansible/lib/ssh-preflight.sh) :
   - auto-détection de la bonne clé privée,
   - nettoyage de `~/.ssh/known_hosts` si nécessaire,
   - gestion optionnelle de `ssh-agent`.
4. Exécuter un playbook de test (souvent `playbooks/ping-test.yml`) qui fait un `ping` Ansible sur tous les hôtes.

En cas de succès, tu dois voir des `SUCCESS` avec `"ping": "pong"` pour chaque hôte.

---

## 4️⃣ Commande Ansible "brute" pour debug

Quand tu veux vérifier rapidement la connectivité sans passer par les scripts, tu peux utiliser :

```bash
cd /home/admin1/Documents/Projet_infra_devops/Ansible

ANSIBLE_HOST_KEY_CHECKING=False \
ansible all \
  -i inventory/terraform.generated.yml \
  -u ansible \
  --private-key=$HOME/.ssh/id_ed25519 \
  -m ping
```

Cette commande :

- Utilise l'inventaire généré par Terraform.
- Se connecte en SSH avec l'utilisateur `ansible`.
- Utilise explicitement ta clé privée `~/.ssh/id_ed25519`.
- Désactive le check de `known_hosts` pour éviter les erreurs de type "REMOTE HOST IDENTIFICATION HAS CHANGED".

Si tout est bien aligné (cloud-init, SSH, réseau), tous les hôtes répondent `"ping": "pong"` ✅.

---

## 5️⃣ Pièges classiques côté Ansible

- 🔑 **Mauvaise clé privée utilisée** :
  - Solution : forcer `--private-key=~/.ssh/id_ed25519` ou ajuster `ansible_ssh_private_key_file` dans l'inventaire / `group_vars`.

- 🧾 **Inventaire incohérent** :
  - Solution : s'assurer que `terraform apply` vient d'être exécuté et que `inventory/terraform.generated.yml` correspond aux VMs actuelles.

- 🌐 **Réseau non disponible** :
  - Solution : vérifier que les VMs ont bien booté, que les IPs sont correctes (`ping 172.16.100.x`), et que les firewalls ne bloquent pas SSH.

---

## 6️⃣ Étape suivante : déploiement applicatif

Une fois le `ping/pong` validé :

- Tu peux exécuter des playbooks réels, par exemple :

  ```bash
  cd Ansible/
  ./run-taiga-apply.sh
  ```

- Tu peux aussi lancer directement :

  ```bash
  ansible-playbook -i inventory/terraform.generated.yml playbooks/taiga.yml
  ```

Pour comprendre les bonnes pratiques et les scripts en détail, voir :

- [Ansible/README.md](../Ansible/README.md)
- [Ansible/AUTOMATION_GUIDE.md](../Ansible/AUTOMATION_GUIDE.md)

---

## 7️⃣ Rappel : dépendances amont

Le `ping/pong` repose sur :

- Terraform qui a créé les VMs et généré l'inventaire.
- cloud-init qui a créé l'utilisateur `ansible` et injecté la clé publique.
- Le réseau Proxmox correctement configuré (bridge, VLAN, gateway).

Si un de ces étages est cassé, Ansible ne pourra pas faire de miracles 😉. Dans ce cas, revenir aux chapitres :

- 👉 [02-terraform-et-proxmox.md](02-terraform-et-proxmox.md)
- 👉 [03-cloud-init-et-ssh.md](03-cloud-init-et-ssh.md)
