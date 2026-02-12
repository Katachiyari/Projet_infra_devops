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
  -d "ciuser=ansible" > /dev/null

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
  -d "ciuser=ansible" > /dev/null

echo "▶️  Démarrage tools-manager..."
curl -k -X POST -s "https://${PROXMOX_HOST}:8006/api2/json/nodes/${PROXMOX_NODE}/qemu/132/status/start" \
  -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" > /dev/null

echo ""
echo "✅ VMs créées et démarrées!"
echo "⏳ Attendez 2-3 minutes pour cloud-init, puis testez:"
echo "   cd Ansible && ansible all -m ping"
