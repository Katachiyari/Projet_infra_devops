#!/usr/bin/env bash
# validate.sh - Comprehensive validation of Ansible setup and infrastructure
# Usage: ./validate.sh [--fix] [--verbose]

set -u +e  # Disable errexit temporarily, handle errors manually
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly GRAY='\033[0;37m'
readonly NC='\033[0m'

# Counters
PASSED=0
FAILED=0
WARNED=0

# Logging
_log() {
  local level="$1"
  shift
  local message="$*"
  
  case "$level" in
    PASS)
      echo -e "${GREEN}✓${NC} PASS: $message"
      ((PASSED++)) || true
      ;;
    FAIL)
      echo -e "${RED}✗${NC} FAIL: $message"
      ((FAILED++)) || true
      ;;
    WARN)
      echo -e "${YELLOW}⚠${NC} WARN: $message"
      ((WARNED++)) || true
      ;;
    INFO)
      echo -e "${BLUE}ℹ${NC} INFO: $message"
      ;;
    DEBUG)
      if [[ "$LOG_LEVEL" == "DEBUG" ]]; then
        echo -e "${GRAY}»${NC} DEBUG: $message" >&2
      fi
      ;;
  esac
}

_pass() { _log "PASS" "$@"; }
_fail() { _log "FAIL" "$@"; }
_warn() { _log "WARN" "$@"; }
_info() { _log "INFO" "$@"; }
_debug() { _log "DEBUG" "$@"; }

# Check command exists
_cmd_exists() {
  command -v "$1" &>/dev/null
}

# Print section header
_section() {
  echo ""
  echo -e "${BLUE}═══ $* ═══${NC}"
}

# Validation functions

_check_system_requirements() {
  _section "System Requirements"
  
  # Python 3
  if _cmd_exists python3; then
    local py_version
    py_version=$(python3 --version 2>&1 | awk '{print $2}')
    _pass "Python 3 found: $py_version"
  else
    _fail "Python 3 not found"
  fi
  
  # pip3
  if _cmd_exists pip3; then
    _pass "pip3 found"
  else
    _fail "pip3 not found"
  fi
  
  # git
  if _cmd_exists git; then
    _pass "git found: $(git --version)"
  else
    _warn "git not found (optional but recommended)"
  fi
  
  # ssh/ssh-keygen
  if _cmd_exists ssh && _cmd_exists ssh-keygen; then
    _pass "SSH tools found"
  else
    _fail "SSH tools not found"
  fi
}

_check_ansible_installation() {
  _section "Ansible Installation"
  
  # ansible-playbook
  if _cmd_exists ansible-playbook; then
    local version
    version=$(ansible-playbook --version | head -n 1)
    _pass "Ansible installed: $version"
  else
    _fail "Ansible not found - run: ./bootstrap.sh"
    return 1
  fi
  
  # ansible
  if _cmd_exists ansible; then
    _pass "ansible command available"
  else
    _fail "ansible command not found"
  fi
  
  # ansible-inventory
  if _cmd_exists ansible-inventory; then
    _pass "ansible-inventory available"
  else
    _fail "ansible-inventory not found"
  fi
  
  # ansible-galaxy
  if _cmd_exists ansible-galaxy; then
    _pass "ansible-galaxy available"
  else
    _fail "ansible-galaxy not found"
  fi
}

_check_ssh_configuration() {
  _section "SSH Configuration"
  
  # SSH keys
  local key_found=false
  for key in "$HOME/.ssh/id_ed25519_common" "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa"; do
    if [[ -f "$key" ]]; then
      _pass "SSH key found: $key"
      key_found=true
      
      # Check permissions
      local perms
      perms=$(stat -c %a "$key" 2>/dev/null || stat -f %A "$key" 2>/dev/null || echo "unknown")
      if [[ "$perms" == "600" ]] || [[ "$perms" =~ "-rw-------" ]]; then
        _pass "Key permissions correct: $perms"
      else
        _warn "Key permissions not optimal: $perms (should be 600)"
      fi
    fi
  done
  
  if [[ "$key_found" == false ]]; then
    _fail "No SSH keys found in ~/.ssh/"
  fi
  
  # Check terraform.tfvars
  if [[ -f "$SCRIPT_DIR/../terraform.tfvars" ]]; then
    _pass "terraform.tfvars found"
    
    local tf_ssh_key
    tf_ssh_key=$(grep -oP 'ssh_public_key\s*=\s*"\K[^"]+' "$SCRIPT_DIR/../terraform.tfvars" 2>/dev/null || true)
    
    if [[ -n "$tf_ssh_key" ]]; then
      _pass "SSH public key defined in terraform.tfvars"
      
      # Extract type and data
      local tf_key_type_data
      tf_key_type_data=$(echo "$tf_ssh_key" | awk '{print $1" "$2}')
      
      # Check for matching local key
      local found_match=false
      for key in "$HOME/.ssh/id_ed25519_common" "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa"; do
        if [[ -f "$key" ]]; then
          local local_key_type_data
          local_key_type_data=$(ssh-keygen -y -f "$key" 2>/dev/null | awk '{print $1" "$2}' || true)
          
          if [[ "$local_key_type_data" == "$tf_key_type_data" ]]; then
            _pass "SSH key matches terraform.tfvars: $key"
            found_match=true
            break
          fi
        fi
      done
      
      if [[ "$found_match" == false ]]; then
        _fail "SSH key in terraform.tfvars does not match any local private key"
        _info "Create matching key with: ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_common -N ''"
      fi
    else
      _fail "ssh_public_key not found in terraform.tfvars"
    fi
  else
    _warn "terraform.tfvars not found (may be expected if Terraform not initialized)"
  fi
}

_check_inventory() {
  _section "Ansible Inventory"
  
  cd "$SCRIPT_DIR" || return 1
  
  # terraform.generated.yml
  if [[ -f "inventory/terraform.generated.yml" ]]; then
    _pass "Terraform inventory exists: inventory/terraform.generated.yml"
    
    # Try to parse it
    if ansible-inventory -i inventory/terraform.generated.yml --list >/dev/null 2>&1; then
      local host_count
      host_count=$(ansible-inventory -i inventory/terraform.generated.yml --list --output json 2>/dev/null | \
                  python3 -c "import json, sys; data = json.load(sys.stdin); print(len(data.get('_meta', {}).get('hostvars', {})))" 2>/dev/null || echo "?")
      _pass "Terraform inventory valid, contains $host_count hosts"
    else
      _warn "Terraform inventory syntax invalid"
    fi
  else
    _warn "Terraform inventory not found (expected if Terraform not initialized)"
  fi
  
  # hosts.yml fallback
  if [[ -f "inventory/hosts.yml" ]]; then
    _pass "Fallback inventory exists: inventory/hosts.yml"
    
    if ansible-inventory -i inventory/hosts.yml --list >/dev/null 2>&1; then
      local host_count
      host_count=$(ansible-inventory -i inventory/hosts.yml --list --output json 2>/dev/null | \
                  python3 -c "import json, sys; data = json.load(sys.stdin); print(len(data.get('_meta', {}).get('hostvars', {})))" 2>/dev/null || echo "?")
      _pass "Fallback inventory valid, contains $host_count hosts"
    else
      _warn "Fallback inventory syntax invalid"
    fi
  else
    _fail "No fallback inventory found: inventory/hosts.yml"
  fi
}

_check_playbooks() {
  _section "Ansible Playbooks"
  
  cd "$SCRIPT_DIR" || return 1
  
  local playbooks=(
    "playbooks/ping-test.yml"
    "playbooks/taiga.yml"
    "playbooks/bind9-docker.yml"
  )
  
  for playbook in "${playbooks[@]}"; do
    if [[ -f "$playbook" ]]; then
      # Check syntax
      if ansible-playbook --syntax-check "$playbook" >/dev/null 2>&1; then
        _pass "Playbook syntax valid: $playbook"
      else
        _fail "Playbook syntax error: $playbook"
      fi
    else
      _warn "Playbook not found: $playbook"
    fi
  done
}

_check_roles() {
  _section "Ansible Roles"
  
  cd "$SCRIPT_DIR" || return 1
  
  local roles_dir="roles"
  
  if [[ ! -d "$roles_dir" ]]; then
    _fail "Roles directory not found: $roles_dir"
    return 1
  fi
  
  _pass "Roles directory exists"
  
  # Check for installed roles
  local role_count
  role_count=$(find "$roles_dir" -maxdepth 1 -type d ! -name roles | wc -l)
  
  if [[ $role_count -gt 0 ]]; then
    _pass "Found $role_count roles in $roles_dir"
    
    # List roles
    for role_dir in "$roles_dir"/*; do
      if [[ -d "$role_dir" ]]; then
        local role_name
        role_name=$(basename "$role_dir")
        
        # Check for meta/main.yml (indicates valid role)
        if [[ -f "$role_dir/meta/main.yml" ]]; then
          _pass "Role valid: $role_name (has meta/main.yml)"
        else
          _warn "Role may be incomplete: $role_name (missing meta/main.yml)"
        fi
      fi
    done
  else
    _warn "No roles found - run: ./bootstrap.sh"
  fi
}

_check_configuration() {
  _section "Configuration Files"
  
  cd "$SCRIPT_DIR" || return 1
  
  # ansible.cfg
  if [[ -f "ansible.cfg" ]]; then
    _pass "ansible.cfg exists"
    
    # Check for common options
    if grep -q "inventory" ansible.cfg; then
      _pass "ansible.cfg has inventory setting"
    else
      _warn "ansible.cfg missing inventory setting"
    fi
    
    if grep -q "roles_path" ansible.cfg; then
      _pass "ansible.cfg has roles_path setting"
    else
      _warn "ansible.cfg missing roles_path setting"
    fi
  else
    _fail "ansible.cfg not found"
  fi
  
  # requirements.yml
  if [[ -f "requirements.yml" ]]; then
    _pass "requirements.yml exists"
  else
    _warn "requirements.yml not found (optional)"
  fi
  
  # Group vars
  if [[ -d "inventory/group_vars" ]]; then
    _pass "group_vars directory exists"
    
    if [[ -f "inventory/group_vars/all.yml" ]]; then
      _pass "group_vars/all.yml found"
    else
      _warn "group_vars/all.yml not found"
    fi
  else
    _warn "group_vars directory not found"
  fi
}

_check_scripts() {
  _section "Script Files"
  
  cd "$SCRIPT_DIR" || return 1
  
  local scripts=(
    "run-ping-test.sh"
    "run-taiga-apply.sh"
    "run-taiga-check.sh"
    "bootstrap.sh"
    "lib/ssh-preflight.sh"
  )
  
  for script in "${scripts[@]}"; do
    if [[ -f "$script" ]]; then
      # Check execution permissions
      if [[ -x "$script" ]]; then
        _pass "Script executable: $script"
      else
        _warn "Script not executable: $script (chmod +x $script)"
      fi
      
      # Check bash syntax
      if bash -n "$script" 2>/dev/null; then
        _pass "Bash syntax valid: $script"
      else
        _fail "Bash syntax error: $script"
      fi
    else
      _fail "Script not found: $script"
    fi
  done
}

_check_connectivity() {
  _section "Connectivity Test (Optional)"
  
  cd "$SCRIPT_DIR" || return 1
  
  local inventory_file="inventory/terraform.generated.yml"
  if [[ ! -f "$inventory_file" ]]; then
    inventory_file="inventory/hosts.yml"
  fi
  
  if [[ ! -f "$inventory_file" ]]; then
    _warn "Skipping connectivity test - no inventory found"
    return 0
  fi
  
  _info "Testing connectivity to inventory hosts (timeout: 10s per host)..."
  
  if ansible -i "$inventory_file" all -m wait_for_connection -a "timeout=10" -o 2>&1 | grep -q "SUCCESS\|changed=0"; then
    _pass "Connectivity test passed"
  else
    _warn "Connectivity test failed or hosts unreachable (may be expected if Terraform not initialized)"
  fi
}

_print_summary() {
  echo ""
  echo -e "${BLUE}════════════════════════════════════${NC}"
  echo -e "${BLUE}Validation Summary${NC}"
  echo -e "${BLUE}════════════════════════════════════${NC}"
  
  echo -e "  ${GREEN}✓ Passed: $PASSED${NC}"
  echo -e "  ${YELLOW}⚠ Warned: $WARNED${NC}"
  echo -e "  ${RED}✗ Failed: $FAILED${NC}"
  
  echo ""
  
  if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All validations passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. ./bootstrap.sh          # Install dependencies"
    echo "  2. ./run-ping-test.sh      # Test connectivity"
    echo "  3. ./run-taiga-apply.sh    # Deploy infrastructure"
    return 0
  else
    echo -e "${RED}✗ Validation failed - please fix the errors above${NC}"
    return 1
  fi
}

# Main
main() {
  echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║  Ansible Setup Validation Script   ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --verbose)
        export LOG_LEVEL="DEBUG"
        shift
        ;;
      *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
  done
  
  # Run validations
  _check_system_requirements
  _check_ansible_installation
  _check_ssh_configuration
  _check_inventory
  _check_playbooks
  _check_roles
  _check_configuration
  _check_scripts
  _check_connectivity
  
  # Summary
  _print_summary
}

main "$@"
