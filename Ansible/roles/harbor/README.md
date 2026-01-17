# Ansible Role: harbor (Mission 2)

Déploie Harbor v2.11.1 en backend HTTP (port 80) en utilisant l'installateur offline officiel, avec `external_url` pointant vers le reverse proxy HTTPS `https://harbor.lab.local` et Trivy activé.

## Variables clés

Voir `defaults/main.yml` pour la liste complète. Exemples:

- `harbor_version`: version de Harbor (par défaut `v2.11.1`)
- `harbor_install_dir`: répertoire d'installation (par défaut `/opt/harbor`)
- `harbor_data_dir`: volume de données (par défaut `/data/harbor`)
- `harbor_hostname`: `harbor.lab.local`
- `harbor_external_url`: `https://harbor.lab.local`
- `harbor_admin_password`: à surcharger via inventory/vault

## Exécution

```bash
cd Ansible
ansible-playbook playbooks/harbor_portainer.yml -l harbor_portainer_hosts
```

## Validation

- Health local: `http://172.16.100.50:80/api/v2.0/health`
- Health via reverse proxy: `https://harbor.lab.local/api/v2.0/health`

Le rôle inclut ces checks dans `tasks/validation.yml`.
