# Projet Infra (Terraform + Ansible + cloud-init)

## Objectif
- **Terraform** crée les VMs sur Proxmox et injecte l’accès SSH (utilisateur `ansible` + clé publique).
- **cloud-init** fait le bootstrap OS (qemu-guest-agent, durcissement SSH, sudoers).
- **Ansible** configure les services (Taiga, Bind9, reverse-proxy, Harbor/Portainer, monitoring, …) de façon idempotente.

## Connexion 100% automatisée (principe)
1. **Une seule source de vérité pour l’accès SSH** : la clé publique est fournie à Terraform (`ssh_public_key`).
2. Terraform configure l’utilisateur `ansible` et sa clé via `initialization.user_account`.
3. cloud-init s’occupe du système (packages + sshd + sudoers), sans re-définir l’utilisateur.
4. Terraform génère automatiquement l’inventaire Ansible dans `Ansible/inventory/terraform.generated.yml`.

## Fichiers sensibles
- Ne versionne pas les secrets : `terraform.tfvars` et les fichiers `*.tfvars` sont ignorés par Git.
- Ne versionne pas le state : `*.tfstate*` est ignoré (utilise idéalement un backend distant).

## Démarrage (référence)
1. Crée un fichier `terraform.tfvars` (non versionné) à partir de `terraform.tfvars.example`.
2. `terraform init`
3. `terraform plan -input=false` (échoue si une variable manque)
4. `terraform apply -input=false`
5. Dans `Ansible/` : `./bootstrap.sh` puis `./run-taiga-apply.sh` (ou `--bastion`).

Astuce: tu peux aussi faire `terraform plan -var-file=terraform.tfvars -input=false`.

## Vérifier la connectivité Ansible (ping/pong)
Dans `Ansible/`:
- `./run-ping-test.sh` (réseau direct)
- `./run-ping-test.sh --bastion` (via ProxyJump)
- `./run-ping-test.sh --key ~/.ssh/id_ed25519_common`

## Documentation SSOT de la stack

Une vue d’ensemble détaillée de l’architecture DevSecOps (PKI locale, Nginx reverse-proxy HTTPS, Harbor/Portainer, stack monitoring, DNS Bind9, flux réseau) est disponible dans :

- [Docs/stackGlobal/SSOT-DevSecOps-stack.md](Docs/stackGlobal/SSOT-DevSecOps-stack.md)

URLs principales (via le reverse-proxy et/ou directement) une fois la stack déployée et la CA importée dans le navigateur :

- Harbor : `https://harbor.lab.local/`
- Portainer : `https://portainer.lab.local/`
- Prometheus : `http://prometheus.lab.local:9090/`
- Grafana : `http://grafana.lab.local:3000/`
- Alertmanager : `http://alertmanager.lab.local:9093/`
