#!/usr/bin/env bash
# run-ping-test.sh - Test SSH connectivity to all Ansible inventory hosts
# Usage: ./run-ping-test.sh [--bastion] [--key /path/to/key] [--verbose]
#
# Bonnes pratiques:
#   - https://docs.ansible.com/
#   - https://www.gnu.org/software/bash/manual/

set -euo pipefail
IFS=$'\n\t'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
_log() {
  local level="$1"
  shift
  local message="$*"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  
  case "$level" in
    INFO)
      echo -e "${BLUE}[${timestamp}]${NC} [INFO] ${message}"
      ;;
    DEBUG)
      if [[ "$LOG_LEVEL" == "DEBUG" ]]; then
        echo -e "${BLUE}[${timestamp}]${NC} [DEBUG] ${message}" >&2
      fi
      ;;
    WARN)
      echo -e "${YELLOW}[${timestamp}]${NC} [WARN] ${message}" >&2
      ;;
    ERROR)
      echo -e "${RED}[${timestamp}]${NC} [ERROR] ${message}" >&2
      ;;
  esac
}

_log_info() { _log "INFO" "$@"; }
_log_debug() { _log "DEBUG" "$@"; }
_log_warn() { _log "WARN" "$@"; }
_log_error() { _log "ERROR" "$@"; }

# Check prerequisites
_check_prerequisites() {
  _log_info "Checking prerequisites..."
  
  local missing=0
  
  for cmd in ansible-playbook ansible-inventory ssh-keygen ssh-add ssh-agent; do
    if ! command -v "$cmd" &>/dev/null; then
      _log_error "Required command not found: $cmd"
      ((missing++))
    else
      _log_debug "Found: $cmd"
    fi
  done
  
  if [[ $missing -gt 0 ]]; then
    _log_error "Missing $missing required commands. Please install Ansible and OpenSSH."
    return 1
  fi
  
  _log_info "All prerequisites met"
  return 0
}

# Validate inventory file
_validate_inventory() {
  local inventory_file="$1"
  
  if [[ ! -f "$inventory_file" ]]; then
    _log_error "Inventory file not found: $inventory_file"
    return 1
  fi
  
  _log_debug "Validating inventory: $inventory_file"
  if ! ansible-inventory -i "$inventory_file" --list >/dev/null 2>&1; then
    _log_error "Invalid inventory file: $inventory_file"
    return 1
  fi
  
  local host_count
  host_count="$(ansible-inventory -i "$inventory_file" --list --output json 2>/dev/null | \
                python3 -c "import json, sys; data = json.load(sys.stdin); print(len(data.get('_meta', {}).get('hostvars', {})))")"
  
  _log_info "Inventory contains $host_count hosts"
  return 0
}

# Usage function
_usage() {
  cat <<EOF
${BLUE}Usage:${NC} $SCRIPT_NAME [OPTIONS]

${BLUE}Options:${NC}
  --bastion              Enable bastion/jump host mode (ProxyJump)
  --key PATH             Path to private SSH key (auto-detected by default)
  --verbose              Enable verbose output (sets LOG_LEVEL=DEBUG)
  --help                 Show this help message

${BLUE}Environment Variables:${NC}
  LOG_LEVEL              Set to DEBUG for verbose output (default: INFO)

${BLUE}Examples:${NC}
  # Basic ping test
  $SCRIPT_NAME

  # Through bastion host
  $SCRIPT_NAME --bastion

  # With specific key and verbose output
  $SCRIPT_NAME --key ~/.ssh/id_ed25519_common --verbose

EOF
}

# Parse command line arguments
_parse_arguments() {
  local extra_vars=()
  local private_key_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --bastion)
        _log_debug "Enabling bastion mode"
        extra_vars+=("-e" "bastion_enabled=true")
        shift
        ;;
      --key)
        if [[ -z "${2:-}" ]]; then
          _log_error "Option --key requires an argument"
          return 1
        fi
        if [[ ! -f "$2" ]]; then
          _log_error "Private key file not found: $2"
          return 1
        fi
        _log_info "Using specified private key: $2"
        private_key_args=("--private-key" "$2")
        shift 2
        ;;
      --verbose)
        _log_debug "Enabling verbose output"
        export LOG_LEVEL="DEBUG"
        shift
        ;;
      --help|-h)
        _usage
        exit 0
        ;;
      *)
        _log_error "Unknown option: $1"
        _usage
        return 1
        ;;
    esac
  done

  # Export arrays for use in subshells
  export EXTRA_VARS_ARRAY="${extra_vars[@]:-}"
  export PRIVATE_KEY_ARGS_ARRAY="${private_key_args[@]:-}"
}

# Main function
main() {
  _log_info "Starting Ansible connectivity test"
  
  # Check prerequisites
  if ! _check_prerequisites; then
    _log_error "Prerequisites check failed"
    return 1
  fi

  # Change to script directory
  cd "$SCRIPT_DIR" || {
    _log_error "Failed to change to script directory: $SCRIPT_DIR"
    return 1
  }
  _log_debug "Working directory: $(pwd)"

  # Source the preflight script
  if [[ ! -f "lib/ssh-preflight.sh" ]]; then
    _log_error "SSH preflight script not found: lib/ssh-preflight.sh"
    return 1
  fi
  _log_debug "Sourcing SSH preflight script"
  # shellcheck disable=SC1091
  source "lib/ssh-preflight.sh"

  # Select inventory file (prefer Terraform-generated)
  local inventory_file="inventory/terraform.generated.yml"
  if [[ ! -f "$inventory_file" ]]; then
    _log_debug "Terraform inventory not found, using fallback: inventory/hosts.yml"
    inventory_file="inventory/hosts.yml"
  fi
  _log_info "Using inventory: $inventory_file"

  # Validate inventory
  if ! _validate_inventory "$inventory_file"; then
    return 1
  fi

  # Declare arrays for ssh_preflight to populate
  local -a private_key_args=()
  local -a extra_vars=()

  # Parse user arguments (this populates EXTRA_VARS_ARRAY and PRIVATE_KEY_ARGS_ARRAY)
  if ! _parse_arguments "$@"; then
    return 1
  fi

  # Restore arrays from exports
  if [[ -n "${PRIVATE_KEY_ARGS_ARRAY:-}" ]]; then
    mapfile -t private_key_args <<<"${PRIVATE_KEY_ARGS_ARRAY:-}"
  fi
  if [[ -n "${EXTRA_VARS_ARRAY:-}" ]]; then
    mapfile -t extra_vars <<<"${EXTRA_VARS_ARRAY:-}"
  fi

  _log_debug "Private key args: ${private_key_args[*]:-none}"
  _log_debug "Extra vars: ${extra_vars[*]:-none}"

  # Run SSH preflight checks
  _log_info "Running SSH preflight checks..."
  if ! ssh_preflight "$inventory_file" private_key_args; then
    _log_error "SSH preflight checks failed"
    return 1
  fi

  # Run the actual playbook
  _log_info "Running Ansible playbook: playbooks/ping-test.yml"
  _log_debug "Command: ansible-playbook -i $inventory_file ${private_key_args[*]:-} playbooks/ping-test.yml ${extra_vars[*]:-}"
  
  if ! ansible-playbook \
    -i "$inventory_file" \
    "${private_key_args[@]}" \
    playbooks/ping-test.yml \
    -vv \
    "${extra_vars[@]}"; then
    _log_error "Playbook execution failed"
    return 1
  fi

  _log_info "${GREEN}Connectivity test completed successfully${NC}"
  return 0
}

# Handle errors
trap 'exit 1' ERR

# Run main function
main "$@"
