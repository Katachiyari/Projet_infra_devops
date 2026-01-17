bind9_docker
============

Rôle Ansible simple et idempotent pour déployer un serveur DNS Bind9 dans un
conteneur Docker sur un hôte Debian/Ubuntu.

Le rôle :

- installe Docker (`docker.io`) si nécessaire,
- prépare des répertoires persistants pour la configuration et le cache,
- génère une configuration Bind9 récursive + forwarders, autoritaire optionnelle,
- crée et démarre un conteneur Docker Bind9 en mode `host` réseau,
- ouvre le port 53/UDP et 53/TCP via UFW (optionnel),
- effectue un healthcheck `named-checkconf` et `dig`.

Requirements
------------

- Ansible >= 2.13
- Collection `community.docker` (voir `Ansible/requirements.yml`)
- Hôte cible Debian/Ubuntu avec accès `become: true`

Role Variables
--------------

Variables principales (surchargables dans `inventory/host_vars/bind9dns.yml`) :

- `bind9_docker_image` (str) : image Docker, par défaut `internetsystemsconsortium/bind9`
- `bind9_docker_tag` (str) : tag d'image (par défaut `9.18`)
- `bind9_docker_container_name` (str) : nom du conteneur (`bind9`)
- `bind9_docker_config_dir` (str) : répertoire de configuration sur l'hôte (`/srv/bind9/etc`)
- `bind9_docker_cache_dir` (str) : répertoire de cache sur l'hôte (`/srv/bind9/cache`)
- `bind9_port` (int) : port d'écoute DNS (53)
- `bind9_listen_v4` (liste) : IP d'écoute dans le conteneur (par défaut `172.16.100.254`)
- `bind9_listen_v6` (liste) : adresses v6 d'écoute (vide par défaut)
- `bind9_recursor` (bool) : activer la récursion
- `bind9_forward` (bool) : activer les forwarders
- `bind9_forward_servers` (liste) : serveurs en forward (8.8.8.8, 1.1.1.1 par défaut)
- `bind9_our_networks` (liste) : réseaux autorisés à interroger/faire de la récursion
- `bind9_authoritative` (bool) : activer des zones internes dynamiques
- `bind9_zones_dynamic` (liste de dicts) : définition de zones internes
- `bind9_docker_user` (str) : utilisateur dans le conteneur (par défaut `bind`)
- `bind9_manage_ufw` (bool) : gérer les règles UFW (`true` par défaut)

Variables de zones (exemple) : voir `inventory/host_vars/bind9dns.yml`.

Dependencies
------------

- Aucune autre dépendance de rôle. La collection `community.docker` est requise.

Example Playbook
----------------

Exemple de playbook (déjà présent) : `Ansible/playbooks/bind9-container.yml` :

```yaml
---
- name: Déployer Bind9 en conteneur Docker
  hosts: bind9_hosts
  become: true
  roles:
    - bind9_docker
```

Commandes utiles
----------------

- Exécution du playbook :

  ```bash
  ansible-playbook -i inventory/hosts.yml playbooks/bind9-container.yml --limit bind9
  ```

- Vérification de la résolution :

  ```bash
  dig @172.16.100.254 isc.org +short
  ```

License
-------

MIT-0

Author Information
------------------

Projet infra devops

