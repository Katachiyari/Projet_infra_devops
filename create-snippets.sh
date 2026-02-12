#!/usr/bin/env bash
# create-snippets.sh - Upload cloud-init snippets via Proxmox API REST

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

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

ENDPOINT="${PROXMOX_ENDPOINT:-$(read_tfvar proxmox_endpoint || true)}"
TOKEN="${PROXMOX_TOKEN:-$(read_tfvar proxmox_api_token || true)}"
DATASTORE="${PROXMOX_STORAGE:-$(read_tfvar datastore_snippets || true)}"
SSH_KEY="${SSH_PUBLIC_KEY:-$(read_tfvar ssh_public_key || true)}"
PROXMOX_NODE="${PROXMOX_NODE:-$(read_tfvar node_name || true)}"

ENDPOINT="${ENDPOINT%/}"

if [[ -z "${ENDPOINT}" || -z "${TOKEN}" || -z "${DATASTORE}" || -z "${SSH_KEY}" || -z "${PROXMOX_NODE}" ]]; then
  echo "❌ Variables manquantes. Renseigne terraform.tfvars ou exporte:"
  echo "   PROXMOX_ENDPOINT, PROXMOX_TOKEN, PROXMOX_STORAGE, SSH_PUBLIC_KEY, PROXMOX_NODE"
  exit 1
fi

echo "========================================="
echo "Upload snippets cloud-init"
echo "========================================="
echo ""

# Créer le répertoire tmp
SNIPPETS_DIR=$(mktemp -d)
trap "rm -rf $SNIPPETS_DIR" EXIT

# Définir les noeuds
declare -A NODES=(
  [bind9dns]="172.16.100.254"
  [git-lab]="172.16.100.40"
  [harbor]="172.16.100.50"
  [k3s-manager]="172.16.100.250"
  [k3s-worker-0]="172.16.100.251"
  [k3s-worker-1]="172.16.100.252"
  [reverse-proxy]="172.16.100.253"
  [tools-manager]="172.16.100.20"
)

# Générer les snippets
echo "Génération des fichiers cloud-init..."
for node in "${!NODES[@]}"; do
  echo "  $node"
  
  cat > "$SNIPPETS_DIR/user-data-$node.yaml" <<SNIPPET
#cloud-config
hostname: $node
manage_etc_hosts: true

users:
  - name: ansible
    groups: [adm, sudo]
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - $SSH_KEY

package_update: true
package_upgrade: true

packages:
  - qemu-guest-agent
  - sudo
  - python3
  - python3-pip

write_files:
  - path: /etc/ssh/sshd_config.d/99-ansible-hardening.conf
    permissions: "0644"
    content: |
      PasswordAuthentication no
      PubkeyAuthentication yes
      PermitRootLogin no

runcmd:
  - [ systemctl, enable, --now, qemu-guest-agent ]
  - [ systemctl, restart, ssh ]
  - [ chown, -R, 'ansible:ansible', '/home/ansible' ]
SNIPPET
done

# Upload les snippets
echo ""
echo "Upload vers Proxmox (API REST)..."
for file in "$SNIPPETS_DIR"/user-data-*.yaml; do
  filename=$(basename "$file")
  
  response=$(curl -k -s -X POST \
    -H "Authorization: PVEAPIToken=$TOKEN" \
    -F "filename=@$file" \
    "$ENDPOINT/api2/json/nodes/$PROXMOX_NODE/storage/$DATASTORE/upload" 2>&1)
  
  if echo "$response" | grep -q '"status":"ok"'; then
    echo "  ✓ $filename"
  else
    echo "  ? $filename"
  fi
done

echo ""
echo "✅ Snippets prêts"
