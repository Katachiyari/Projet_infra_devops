#!/usr/bin/env bash
set -euo pipefail

PROXMOX_HOST="10.250.250.4"
PROXMOX_NODE="pve4"
PROXMOX_TOKEN=$(grep 'proxmox_api_token' terraform.tfvars | cut -d'"' -f2)

echo "🚀 Création des VMs avec configuration complète..."

# VM bind9dns (ID 128)
echo "📦 Clonage bind9dns..."
curl -k -X POST -s "https://${PROXMOX_HOST}:8006/api2/json/nodes/${PROXMOX_NODE}/qemu/9000/clone" \
  -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "newid=128&name=bind9dns&full=1" > /dev/null

sleep 5

echo "⚙️  Configuration bind9dns..."
curl -k -X PUT -s "https://${PROXMOX_HOST}:8006/api2/json/nodes/${PROXMOX_NODE}/qemu/128/config" \
  -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "cores=2&memory=1024&onboot=1&tags=bind9;dns;prod" \
  -d "ipconfig0=ip=172.16.100.254/24,gw=172.16.100.1" \
  -d "cicustom=user=jdk_snippets:snippets/user-data-bind9dns.yaml" \
  -d "ciuser=ansible" \
  -d "sshkeys=ssh-ed25519%20AAAAC3NzaC1lZDI1NTE5AAAAIE30vg7EchnxPkkVvAnbi0Ey55NGWRiUNE1ClsUvCj7d%20vm-common-key" > /dev/null

echo "▶️  Démarrage bind9dns..."
curl -k -X POST -s "https://${PROXMOX_HOST}:8006/api2/json/nodes/${PROXMOX_NODE}/qemu/128/status/start" \
  -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" > /dev/null

# VM tools-manager (ID 132)
echo "📦 Clonage tools-manager..."
curl -k -X POST -s "https://${PROXMOX_HOST}:8006/api2/json/nodes/${PROXMOX_NODE}/qemu/9000/clone" \
  -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "newid=132&name=tools-manager&full=1" > /dev/null

sleep 5

echo "⚙️  Configuration tools-manager..."
curl -k -X PUT -s "https://${PROXMOX_HOST}:8006/api2/json/nodes/${PROXMOX_NODE}/qemu/132/config" \
  -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "cores=2&memory=4096&onboot=1&tags=ansible;dev;tools" \
  -d "ipconfig0=ip=172.16.100.20/24,gw=172.16.100.1" \
  -d "cicustom=user=jdk_snippets:snippets/user-data-tools-manager.yaml" \
  -d "ciuser=ansible" \
  -d "sshkeys=ssh-ed25519%20AAAAC3NzaC1lZDI1NTE5AAAAIE30vg7EchnxPkkVvAnbi0Ey55NGWRiUNE1ClsUvCj7d%20vm-common-key" > /dev/null

echo "▶️  Démarrage tools-manager..."
curl -k -X POST -s "https://${PROXMOX_HOST}:8006/api2/json/nodes/${PROXMOX_NODE}/qemu/132/status/start" \
  -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" > /dev/null

echo ""
echo "✅ VMs créées et démarrées!"
echo "⏳ Attendez 2-3 minutes pour cloud-init, puis testez:"
echo "   cd Ansible && ansible all -m ping"
