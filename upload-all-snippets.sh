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
PROXMOX_STORAGE="${PROXMOX_STORAGE:-$(read_tfvar datastore_snippets || true)}"
PROXMOX_TOKEN="${PROXMOX_TOKEN:-$(read_tfvar proxmox_api_token || true)}"

if [[ -z "${PROXMOX_HOST}" || -z "${PROXMOX_NODE}" || -z "${PROXMOX_STORAGE}" || -z "${PROXMOX_TOKEN}" ]]; then
    echo "❌ Variables manquantes. Renseigne terraform.tfvars ou exporte PROXMOX_HOST, PROXMOX_NODE, PROXMOX_STORAGE, PROXMOX_TOKEN."
    exit 1
fi

echo "📤 Upload de tous les snippets cloud-init..."

for vm in bind9dns tools-manager reverse-proxy harbor k3s-manager git-lab k3s-worker-0 k3s-worker-1; do
    if [ -f "generated-cloud-init/user-data-${vm}.yaml" ]; then
        echo "  ↑ ${vm}..."
        curl -k -X POST -s \
            "https://${PROXMOX_HOST}:8006/api2/json/nodes/${PROXMOX_NODE}/storage/${PROXMOX_STORAGE}/upload" \
            -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" \
            -F "content=snippets" \
            -F "filename=@generated-cloud-init/user-data-${vm}.yaml;filename=user-data-${vm}.yaml" \
            --output /dev/null && echo "    ✓" || echo "    ✗ (peut-être déjà existant)"
    fi
done

echo "✅ Snippets uploadés !"
