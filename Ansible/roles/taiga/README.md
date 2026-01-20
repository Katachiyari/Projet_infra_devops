# Ansible Role: Taiga

This role deploys and configures the Taiga project management platform using Docker, following DevSecOps, SSOT, and automation best practices.

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

## Usage
Include this role in your playbook:
```yaml
- hosts: taiga
  roles:
    - taiga
```

## Author
Mission 4 – DevSecOps Lab
