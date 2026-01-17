#!/usr/bin/env bash
# deploy-vms.sh - Approche simple et officielle
# Étapes: (1) Uploader les snippets cloud-init via API
#         (2) Terraform init/validate/plan/apply
#         (3) Attendre cloud-init et tester Ansible

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}1️⃣  Étape: Upload snippets cloud-init${NC}"
echo -e "${BLUE}=========================================${NC}"

if [[ -f create-snippets.sh ]]; then
    bash create-snippets.sh
else
    echo -e "${RED}❌ create-snippets.sh non trouvé${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}2️⃣  Étape: Terraform Init${NC}"
echo -e "${BLUE}=========================================${NC}"
terraform init

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}3️⃣  Étape: Terraform Validate${NC}"
echo -e "${BLUE}=========================================${NC}"
terraform validate

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}4️⃣  Étape: Terraform Plan${NC}"
echo -e "${BLUE}=========================================${NC}"
terraform plan -out=tfplan

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}5️⃣  Étape: Terraform Apply${NC}"
echo -e "${BLUE}=========================================${NC}"

read -p "Continuer avec terraform apply? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}❌ Annulé${NC}"
    exit 1
fi

terraform apply tfplan

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}✅ VMs créées avec Terraform${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "Attendez ${BLUE}3-4 minutes${NC} pour que cloud-init finisse de démarrer..."
echo ""
echo -e "Puis testez avec:"
echo -e "${BLUE}  cd Ansible && ansible all -m ping${NC}"

