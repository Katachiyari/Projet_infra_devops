#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

inventory_file="inventory/terraform.generated.yml"
if [[ ! -f "$inventory_file" ]]; then
	inventory_file="inventory/hosts.yml"
fi

# Usage:
#   ./run-taiga-check.sh            # si tu lances depuis le bastion (ou accès direct au réseau)
#   ./run-taiga-check.sh --bastion  # si tu lances depuis ton PC et dois passer par le bastion

extra_vars=()
private_key_args=()

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
			echo "Option inconnue: $1" >&2
			exit 2
			;;
	esac
done

ansible -i "$inventory_file" "${private_key_args[@]}" taiga_hosts -m wait_for_connection -a "timeout=300" -vv "${extra_vars[@]}"
ansible -i "$inventory_file" "${private_key_args[@]}" taiga_hosts -m ping -vv "${extra_vars[@]}"
ansible-playbook -i "$inventory_file" "${private_key_args[@]}" playbooks/taiga.yml --check -vv "${extra_vars[@]}"
