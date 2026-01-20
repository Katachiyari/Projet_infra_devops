# Mission 4: Taiga & EdgeDoc

This documentation covers the deployment, configuration, and integration of Taiga (project management) and EdgeDoc (collaborative editor) in the DevSecOps lab stack.

## Objectives
- Deploy Taiga and EdgeDoc using Ansible roles and Docker
- Integrate with Nginx reverse-proxy, Bind9 DNS, and monitoring
- Enforce security (Trivy, UFW, secure headers)
- Ensure idempotence and SSOT compliance

## Structure
- `roles/taiga/`: Ansible role for Taiga
- `roles/edgedoc/`: Ansible role for EdgeDoc
- `playbooks/`: Playbooks for deployment and validation

## References
- [Official Taiga Docker](https://github.com/taigaio/taiga-docker)
- [EdgeDoc Docker](https://github.com/edgedoc/edgedoc)

---

## Authors
DevSecOps Lab – Mission 4
