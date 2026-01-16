#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

inventory_file="inventory/terraform.generated.yml"
if [[ ! -f "$inventory_file" ]]; then
  inventory_file="inventory/hosts.yml"
fi

extra_vars=()
private_key_args=()

# Convenance: si une clé standard existe sur la machine (ex: bastion/management),
# l'utiliser automatiquement pour éviter les erreurs "Permission denied (publickey)".
default_key="$HOME/.ssh/id_ed25519_common"
if [[ -f "$default_key" ]]; then
  private_key_args+=("--private-key" "$default_key")
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bastion)
      extra_vars+=("-e" "bastion_enabled=true")
      shift
      ;;
    --key)
      private_key_args=("--private-key" "${2:?missing key path}")
      shift 2
      ;;
    *)
      echo "Usage: $0 [--bastion] [--key /path/to/key]" >&2
      exit 2
      ;;
  esac
done

ansible-playbook -i "$inventory_file" "${private_key_args[@]}" playbooks/ping-test.yml -vv "${extra_vars[@]}"
