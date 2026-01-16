#!/usr/bin/env bash
set -euo pipefail

__ssh_agent_started=false

_ssh_kill_agent_if_started() {
  if [[ "$__ssh_agent_started" == "true" ]]; then
    ssh-agent -k >/dev/null 2>&1 || true
  fi
}

_terraform_public_key() {
  local tfvars_path="$1"
  if [[ ! -f "$tfvars_path" ]]; then
    return 0
  fi

  python3 - <<'PY' "$tfvars_path" || true
import re, sys
path = sys.argv[1]
try:
    data = open(path, 'r', encoding='utf-8').read()
except OSError:
    sys.exit(0)
m = re.search(r'^\s*ssh_public_key\s*=\s*"([^"]+)"\s*$', data, re.M)
if m:
    print(m.group(1).strip())
PY
}

_pubkey_type_and_data() {
  # prints: "type base64" or empty
  local pubkey="$1"
  if [[ -z "$pubkey" ]]; then
    return 0
  fi
  awk '{print $1" "$2}' <<<"$pubkey" 2>/dev/null || true
}

_private_key_pub_type_and_data() {
  local key_path="$1"
  ssh-keygen -y -f "$key_path" 2>/dev/null | awk '{print $1" "$2}' || true
}

_find_matching_private_key() {
  local desired_pubkey="$1"
  local desired="$(_pubkey_type_and_data "$desired_pubkey")"
  if [[ -z "$desired" ]]; then
    return 0
  fi

  local candidates=(
    "$HOME/.ssh/id_ed25519_common"
    "$HOME/.ssh/id_ed25519"
    "$HOME/.ssh/id_rsa"
  )

  local key
  for key in "${candidates[@]}"; do
    if [[ -f "$key" ]]; then
      local got
      got="$(_private_key_pub_type_and_data "$key")"
      if [[ -n "$got" && "$got" == "$desired" ]]; then
        echo "$key"
        return 0
      fi
    fi
  done
}

_inventory_hosts_and_ips() {
  local inventory_file="$1"

  ansible-inventory -i "$inventory_file" --list | python3 - <<'PY'
import json, sys
inv = json.load(sys.stdin)
hostvars = inv.get('_meta', {}).get('hostvars', {})
hosts = []
ips = []
for h, hv in hostvars.items():
    hosts.append(h)
    ip = hv.get('ansible_host')
    if ip:
        ips.append(ip)

def uniq(seq):
    out = []
    seen = set()
    for x in seq:
        if x not in seen:
            out.append(x)
            seen.add(x)
    return out

for h in uniq(hosts):
    print(h)
for ip in uniq(ips):
    print(ip)
PY
}

ssh_preflight() {
  # Usage: ssh_preflight <inventory_file> <array_var_name_for_private_key_args>
  local inventory_file="$1"
  local key_args_var="$2"

  # bash nameref
  local -n __key_args_ref="$key_args_var"

  trap _ssh_kill_agent_if_started EXIT

  # If user didn't provide --key, try to pick a key that matches terraform ssh_public_key.
  if [[ ${#__key_args_ref[@]} -eq 0 ]]; then
    local tfvars_path
    tfvars_path="$(cd "$(dirname "$0")/.." && pwd)/../terraform.tfvars"
    local desired_pubkey
    desired_pubkey="$(_terraform_public_key "$tfvars_path")"
    local matched
    matched="$(_find_matching_private_key "$desired_pubkey")"
    if [[ -n "$matched" ]]; then
      __key_args_ref=("--private-key" "$matched")
    fi
  fi

  # Clean known_hosts entries to avoid "REMOTE HOST IDENTIFICATION HAS CHANGED".
  local targets
  targets="$(_inventory_hosts_and_ips "$inventory_file")"
  while IFS= read -r t; do
    [[ -z "$t" ]] && continue
    ssh-keygen -R "$t" >/dev/null 2>&1 || true
  done <<<"$targets"

  # Ensure ssh-agent has the key loaded (provider scripts and some setups rely on it).
  if [[ ${#__key_args_ref[@]} -ge 2 && "${__key_args_ref[0]}" == "--private-key" ]]; then
    local key_path="${__key_args_ref[1]}"

    # Start agent if missing.
    if [[ -z "${SSH_AUTH_SOCK-}" ]]; then
      eval "$(ssh-agent -s)" >/dev/null
      __ssh_agent_started=true
    fi

    # Add key if not already present.
    if ! ssh-add -L 2>/dev/null | grep -q "$(ssh-keygen -y -f "$key_path" 2>/dev/null | awk '{print $2}' || true)"; then
      ssh-add "$key_path" >/dev/null 2>&1 || true
    fi
  fi

  # Fast validation (won't fail the whole run, but gives early signal).
  ansible -i "$inventory_file" "${__key_args_ref[@]}" all -m wait_for_connection -a "timeout=20" -o >/dev/null 2>&1 || true
}
