#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Installe les rôles/collections requis
ansible-galaxy install -r requirements.yml

# Note: si tu utilises Ansible Vault, exporte ANSIBLE_VAULT_PASSWORD_FILE ou utilise --ask-vault-pass.
