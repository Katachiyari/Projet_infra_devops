#!/usr/bin/env bash
# ssh-preflight.sh - Prépare l'environnement SSH pour Ansible
# Bonnes pratiques: https://www.gnu.org/software/bash/manual/
#                   https://www.openssh.com/manual.html

set -euo pipefail
IFS=$'\n\t'

# Logging utilities
LOG_LEVEL="${LOG_LEVEL:-INFO}"

_log() {
  local level="$1"
  shift
  local message="$*"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[${timestamp}] [${level}] [ssh-preflight] ${message}" >&2
}

_log_info() { [[ "$LOG_LEVEL" =~ ^(DEBUG|INFO)$ ]] && _log "INFO" "$@" || true; }
_log_debug() { [[ "$LOG_LEVEL" == "DEBUG" ]] && _log "DEBUG" "$@" || true; }
_log_warn() { _log "WARN" "$@"; }
_log_error() { _log "ERROR" "$@"; }

# State management
__ssh_agent_started=false

_ssh_kill_agent_if_started() {
  if [[ "$__ssh_agent_started" == "true" ]]; then
    _log_debug "Stopping SSH agent"
    ssh-agent -k >/dev/null 2>&1 || _log_warn "Failed to kill SSH agent"
  fi
}


# Extract SSH public key from Terraform variables
_terraform_public_key() {
  local tfvars_path="$1"
  
  if [[ ! -f "$tfvars_path" ]]; then
    _log_debug "Terraform vars file not found: $tfvars_path"
    return 0
  fi

  _log_debug "Extracting SSH public key from: $tfvars_path"
  python3 - <<'PY' "$tfvars_path" || true
import re
import sys

path = sys.argv[1]
try:
    with open(path, 'r', encoding='utf-8') as f:
        data = f.read()
except OSError as e:
    print(f"Error reading {path}: {e}", file=sys.stderr)
    sys.exit(0)

# Match: ssh_public_key = "..."
match = re.search(r'^\s*ssh_public_key\s*=\s*"([^"]+)"\s*$', data, re.MULTILINE)
if match:
    print(match.group(1).strip())
PY
}


# Extract type and base64 data from public key
_pubkey_type_and_data() {
  local pubkey="$1"
  
  if [[ -z "$pubkey" ]]; then
    return 0
  fi
  
  # Format: "ssh-ed25519 AAAAC3... comment"
  awk '{print $1" "$2}' <<<"$pubkey" 2>/dev/null || true
}


# Extract public key from private key and get type+data
_private_key_pub_type_and_data() {
  local key_path="$1"
  
  if [[ ! -f "$key_path" ]]; then
    _log_warn "Private key not found: $key_path"
    return 0
  fi
  
  ssh-keygen -y -f "$key_path" 2>/dev/null | awk '{print $1" "$2}' || {
    _log_warn "Failed to extract public key from: $key_path"
    return 0
  }
}


# Find matching private key for public key
_find_matching_private_key() {
  local desired_pubkey="$1"
  local desired
  
  desired="$(_pubkey_type_and_data "$desired_pubkey")"
  if [[ -z "$desired" ]]; then
    _log_debug "No desired public key provided"
    return 0
  fi

  _log_debug "Looking for private key matching: ${desired%% *}..."
  
  local candidates=(
    "$HOME/.ssh/id_ed25519_common"
    "$HOME/.ssh/id_ed25519"
    "$HOME/.ssh/id_rsa"
  )

  for key in "${candidates[@]}"; do
    if [[ -f "$key" ]]; then
      _log_debug "Checking candidate: $key"
      local got
      got="$(_private_key_pub_type_and_data "$key")"
      if [[ -n "$got" && "$got" == "$desired" ]]; then
        _log_info "Found matching private key: $key"
        echo "$key"
        return 0
      fi
    fi
  done
  
  _log_warn "No matching private key found for: ${desired%% *}..."
}


# Extract hostnames and IPs from inventory
_inventory_hosts_and_ips() {
  local inventory_file="$1"
  local inv_json
  
  _log_debug "Extracting hosts/IPs from inventory: $inventory_file"
  
  inv_json="$(ansible-inventory -i "$inventory_file" --list --output json 2>/dev/null || true)"
  if [[ -z "$inv_json" ]]; then
    _log_warn "Could not parse inventory"
    return 0
  fi

  python3 - <<'PY' "$inv_json" || true
import json
import sys

raw = sys.argv[1]
try:
    inv = json.loads(raw)
except json.JSONDecodeError as e:
    print(f"Error parsing inventory JSON: {e}", file=sys.stderr)
    sys.exit(0)

hostvars = inv.get('_meta', {}).get('hostvars', {})
hosts = []
ips = []

for hostname, hostvars_dict in hostvars.items():
    hosts.append(hostname)
    ansible_host = hostvars_dict.get('ansible_host')
    if ansible_host:
        ips.append(ansible_host)

def uniq(seq):
    """Remove duplicates while preserving order"""
    seen = set()
    result = []
    for item in seq:
        if item not in seen:
            seen.add(item)
            result.append(item)
    return result

for host in uniq(hosts):
    print(host)
for ip in uniq(ips):
    print(ip)
PY
}


# Main preflight function
ssh_preflight() {
  # Usage: ssh_preflight <inventory_file> <array_var_name_for_private_key_args>
  local inventory_file="$1"
  local key_args_var="${2:-}"
  
  if [[ -z "$key_args_var" ]]; then
    _log_error "Usage: ssh_preflight <inventory_file> <key_args_var>"
    return 1
  fi

  # Bash nameref - allow access to caller's array variable
  local -n __key_args_ref="$key_args_var"

  # Ensure cleanup on exit
  trap _ssh_kill_agent_if_started EXIT

  _log_info "Starting SSH preflight checks"
  _log_debug "Inventory file: $inventory_file"
  _log_debug "Key args variable: $key_args_var"

  # Auto-detect key if user didn't provide --key argument
  if [[ ${#__key_args_ref[@]} -eq 0 ]]; then
    _log_debug "No private key specified, auto-detecting..."
    
    local project_root
    # BASH_SOURCE[0] points to this file even when sourced
    project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    local tfvars_path="$project_root/terraform.tfvars"
    local desired_pubkey
    local matched
    
    desired_pubkey="$(_terraform_public_key "$tfvars_path")"
    matched="$(_find_matching_private_key "$desired_pubkey")"
    
    if [[ -n "$matched" ]]; then
      __key_args_ref=("--private-key" "$matched")
      _log_info "Auto-detected private key: $matched"
    else
      _log_warn "Could not auto-detect private key, proceeding without one"
    fi
  else
    _log_info "Using user-specified private key: ${__key_args_ref[1]}"
  fi

  # Clean known_hosts entries to avoid "REMOTE HOST IDENTIFICATION HAS CHANGED"
  _log_info "Cleaning known_hosts entries..."
  local targets
  targets="$(_inventory_hosts_and_ips "$inventory_file")"
  
  local target_count=0
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    ((target_count++))
    _log_debug "Removing from known_hosts: $target"
    ssh-keygen -R "$target" >/dev/null 2>&1 || _log_debug "Entry not in known_hosts: $target"
  done <<<"$targets"
  
  _log_info "Cleaned $target_count host entries from known_hosts"

  # Ensure ssh-agent has the key loaded
  if [[ ${#__key_args_ref[@]} -ge 2 && "${__key_args_ref[0]}" == "--private-key" ]]; then
    local key_path="${__key_args_ref[1]}"
    
    _log_info "Setting up SSH agent with key: $key_path"

    # Start agent if not already running
    if [[ -z "${SSH_AUTH_SOCK-}" ]]; then
      _log_info "Starting new SSH agent"
      eval "$(ssh-agent -s)" >/dev/null
      __ssh_agent_started=true
    else
      _log_debug "SSH agent already running at: $SSH_AUTH_SOCK"
    fi

    # Add key to agent if not already present
    local pubkey_data
    pubkey_data="$(ssh-keygen -y -f "$key_path" 2>/dev/null | awk '{print $2}' || true)"
    
    if [[ -n "$pubkey_data" ]]; then
      if ssh-add -L 2>/dev/null | grep -q "$pubkey_data"; then
        _log_debug "Private key already loaded in agent"
      else
        _log_info "Loading private key into agent: $key_path"
        # This may prompt for passphrase if key is encrypted
        if ! ssh-add "$key_path" 2>/dev/null; then
          _log_error "Failed to add key to SSH agent. Key may be encrypted or invalid."
          return 1
        fi
      fi
    else
      _log_error "Could not extract public key from private key: $key_path"
      return 1
    fi
  else
    _log_debug "No private key configured for agent"
  fi

  # Fast connectivity validation (non-blocking)
  _log_info "Validating SSH connectivity to inventory hosts..."
  if ansible -i "$inventory_file" "${__key_args_ref[@]}" all -m wait_for_connection -a "timeout=20" -o 2>&1 | grep -q "FAILED\|ERROR"; then
    _log_warn "Some hosts failed connectivity check (non-blocking)"
  else
    _log_info "All hosts passed connectivity check"
  fi

  _log_info "SSH preflight checks completed successfully"
}
# Only run if sourced with function call, not if sourced for definition
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _log_error "This script must be sourced, not executed directly"
  exit 1
fi