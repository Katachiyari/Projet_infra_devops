#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Usage:
#   ./run-taiga-check.sh            # si tu lances depuis le bastion (ou accès direct au réseau)
#   ./run-taiga-check.sh --bastion  # si tu lances depuis ton PC et dois passer par le bastion

extra_vars=()
if [[ "${1-}" == "--bastion" ]]; then
	extra_vars+=("-e" "bastion_enabled=true")
fi

ansible -i inventory/hosts.yml taiga_hosts -m ping -vv "${extra_vars[@]}"
ansible-playbook -i inventory/hosts.yml playbooks/taiga.yml --check -vv "${extra_vars[@]}"
