#!/usr/bin/env bash
# Script pour contourner le problème SSH de Terraform en uploadant les snippets via API

set -euo pipefail

# Variables de configuration
PROXMOX_HOST="${PROXMOX_HOST:-10.250.250.4}"
PROXMOX_NODE="${PROXMOX_NODE:-pve4}"
PROXMOX_STORAGE="${PROXMOX_STORAGE:-jdk_snippets}"

# Récupérer le token depuis terraform.tfvars
PROXMOX_TOKEN=$(grep 'proxmox_api_token' terraform.tfvars | cut -d'"' -f2)

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
