#!/usr/bin/env bash
set -euo pipefail

TFVARS_FILE="${TFVARS_FILE:-terraform.tfvars}"

read_tfvar() {
    local key="$1"
    local line
    line="$(grep -E "^${key}[[:space:]]*=" "$TFVARS_FILE" | head -n1 || true)"
    if [[ -z "$line" ]]; then
        return 1
    fi
    sed -E 's/^[^"]*"([^"]+)".*$/\1/' <<<"$line"
}

if [[ ! -f "$TFVARS_FILE" ]]; then
    echo "❌ Fichier introuvable: $TFVARS_FILE"
    exit 1
fi

PROXMOX_HOST="${PROXMOX_HOST:-$(read_tfvar proxmox_endpoint | sed -E 's#https?://([^/:]+).*#\1#')}"
PROXMOX_NODE="${PROXMOX_NODE:-$(read_tfvar node_name || true)}"
PROXMOX_TOKEN="${PROXMOX_TOKEN:-$(read_tfvar proxmox_api_token || true)}"

if [[ -z "${PROXMOX_HOST}" || -z "${PROXMOX_NODE}" || -z "${PROXMOX_TOKEN}" ]]; then
    echo "❌ Variables manquantes. Renseigne terraform.tfvars ou exporte PROXMOX_HOST, PROXMOX_NODE, PROXMOX_TOKEN."
    exit 1
fi

echo "🚀 Création de toutes les VMs avec cloud-init corrigé..."
echo ""

# Fonction pour créer une VM
create_vm() {
    local vmid=$1
    local name=$2
    local ip=$3
    local cores=$4
    local memory=$5
    local disk=$6
    local tags=$7
    
    echo "📦 ${name} (ID: ${vmid})..."
    
    # Clonage
    curl -k -X POST -s "https://${PROXMOX_HOST}:8006/api2/json/nodes/${PROXMOX_NODE}/qemu/9000/clone" \
        -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "newid=${vmid}&name=${name}&full=1" > /dev/null
    
    sleep 3
    
    # Configuration complète avec cloud-init
    curl -k -X PUT -s "https://${PROXMOX_HOST}:8006/api2/json/nodes/${PROXMOX_NODE}/qemu/${vmid}/config" \
        -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "cores=${cores}" \
        -d "memory=${memory}" \
        -d "onboot=1" \
        -d "tags=${tags}" \
        -d "ipconfig0=ip=${ip}/24,gw=172.16.100.1" \
        -d "cicustom=user=jdk_snippets:snippets/user-data-${name}.yaml" \
        -d "ciuser=ansible" > /dev/null
    
    # Redimensionnement du disque si nécessaire
    if [ "${disk}" != "20" ]; then
        curl -k -X PUT -s "https://${PROXMOX_HOST}:8006/api2/json/nodes/${PROXMOX_NODE}/qemu/${vmid}/resize" \
            -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "disk=scsi0&size=${disk}G" > /dev/null
    fi
    
    # Démarrage
    curl -k -X POST -s "https://${PROXMOX_HOST}:8006/api2/json/nodes/${PROXMOX_NODE}/qemu/${vmid}/status/start" \
        -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" > /dev/null
    
    echo "  ✅ ${name} créée et démarrée"
}

# Création de toutes les VMs selon terraform.tfvars
create_vm 128 "bind9dns"      "172.16.100.254" 2 1024  20 "bind9;dns;prod"
create_vm 132 "tools-manager" "172.16.100.20"  2 4096  60 "ansible;dev;tools"
create_vm 110 "reverse-proxy" "172.16.100.253" 2 2048  30 "nginx;proxy;prod"
create_vm 129 "harbor"        "172.16.100.50"  4 8192  100 "harbor;registry;prod"
create_vm 130 "k3s-manager"   "172.16.100.250" 4 8192  40 "k3s;manager;prod"
create_vm 131 "git-lab"       "172.16.100.40"  4 8192  100 "gitlab;git;prod"
create_vm 133 "k3s-worker-1"  "172.16.100.252" 4 8192  40 "k3s;worker;prod"
create_vm 126 "k3s-worker-0"  "172.16.100.251" 4 8192  40 "k3s;worker;prod"

echo ""
echo "✅ Toutes les VMs créées et démarrées !"
echo "⏳ Attendez 3-4 minutes pour que cloud-init se termine sur toutes les VMs"
echo ""
echo "📝 Pour tester Ansible :"
echo "   cd Ansible && ansible all -m ping"
