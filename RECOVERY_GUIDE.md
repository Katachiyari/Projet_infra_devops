# Guide de récupération - Recréer les VMs avec cloud-init corrigé

## Problème
Le provider Terraform ne peut pas se connecter via SSH au serveur Proxmox pour uploader les snippets cloud-init.

## Solution : Recréer manuellement les 2 VMs (bind9dns et tools-manager)

### Option 1 : Via l'interface web Proxmox

1. **Accéder à Proxmox** : https://votre-proxmox:8006

2. **Upload des snippets cloud-init** :
   - Datacenter → pve4 → jdk_snippets
   - Upload → Sélectionner `generated-cloud-init/user-data-bind9dns.yaml`
   - Upload → Sélectionner `generated-cloud-init/user-data-tools-manager.yaml`

3. **Créer la VM bind9dns** :
   - Clone VM 9000 (template)
   - Name: bind9dns
   - Mode: Full Clone
   - Cloud-Init:
     - User: ansible
     - SSH Public Key: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE30vg7EchnxPkkVvAnbi0Ey55NGWRiUNE1ClsUvCj7d vm-common-key
     - IP Config: 172.16.100.254/24, Gateway: 172.16.100.1
     - User Data: jdk_snippets:snippets/user-data-bind9dns.yaml
   - CPU: 2 cores
   - Memory: 1024 MB
   - Disk: 20 GB
   - Network: vmbr23

4. **Créer la VM tools-manager** :
   - Clone VM 9000 (template)
   - Name: tools-manager
   - Mode: Full Clone
   - Cloud-Init:
     - User: ansible
     - SSH Public Key: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE30vg7EchnxPkkVvAnbi0Ey55NGWRiUNE1ClsUvCj7d vm-common-key
     - IP Config: 172.16.100.20/24, Gateway: 172.16.100.1
     - User Data: jdk_snippets:snippets/user-data-tools-manager.yaml
   - CPU: 2 cores
   - Memory: 4096 MB
   - Disk: 60 GB
   - Network: vmbr23

5. **Démarrer les VMs** et attendre ~2 minutes pour cloud-init

### Option 2 : Import du state Terraform précédent

Si les VMs sont recréées manuellement avec les mêmes IDs:

```bash
terraform import 'proxmox_virtual_environment_vm.vm["bind9dns"]' 128
terraform import 'proxmox_virtual_environment_vm.vm["tools-manager"]' 132
```

### Option 3 : Attendre et réessayer Terraform

Le problème SSH avec Proxmox pourrait être temporaire (charge, limite de connexions).
Attendre quelques minutes et réessayer :

```bash
terraform apply -auto-approve
```

## Test Ansible une fois les VMs créées

```bash
cd Ansible
ansible all -m ping -i inventory/hosts.yml
```

✅ Le cloud-init est maintenant conforme aux bonnes pratiques officielles:
- Création explicite de l'utilisateur `ansible` dans cloud-init
- Clé SSH automatiquement déployée
- Python3 installé pour Ansible
- Configuration sécurisée du SSH (pas de mot de passe, clés uniquement)
