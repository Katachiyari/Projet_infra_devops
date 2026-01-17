#!/usr/bin/env bash
# Script pour créer les VMs via l'API Proxmox directement

set -euo pipefail

PROXMOX_HOST="${PROXMOX_HOST:-10.250.250.4}"
PROXMOX_NODE="${PROXMOX_NODE:-pve4}"
PROXMOX_TOKEN=$(grep 'proxmox_api_token' terraform.tfvars | cut -d'"' -f2)

SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE30vg7EchnxPkkVvAnbi0Ey55NGWRiUNE1ClsUvCj7d vm-common-key"

# Fonction pour cloner et configurer une VM
create_vm() {
    local name=$1
    local vmid=$2
    local cpu=$3
    local mem=$4
    local disk=$5
    local ip=$6
    local snippet=$7
    
    echo "🔧 Création de la VM ${name} (ID: ${vmid})..."
    
    # Clone la VM depuis le template 9000
    curl -k -X POST \
        "https://${PROXMOX_HOST}:8006/api2/json/nodes/${PROXMOX_NODE}/qemu/9000/clone" \
        -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" \
        -d "newid=${vmid}" \
        -d "name=${name}" \
        -d "full=1" \
        --silent --output /dev/null
    
    sleep 3
    
    # Configuration de la VM
    curl -k -X PUT \
        "https://${PROXMOX_HOST}:8006/api2/json/nodes/${PROXMOX_NODE}/qemu/${vmid}/config" \
        -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" \
        -d "cores=${cpu}" \
        -d "memory=${mem}" \
        -d "scsi0=local-lvm:${disk}" \
        -d "ipconfig0=ip=${ip}/24,gw=172.16.100.1" \
        -d "ciuser=ansible" \
        -d "sshkeys=$(echo $SSH_KEY | jq -sRr @uri)" \
        -d "cicustom=user=jdk_snippets:snippets/user-data-${name}.yaml" \
        -d "onboot=1" \
        --silent --output /dev/null
    
    # Démarrage de la VM
    curl -k -X POST \
        "https://${PROXMOX_HOST}:8006/api2/json/nodes/${PROXMOX_NODE}/qemu/${vmid}/status/start" \
        -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" \
        --silent --output /dev/null
    
    echo "  ✅ VM ${name} créée et démarrée"
}

echo "🚀 Création des VMs via l'API Proxmox..."
echo ""

# Créer bind9dns (VM ID 134)
create_vm "bind9dns" 134 2 1024 20 "172.16.100.254" "user-data-bind9dns.yaml"

# Créer tools-manager (VM ID 135)
create_vm "tools-manager" 135 2 4096 60 "172.16.100.20" "user-data-tools-manager.yaml"

echo ""
echo "✅ VMs créées avec succès!"
echo "⏳ Attendez ~2 minutes pour que cloud-init se termine, puis testez Ansible:"
echo "   cd Ansible && ansible all -m ping -i inventory/hosts.yml"
