#!/usr/bin/env bash
# Script pour contourner le problème SSH de Terraform en uploadant les snippets via API

set -euo pipefail

# Variables de configuration
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

echo "📤 Upload des snippets cloud-init via l'API Proxmox..."

# Fonction pour uploader un snippet
upload_snippet() {
    local name=$1
    local file=$2
    
    echo "  ↑ Uploading ${name}..."
    
    curl -k -X POST \
        "https://${PROXMOX_HOST}:8006/api2/json/nodes/${PROXMOX_NODE}/storage/${PROXMOX_STORAGE}/upload" \
        -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" \
        -F "content=snippets" \
        -F "filename=@${file};filename=user-data-${name}.yaml" \
        --silent --output /dev/null && echo "    ✓ ${name} uploaded" || echo "    ✗ ${name} failed"
}

# Upload les deux snippets
upload_snippet "bind9dns" "generated-cloud-init/user-data-bind9dns.yaml"
upload_snippet "tools-manager" "generated-cloud-init/user-data-tools-manager.yaml"

echo ""
echo "✅ Snippets uploadés! Vous pouvez maintenant créer les VMs manuellement via l'interface Proxmox"
echo ""
echo "Ou si vous préférez utiliser Terraform, exécutez:"
echo "  terraform apply -target=proxmox_virtual_environment_vm.vm[\\\"bind9dns\\\"] -target=proxmox_virtual_environment_vm.vm[\\\"tools-manager\\\"] -auto-approve"
