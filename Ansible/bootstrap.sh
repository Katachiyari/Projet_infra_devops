#!/usr/bin/env bash
# bootstrap.sh - Initialize Ansible environment and install dependencies
# Bonnes pratiques: https://docs.ansible.com/ansible/latest/
#                   https://www.gnu.org/software/bash/manual/

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

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
    SUCCESS)
      echo -e "${GREEN}[${timestamp}]${NC} [SUCCESS] ${message}"
      ;;
  esac
}

_log_info() { _log "INFO" "$@"; }
_log_debug() { _log "DEBUG" "$@"; }
_log_warn() { _log "WARN" "$@"; }
_log_error() { _log "ERROR" "$@"; }
_log_success() { _log "SUCCESS" "$@"; }

# Check if command exists
_command_exists() {
  command -v "$1" &>/dev/null
}

# Check system prerequisites
_check_system_requirements() {
  _log_info "Checking system requirements..."
  
  local python_version
  local ansible_version
  
  # Check Python
  if ! _command_exists python3; then
    _log_error "Python 3 is required but not found"
    return 1
  fi
  
  python_version=$(python3 --version 2>&1 | awk '{print $2}')
  _log_info "Found Python $python_version"
  
  # Check pip
  if ! _command_exists pip3; then
    _log_error "pip3 is required. Install with: sudo apt-get install python3-pip"
    return 1
  fi
  
  _log_info "Found pip3: $(pip3 --version)"
  
  # Check git (useful for cloning roles)
  if ! _command_exists git; then
    _log_warn "git not found (optional but recommended)"
  else
    _log_debug "Found git: $(git --version)"
  fi
  
  return 0
}

# Install Ansible if not present
_install_ansible() {
  if _command_exists ansible; then
    ansible_version=$(ansible --version | head -n 1)
    _log_info "Ansible already installed: $ansible_version"
    return 0
  fi
  
  _log_info "Ansible not found. Installing..."
  
  if ! pip3 install --upgrade ansible; then
    _log_error "Failed to install Ansible via pip"
    return 1
  fi
  
  _log_success "Ansible installed successfully"
  ansible --version | head -n 1
}

# Install Python dependencies
_install_python_dependencies() {
  _log_info "Installing Python dependencies..."
  
  local requirements_files=(
    "requirements.txt"
    "requirements-dev.txt"
  )
  
  for req_file in "${requirements_files[@]}"; do
    if [[ -f "$req_file" ]]; then
      _log_info "Installing from $req_file"
      if ! pip3 install -r "$req_file"; then
        _log_error "Failed to install dependencies from $req_file"
        return 1
      fi
    fi
  done
  
  _log_success "Python dependencies installed"
}

# Install Ansible collections and roles
_install_ansible_dependencies() {
  _log_info "Installing Ansible collections and roles..."
  
  if [[ ! -f "requirements.yml" ]]; then
    _log_warn "requirements.yml not found, skipping"
    return 0
  fi
  
  _log_debug "Installing from requirements.yml"
  
  if ! ansible-galaxy install -r requirements.yml --force; then
    _log_error "Failed to install Ansible requirements"
    return 1
  fi
  
  _log_success "Ansible collections and roles installed"
}

# Validate Ansible installation
_validate_ansible() {
  _log_info "Validating Ansible installation..."
  
  # Check playbooks syntax
  local playbooks=(
    "playbooks/ping-test.yml"
    "playbooks/taiga.yml"
  )
  
  for playbook in "${playbooks[@]}"; do
    if [[ -f "$playbook" ]]; then
      _log_debug "Validating syntax: $playbook"
      if ! ansible-playbook --syntax-check "$playbook" >/dev/null 2>&1; then
        _log_error "Syntax error in playbook: $playbook"
        return 1
      fi
    fi
  done
  
  # Check inventory
  if ! ansible-inventory --list >/dev/null 2>&1; then
    _log_warn "Inventory validation failed (may be expected if Terraform not initialized)"
  fi
  
  _log_success "Ansible validation completed"
}

# Verify SSH configuration
_verify_ssh() {
  _log_info "Verifying SSH configuration..."
  
  # Check SSH keys
  if [[ ! -f "$HOME/.ssh/id_ed25519_common" ]] && [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
    _log_warn "No ED25519 SSH key found in ~/.ssh/"
    _log_info "Generate a key with: ssh-keygen -t ed25519 -C 'your_email@example.com'"
  else
    _log_debug "SSH keys found in ~/.ssh/"
  fi
  
  # Check terraform.tfvars SSH key
  if [[ -f "../terraform.tfvars" ]]; then
    local ssh_key_in_tfvars
    ssh_key_in_tfvars=$(grep -oP 'ssh_public_key\s*=\s*"\K[^"]+' ../terraform.tfvars || true)
    
    if [[ -n "$ssh_key_in_tfvars" ]]; then
      _log_debug "Found SSH public key in terraform.tfvars"
      # Extract just the key type and data for comparison
      local tfvars_key_type_data
      tfvars_key_type_data=$(echo "$ssh_key_in_tfvars" | awk '{print $1" "$2}')
      
      # Check if key exists locally
      for key_path in "$HOME/.ssh/id_ed25519_common" "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa"; do
        if [[ -f "$key_path" ]]; then
          local local_key_type_data
          local_key_type_data=$(ssh-keygen -y -f "$key_path" 2>/dev/null | awk '{print $1" "$2}' || true)
          
          if [[ "$local_key_type_data" == "$tfvars_key_type_data" ]]; then
            _log_success "SSH key matches terraform.tfvars: $key_path"
            return 0
          fi
        fi
      done
      
      _log_warn "SSH key in terraform.tfvars does not match any local key"
      _log_info "Consider using: ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_common -N ''"
    fi
  fi
}

# Show next steps
_show_next_steps() {
  cat <<EOF

${GREEN}✓ Bootstrap completed successfully!${NC}

${BLUE}Next steps:${NC}
  1. Verify Terraform configuration:
     ${YELLOW}cd .. && terraform init${NC}
     ${YELLOW}terraform plan${NC}
  
  2. Test connectivity to inventory hosts:
     ${YELLOW}./run-ping-test.sh${NC}
  
  3. Run Taiga deployment:
     ${YELLOW}./run-taiga-apply.sh${NC}
  
  4. For help on available commands:
     ${YELLOW}./run-ping-test.sh --help${NC}

${BLUE}Documentation:${NC}
  - Ansible: https://docs.ansible.com/
  - Terraform: https://www.terraform.io/docs/
  - SSH: man ssh-keygen

${BLUE}Troubleshooting:${NC}
  - Enable verbose output: LOG_LEVEL=DEBUG ./run-ping-test.sh
  - Check Ansible logs: tail -f /tmp/ansible.log
  - Verify SSH access: ssh -vvv ansible@<host>

EOF
}

# Main function
main() {
  _log_info "Starting Ansible environment bootstrap"
  _log_debug "Script directory: $SCRIPT_DIR"
  
  cd "$SCRIPT_DIR" || {
    _log_error "Failed to change to script directory"
    return 1
  }

  # Run all checks and installations
  _check_system_requirements || return 1
  _install_ansible || return 1
  _install_python_dependencies || return 1
  _install_ansible_dependencies || return 1
  _validate_ansible || return 1
  _verify_ssh
  
  _show_next_steps
  _log_success "Bootstrap completed successfully"
  return 0
}

# Error handling
trap '_log_error "Bootstrap failed"; exit 1' ERR

# Run main function
main "$@"
