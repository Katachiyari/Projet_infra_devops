#!/usr/bin/env bash
# create-snippets.sh - Upload cloud-init snippets via Proxmox API REST

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Charger les valeurs manuellement
ENDPOINT="https://10.250.250.4:8006"
TOKEN="terraform-jdk@pve4!jdk-token=c4a17231-fab8-4cd6-801e-bc0dd0251b1c"
DATASTORE="jdk_snippets"
SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE30vg7EchnxPkkVvAnbi0Ey55NGWRiUNE1ClsUvCj7d vm-common-key"

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
    "$ENDPOINT/api2/json/nodes/pve4/storage/$DATASTORE/upload" 2>&1)
  
  if echo "$response" | grep -q '"status":"ok"'; then
    echo "  ✓ $filename"
  else
    echo "  ? $filename"
  fi
done

echo ""
echo "✅ Snippets prêts"
