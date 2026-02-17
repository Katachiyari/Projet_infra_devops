# Docs - Référence Opérationnelle du Projet DevSecOps

> Dernière mise à jour : 13 février 2026.
>
> État validé : accès Ansible direct depuis le poste local, reverse-proxy aligné sur GitLab/Registry/Taiga/EdgeDoc.

## 1. Vue d'ensemble

Ce dossier centralise la documentation fonctionnelle et opérationnelle du lab :

- Provisionnement VM via Terraform + Proxmox.
- Bootstrap système via cloud-init.
- Déploiement idempotent via Ansible.
- Exposition TLS via Nginx reverse-proxy + PKI locale.

## 2. État actuel de la stack

Services exposés derrière le reverse-proxy (`172.16.100.253`) :

- Harbor (`harbor.lab.local`) -> `172.16.100.50:80`
- Portainer (`portainer.lab.local`) -> `172.16.100.50:9000`
- GitLab (`git-lab.lab.local`) -> `172.16.100.40:8181`
- Registry (`registry.gitlab.lab.local`) -> `172.16.100.40:5050`
- Taiga (`taiga.lab.local`) -> `172.16.100.20:8080`
- EdgeDoc (`edgedoc.lab.local`) -> `172.16.100.20:8080`

## 3. SSOT à respecter

- SSH : `terraform.tfvars -> ssh_public_key` est la source de vérité.
- Inventaire Ansible :
  - primaire : `Ansible/inventory/terraform.generated.yml` (généré par Terraform),
  - fallback : `Ansible/inventory/hosts.yml`.
- TLS interne : certificats distribués depuis la CA locale.

## 4. Workflow court (runbook)

```bash
# 1) Infra
terraform init
terraform plan -input=false
terraform apply -input=false

# 2) Config Ansible
cd Ansible
./bootstrap.sh
./validate.sh
./run-ping-test.sh

# 3) Test direct (si besoin)
ansible -i inventory/hosts.yml all -m ping -u ansible \
  --private-key "$HOME/.ssh/id_ed25519_admin1_nopass" --ask-vault-pass
```

## 5. Dossier docs à lire en priorité

- `Docs/docs/README.md` : sommaire pédagogique.
- `Docs/stackGlobal/SSOT-DevSecOps-stack.md` : architecture et flux SSOT.
- `Docs/NGINX_reverse_proxy/NGINX_reverse_proxy.md` : design reverse-proxy.
- `Docs/gitLab/gitLab.md` : cadrage GitLab.
- `Docs/Harbor/Harbor.md` : Harbor + runbook test "PC client" (build/tag/push + manifest/pull).
- `Docs/taiga_edgedoc/README.md` : intégration Taiga/EdgeDoc.
- `Docs/stackMonitoring/stackMonitoring.md` : monitoring.
- `Docs/bind9/bind9.md` : DNS interne.

## 6. Notes de maintenance doc

- Toute modification d'IP, hostname, port ou clé SSH doit être reportée dans cette doc le même jour.
- Éviter les duplications : préférer une page de référence et des liens depuis les autres pages.
