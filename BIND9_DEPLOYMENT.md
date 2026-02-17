# Bind9 deployment (Runbook)

Ce fichier est conserve a la racine comme point d'entree "runbook".

Source de verite (SSOT) et documentation a jour :
- `Docs/bind9/bind9.md`

## TL;DR (operational)

Zones et records :
- `Ansible/inventory/host_vars/bind9dns.yml`

Deploiement Bind9 (choisir un mode) :

```bash
cd Ansible
# Mode conteneur (role bind9_docker)
ansible-playbook -i inventory/hosts.yml playbooks/bind9-container.yml --limit bind9_hosts
```

Ou :

```bash
cd Ansible
# Mode VM (role systemli.bind9)
ansible-playbook -i inventory/hosts.yml playbooks/bind9-docker.yml --limit bind9_hosts
```

Verification :

```bash
dig +short @172.16.100.254 harbor.lab.local
dig +short @172.16.100.254 git-lab.lab.local
dig +short @172.16.100.254 registry.gitlab.lab.local
```

Attendu : `172.16.100.253` pour les services exposes via reverse-proxy.

