# 🍼 cloud-init, utilisateur ansible et SSH

Ce chapitre explique comment les VMs reçoivent leur configuration initiale : réseau, utilisateur `ansible` et accès SSH.

---

## 1️⃣ cloud-init côté Proxmox : le bloc `initialization`

Dans ce projet, on utilise la fonctionnalité d'**initialisation Proxmox** (basée sur cloud-init) via Terraform, dans [main.tf](../../main.tf) :

```hcl
initialization {
  ip_config {
    ipv4 {
      address = format("%s/%d", each.value.ip, var.cidr_suffix)
      gateway = var.gateway
    }
  }

  user_account {
    username = "ansible"
    keys     = [var.ssh_public_key]
  }
}
```

Ce bloc demande à Proxmox/cloud-init de :

- Configurer une **IP statique** + **gateway** dans la VM.
- Créer l'utilisateur `ansible`.
- Injecter la clé publique fournie par `var.ssh_public_key` dans `~ansible/.ssh/authorized_keys`.

Résultat attendu ✅ :

- Après le premier boot, on peut faire :

```bash
ssh ansible@IP_DE_LA_VM
```

avec la **clé privée correspondant à la clé publique Terraform**.

---

## 2️⃣ Clé publique SSH : source de vérité

La clé publique utilisée par cloud-init est fournie dans `terraform.tfvars` :

```hcl
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDniJ+owGFsoKItC6RpAYsRypOmTsCK3LEtntb6gT/Ur admin1@management-jdk"
```

Côté machine d'administration, la clé privée correspondante doit être la paire exacte de `ssh_public_key` (exemple courant dans ce lab) :

```bash
~/.ssh/id_ed25519_admin1_nopass
```

C'est cette clé privée qui est utilisée :

- Par **SSH** direct :

  ```bash
  ssh -i ~/.ssh/id_ed25519_admin1_nopass ansible@172.16.100.40
  ```

- Par **Ansible** :

  ```bash
  ansible all -i Ansible/inventory/hosts.yml \
    -u ansible --private-key=~/.ssh/id_ed25519_admin1_nopass -m ping
  ```

🔴 Si la clé publique dans `terraform.tfvars` **ne correspond pas** à la clé privée que tu utilises, tu obtiendras `Permission denied (publickey)`.

---

## 3️⃣ Modèle cloud-init détaillé (référence)

Un fichier cloud-init plus avancé est disponible dans [cloud-init/user-data.yaml.tftpl](../../cloud-init/user-data.yaml.tftpl). Il montre comment :

- Définir le `hostname`.
- Créer un utilisateur `ansible` avec :
  - appartenance au groupe `sudo`,
  - désactivation du mot de passe,
  - clé publique SSH,
  - configuration du shell.
- Installer des paquets (ex. `qemu-guest-agent`, `python3`, `sudo`).
- Durcir la configuration SSH (`PasswordAuthentication no`, `PermitRootLogin no`, etc.).

Ce template sert aujourd'hui surtout de **document de référence**, car la configuration minimale suffisante est déjà transmise via le bloc `initialization` dans [main.tf](../../main.tf).

---

## 4️⃣ Problèmes classiques et résolutions

### 🔐 "Permission denied (publickey)"

Vérifier :

1. La clé publique de `terraform.tfvars` :

   ```bash
   grep ssh_public_key terraform.tfvars
   ```

2. La clé privée utilisée en local :

   ```bash
   ssh-keygen -y -f ~/.ssh/id_ed25519_admin1_nopass
   ```

   Comparer le type + le bloc base64 avec la valeur de `ssh_public_key`.

3. Si elles ne correspondent pas :
   - Mettre à jour `ssh_public_key` avec la **vraie** clé publique.
   - Détruire et recréer les VMs si nécessaire :

     ```bash
     terraform destroy -target=proxmox_virtual_environment_vm.vm -auto-approve
     terraform apply -auto-approve
     ```

### ⚠️ "REMOTE HOST IDENTIFICATION HAS CHANGED!"

Ce message vient de `known_hosts` quand l'IP a déjà été utilisée par une autre VM auparavant.

Solution :

```bash
ssh-keygen -R 172.16.100.40   # adapter l'IP
ssh ansible@172.16.100.40     # accepter le nouveau host key
```

Les scripts modernes du projet (ex. [Ansible/lib/ssh-preflight.sh](../../Ansible/lib/ssh-preflight.sh)) savent aussi nettoyer `known_hosts` de façon automatique.

---

## 5️⃣ Accès direct depuis le poste local (sans jump)

Si le routage est correct et qu'OPNsense ne redirige pas le LAN vers un bastion, l'accès SSH/Ansible se fait en direct depuis le poste local :

```bash
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_admin1_nopass ansible@172.16.100.254
```

Puis :

```bash
cd Ansible
ansible -i inventory/hosts.yml all -m ping -u ansible \
  --private-key ~/.ssh/id_ed25519_admin1_nopass --ask-vault-pass
```

---

## 6️⃣ Vérifier que cloud-init a bien fait son travail

Une fois la VM démarrée :

1. Se connecter en console via l'UI Proxmox.
2. Vérifier l'utilisateur :

   ```bash
   id ansible
   getent passwd ansible
   ```

3. Vérifier `authorized_keys` :

   ```bash
   sudo -u ansible cat ~ansible/.ssh/authorized_keys
   ```

4. Vérifier l'adresse IP dans la VM :

   ```bash
   ip a
   ip route
   ```

Les valeurs doivent correspondre à ce qui est défini dans `nodes` (voir [variables.tf](../../variables.tf) / `terraform.tfvars`).

---

## 7️⃣ Enchaînement avec Ansible

Une fois :

- les VMs créées par Terraform,
- `ansible` créé par cloud-init,
- la clé SSH alignée,

on peut passer à 👉 [04-ansible-et-test-de-connectivite.md](04-ansible-et-test-de-connectivite.md), qui détaille :

- la structure du projet Ansible,
- les scripts d'automatisation,
- et comment arriver au `ansible all -m ping` "pong" sur tout le parc.
