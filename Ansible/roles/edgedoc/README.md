# Ansible Role: EdgeDoc (BookStack)

This role deploys and configures BookStack using Docker, while keeping the existing EdgeDoc exposure contract (`edgedoc.lab.local` on backend port `8080`) to avoid DNS and reverse-proxy changes.

## Structure
- `tasks/`: Main tasks for installation, configuration, and deployment
- `templates/`: Jinja2 templates for configuration files
- `defaults/`: Default variables
- `handlers/`: Handlers for service reload/restart
- `meta/`: Role metadata

## Requirements
- Docker/Podman
- Nginx reverse-proxy
- Bind9 DNS
- Monitoring integration
- Security: UFW, Trivy, headers
- Vault secrets in `group_vars/all/edgedoc.vault.yml`

## Usage
Include this role in your playbook:
```yaml
- hosts: edgedoc
  roles:
    - edgedoc
```

## Author
Mission 4 – DevSecOps Lab
