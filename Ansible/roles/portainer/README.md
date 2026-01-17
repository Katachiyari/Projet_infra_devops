# Ansible Role: portainer (Mission 2)

Déploie Portainer CE v2.19.4 en backend HTTP sur le port 9000, avec accès restreint au reverse proxy (172.16.100.50).

## Variables clés

Voir `defaults/main.yml` pour la liste complète. Exemples:

- `portainer_install_dir`: `/data/portainer`
- `portainer_data_dir`: `/data/portainer/data`
- `portainer_image`: `portainer/portainer-ce:2.19.4`
- `portainer_http_port`: `9000`

## Exécution

```bash
cd Ansible
ansible-playbook playbooks/harbor_portainer.yml -l harbor_portainer_hosts
```

## Validation

- Health local: `http://172.16.100.2:9000`

Le rôle inclut ce check dans `tasks/validation.yml`.
