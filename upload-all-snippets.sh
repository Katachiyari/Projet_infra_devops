#!/usr/bin/env bash
set -euo pipefail

PROXMOX_HOST="10.250.250.4"
PROXMOX_NODE="pve4"
PROXMOX_TOKEN=$(grep 'proxmox_api_token' terraform.tfvars | cut -d'"' -f2)

echo "📤 Upload de tous les snippets cloud-init..."

for vm in bind9dns tools-manager reverse-proxy harbor k3s-manager git-lab k3s-worker-0 k3s-worker-1; do
    if [ -f "generated-cloud-init/user-data-${vm}.yaml" ]; then
        echo "  ↑ ${vm}..."
        curl -k -X POST -s \
            "https://${PROXMOX_HOST}:8006/api2/json/nodes/${PROXMOX_NODE}/storage/jdk_snippets/upload" \
            -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" \
            -F "content=snippets" \
            -F "filename=@generated-cloud-init/user-data-${vm}.yaml;filename=user-data-${vm}.yaml" \
            --output /dev/null && echo "    ✓" || echo "    ✗ (peut-être déjà existant)"
    fi
done

echo "✅ Snippets uploadés !"
