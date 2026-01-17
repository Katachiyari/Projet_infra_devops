# Stack de monitoring (Prometheus / Grafana / Alertmanager)

## 1. Objectif et périmètre

Cette documentation décrit le déploiement complet de la stack de monitoring sur la VM `monitoring-stack` :

- Provisionnement de la VM via Terraform
- Déploiement de Prometheus, Grafana et Alertmanager via Ansible (Docker Compose v2)
- Installation de Node Exporter sur toutes les VMs
- Intégration DNS dans Bind9 pour un accès par noms
- Cycle de vie et idempotence

L’ensemble respecte les contraintes du projet : SSOT, DevSecOps, idempotence, utilisation de Docker Compose v2 et secrets dans Ansible Vault.

---

## 2. Déroulé complet des commandes de déploiement

Cette section décrit, étape par étape, ce qui se passe depuis la première commande jusqu’à la fin du déploiement.

### 2.1. Création de la VM `monitoring-stack` (Terraform)

**Commande exécutée :**

```bash
cd /home/admin1/Documents/Projet_infra_devops
terraform apply -target='proxmox_virtual_environment_vm.vm["monitoring-stack"]' -auto-approve
```

**Effets principaux :**

- Création d’une VM Proxmox `monitoring-stack` à partir du template cloud-init.
- Paramètres clés (issus de `terraform.tfvars`) :
  - CPU : 2 vCPU
  - RAM : 4096 Mo
  - Disque : 50 Go
  - Réseau : `vmbr23`, IP `172.16.100.60/24`, passerelle `172.16.100.1`
  - Utilisateur : `ansible` (clé SSH injectée via cloud-init)
  - Tags Proxmox : `monitoring`, `observability`, `prod` (permettent le groupement Ansible `monitoring_hosts`).
- Activation de l’agent QEMU pour remonter les interfaces réseau à Terraform.

Une fois la commande terminée, la VM est créée, démarrée et accessible en SSH par Ansible.

### 2.2. Déploiement de la stack monitoring (Ansible)

**Commande :**

```bash
cd /home/admin1/Documents/Projet_infra_devops/Ansible
ansible-playbook playbooks/monitoring.yml
```

Ce playbook contient deux plays :

1. **Play 1 – Déploiement Stack Monitoring**
   - `hosts: monitoring_hosts` (groupe peuplé automatiquement par l’inventaire généré par Terraform)
   - `become: true`
   - Rôle appliqué : `monitoring`

2. **Play 2 – Installation Node Exporter**
   - `hosts: all`
   - `become: true`
   - Rôle appliqué : `node_exporter`

#### 2.2.1. Rôle `monitoring` – Aperçu des étapes

Sur `monitoring-stack`, le rôle `monitoring` exécute les tâches suivantes :

1. **Pré-requis Docker et fichiers (tasks/prerequisites.yml)**
   - Installation des paquets :
     - `docker.io`
     - `python3-docker`
   - Installation de Docker Compose v2 via le binaire officiel GitHub, placé dans
     `/usr/local/lib/docker/cli-plugins/docker-compose` (permissions `0755`).
   - Démarrage et activation du service `docker`.
   - Création des répertoires de données et de configuration :
     - Base : `/data/monitoring`
     - Prometheus : `/data/monitoring/prometheus`
     - Grafana : `/data/monitoring/grafana`
     - Alertmanager : `/data/monitoring/alertmanager`
     - Configs : `/data/monitoring/config` et sous-répertoires Grafana
       (`provisioning`, `datasources`, `dashboards`).
   - Ajustement des permissions pour respecter les UIDs non-root utilisés dans les conteneurs :
     - Prometheus : UID/GID `65534` sur `/data/monitoring/prometheus`
     - Grafana : UID/GID `472` sur `/data/monitoring/grafana`
     - Alertmanager : UID/GID `65534` sur `/data/monitoring/alertmanager`
   - Si UFW est présent et actif, ouverture des ports 9090 (Prometheus), 3000 (Grafana) et 9093 (Alertmanager).

2. **Configuration Prometheus (tasks/prometheus.yml)**
   - Génération de `prometheus.yml` (via `templates/prometheus.yml.j2`) dans
     `/data/monitoring/config/prometheus.yml`.
   - Génération des règles d’alerte `alert-rules.yml` (via `templates/alert-rules.yml.j2`) dans
     `/data/monitoring/config/alert-rules.yml`.
   - Les deux tâches notifient le handler de redémarrage de la stack Docker Compose.

   La configuration Prometheus :
   - Déclare les intervalles globaux de scrutation et d’évaluation (`15s`).
   - Charge les règles depuis `/etc/prometheus/alert-rules.yml` dans le conteneur.
   - Définit des jobs :
     - `prometheus` (scrape `localhost:9090` dans le conteneur)
     - `alertmanager` (scrape `localhost:9093` dans le conteneur)
     - `node-exporter` : cibles générées dynamiquement à partir de `groups['all']` et des `ansible_host` présents dans l’inventaire Ansible.

3. **Configuration Alertmanager (tasks/alertmanager.yml)**
   - Génération de `alertmanager.yml` dans
     `/data/monitoring/config/alertmanager.yml` à partir de `templates/alertmanager.yml.j2`.
   - Configuration d’un routeur basique avec un receiver email utilisant :
     - `alertmanager_smtp_host`
     - `alertmanager_smtp_from`
     - `alertmanager_smtp_to`
     - `alertmanager_smtp_username`
     - `alertmanager_smtp_password` (stocké dans le vault `secrets/monitoring.vault`).

4. **Configuration Grafana (tasks/grafana.yml)**
   - Génération de la datasource Prometheus via `templates/grafana-datasources.yml.j2` dans
     `/data/monitoring/config/grafana/provisioning/datasources/datasources.yml`.
   - Copie des dashboards fournis :
     - `node-exporter.json`
     - `docker-containers.json`
     vers `/data/monitoring/config/grafana/provisioning/dashboards/`.

5. **Génération du fichier Docker Compose et déploiement (tasks/main.yml)**
   - Génération du fichier `docker-compose.yml` dans `/data/monitoring/config/docker-compose.yml`
     à partir du template `templates/docker-compose.yml.j2`.
   - Déploiement / mise à jour de la stack via `community.docker.docker_compose_v2` :
     - `project_src: /data/monitoring/config`
     - `files: ["/data/monitoring/config/docker-compose.yml"]`
     - `state: present`
   - Résultat : création / mise à jour des conteneurs `prometheus`, `grafana` et `alertmanager` sur le réseau Docker `config_monitoring_net`.

#### 2.2.2. Rôle `node_exporter`

Sur **toutes** les VMs (y compris `monitoring-stack`), le rôle `node_exporter` :

1. Crée un utilisateur système `node_exporter` sans shell.
2. Crée le répertoire d’installation (par défaut `/opt/node_exporter`).
3. Télécharge l’archive officielle `node_exporter-<version>.linux-amd64.tar.gz` depuis GitHub pour la version définie.
4. Décompresse l’archive et copie le binaire `node_exporter` dans `/usr/local/bin`.
5. Génère un service systemd `node_exporter.service` (template) écoutant sur le port `9100`.
6. Recharge systemd, active et démarre le service.
7. Si UFW est installé et actif, ouvre le port 9100 **uniquement** depuis l’IP de `monitoring-stack`.

Ce rôle est idempotent : rejouer le playbook ne réinstalle pas inutilement le binaire si la version cible est déjà en place.

### 2.3. Configuration DNS Bind9

Les enregistrements DNS de la stack monitoring sont gérés par Ansible via le fichier
`Ansible/inventory/host_vars/bind9dns.yml`. La zone dynamique `lab.local` inclut notamment :

- `monitoring.lab.local` → A `172.16.100.60`
- `grafana.lab.local` → CNAME vers `monitoring.lab.local.`
- `prometheus.lab.local` → CNAME vers `monitoring.lab.local.`
- `alertmanager.lab.local` → CNAME vers `monitoring.lab.local.`

L’application de la config Bind9 se fait avec :

```bash
cd /home/admin1/Documents/Projet_infra_devops/Ansible
ansible-playbook -i inventory/hosts.yml playbooks/bind9-docker.yml
```

Une fois appliquée, et à condition que les clients utilisent le serveur DNS interne (`172.16.100.254`),
les noms ci-dessus sont résolus correctement.

### 2.5. Autres services internes (Harbor, GitLab, tools-manager)

Pour rester cohérent côté DNS, d'autres services de la plateforme ont également été déclarés dans la zone `lab.local` du même fichier `bind9dns.yml` :

- `harbor.lab.local` → A `172.16.100.253`
- `git-lab.lab.local` → A `172.16.100.40`
- `gitlab.lab.local` → CNAME vers `git-lab.lab.local.`
- `tools-manager.lab.local` → A `172.16.100.20`

Points importants :
- Sur le serveur Bind9, ces enregistrements sont déjà fonctionnels (vérifiables avec `dig @172.16.100.254 …`).
- Sur la machine d'admin (Ubuntu avec `systemd-resolved`), le suffixe `.local` est géré de manière spéciale (mDNS). Pour garantir la résolution de `*.lab.local`, deux actions ont été faites :
  - simplification de `nsswitch.conf` pour utiliser `hosts: files dns` ;
  - ajout d'entrées explicites dans `/etc/hosts` pour `monitoring.lab.local`, `grafana.lab.local`, `prometheus.lab.local`, `alertmanager.lab.local`, `harbor.lab.local`, `git-lab.lab.local` / `gitlab.lab.local` et `tools-manager.lab.local`.

Ainsi, même si le stub resolver local traite `.local` de façon particulière, l'admin peut accéder à l'ensemble des services internes par nom de domaine tout en gardant Bind9 comme source de vérité.

### 2.4. Validation par `curl`

Depuis la machine de management, après déploiement :

- **Prometheus cibles** :

  ```bash
  curl http://172.16.100.60:9090/targets
  # ou, si la résolution DNS est active :
  curl http://monitoring.lab.local:9090/targets
  ```

  Retour : page HTML de l’UI Prometheus avec la liste des targets.

- **Santé Grafana** :

  ```bash
  curl http://172.16.100.60:3000/api/health
  # ou
  curl http://grafana.lab.local:3000/api/health
  ```

  Exemple de réponse JSON :

  ```json
  {
    "commit": "…",
    "database": "ok",
    "version": "10.2.3"
  }
  ```

- **Readiness Alertmanager** :

  ```bash
  curl http://172.16.100.60:9093/-/ready
  # ou
  curl http://alertmanager.lab.local:9093/-/ready
  ```

  Réponse attendue :

  ```text
  OK
  ```

Ces vérifications confirment que la stack est opérationnelle.

---

## 3. Cycle de vie de la stack monitoring

### 3.1. Création initiale

1. Définition / ajout de la VM dans `terraform.tfvars` (entrée `monitoring-stack` dans le map `nodes`).
2. `terraform apply -target=…` pour créer uniquement la VM de monitoring.
3. Mise à jour automatique de l’inventaire Ansible généré (`Ansible/inventory/terraform.generated.yml`).
4. Première exécution du playbook `playbooks/monitoring.yml` pour :
   - Installer Docker + Docker Compose v2 sur `monitoring-stack`
   - Générer les configs Prometheus, Grafana, Alertmanager
   - Déployer les conteneurs
   - Installer Node Exporter sur toutes les VMs.
5. Application / mise à jour de la configuration Bind9 pour exposer les entrées DNS de la stack.

### 3.2. Mise à jour

- **Mettre à jour une version (Prometheus / Grafana / Alertmanager / Node Exporter)** :
  - Modifier la version dans `Ansible/inventory/group_vars/monitoring_hosts.yml`.
  - Rejouer :

    ```bash
    cd Ansible
    ansible-playbook playbooks/monitoring.yml
    ```

  - Docker Compose téléchargera les nouvelles images et redémarrera proprement les services.

- **Ajouter / retirer des VMs à monitorer** :
  - Géré par Terraform (ajout/suppression dans `terraform.tfvars`).
  - Regénération de l’inventaire Ansible.
  - Rejeu du playbook : Prometheus découvrit automatiquement les nouvelles cibles Node Exporter via `groups['all']`.

- **Modifier les règles d’alerte** :
  - Éditer `Ansible/roles/monitoring/templates/alert-rules.yml.j2`.
  - Rejouer le playbook monitoring : le handler redémarrera Prometheus uniquement si le fichier est modifié.

### 3.3. Re-déploiement / idempotence

- Rerunner `ansible-playbook playbooks/monitoring.yml` est **idempotent** :
  - Paquets déjà installés → `ok` sans changement.
  - Fichiers templates identiques → pas de redémarrage inutile.
  - Node Exporter déjà à la bonne version → pas de réinstallation.

- De même, un `terraform apply` sans modification ne provoque pas de changements sur la VM.

### 3.4. Arrêt et suppression

- **Arrêter la stack Docker** :
  - Modifier l’état souhaité dans une tâche dédiée ou exécuter manuellement `docker compose down` sur `monitoring-stack` si besoin ponctuel.

- **Supprimer la VM de monitoring** :
  - Supprimer l’entrée correspondante dans `terraform.tfvars`.
  - Exécuter `terraform apply` pour détruire la ressource Proxmox.
  - Optionnel : nettoyer les enregistrements DNS associés dans `bind9dns.yml` via Ansible.

---

## 4. Tableau des fichiers de code liés à la stack monitoring

| Fichier | Rôle (SSOT ou non) | Description synthétique |
|--------|---------------------|-------------------------|
| `terraform.tfvars` | SSOT infra (VMs) | Définition des VMs, dont `monitoring-stack` (IP, CPU, RAM, disque, tags). |
| `main.tf` | Non (implémentation) | Ressource `proxmox_virtual_environment_vm` qui utilise les données de `terraform.tfvars`. |
| `variables.tf` | Non (schéma) | Déclaration des variables Terraform, y compris le map `nodes`. |
| `Ansible/inventory/terraform.generated.yml` | Non (généré) | Inventaire Ansible dynamique produit par Terraform, groupement `monitoring_hosts`. |
| `Ansible/inventory/group_vars/all.yml` | SSOT global | Paramètres globaux Ansible (bastion, options communes). |
| `Ansible/inventory/group_vars/monitoring_hosts.yml` | SSOT monitoring | Versions, ports, stockage, paramètres SMTP et options de la stack monitoring. |
| `Ansible/secrets/monitoring.vault` | SSOT secrets monitoring | Mots de passe Grafana admin et SMTP Alertmanager (chiffrés via Ansible Vault). |
| `Ansible/roles/monitoring/defaults/main.yml` | SSOT technique (rôle) | Structure des chemins (données, configs), noms de services et réseau Docker pour la stack. |
| `Ansible/roles/monitoring/tasks/prerequisites.yml` | Non | Installation Docker/Docker Compose et création des répertoires avec les bons UID/GID. |
| `Ansible/roles/monitoring/tasks/prometheus.yml` | Non | Génération des fichiers de configuration Prometheus et de ses règles d’alerte. |
| `Ansible/roles/monitoring/tasks/alertmanager.yml` | Non | Génération de la configuration Alertmanager. |
| `Ansible/roles/monitoring/tasks/grafana.yml` | Non | Génération des datasources Grafana et copie des dashboards. |
| `Ansible/roles/monitoring/tasks/main.yml` | Non (orchestration) | Chaînage de toutes les tâches du rôle `monitoring` et appel à Docker Compose v2. |
| `Ansible/roles/monitoring/templates/docker-compose.yml.j2` | Non | Définition de la stack Docker (services Prometheus, Grafana, Alertmanager, réseau, volumes). |
| `Ansible/roles/monitoring/templates/prometheus.yml.j2` | Non | Configuration Prometheus, y compris l’auto-discovery des cibles Node Exporter via `groups['all']`. |
| `Ansible/roles/monitoring/templates/alertmanager.yml.j2` | Non | Configuration Alertmanager (receiver email, routes de base). |
| `Ansible/roles/monitoring/templates/grafana-datasources.yml.j2` | Non | Datasource Grafana vers Prometheus. |
| `Ansible/roles/monitoring/templates/alert-rules.yml.j2` | Non | Règles d’alerte de base (InstanceDown, HighCPUUsage). |
| `Ansible/roles/monitoring/files/dashboards/node-exporter.json` | Non | Dashboard Grafana pour les métriques Node Exporter. |
| `Ansible/roles/monitoring/files/dashboards/docker-containers.json` | Non | Dashboard Grafana pour les conteneurs Docker. |
| `Ansible/roles/node_exporter/defaults/main.yml` | SSOT technique (rôle) | Paramètres par défaut Node Exporter (version, port, chemins). |
| `Ansible/roles/node_exporter/tasks/main.yml` | Non | Installation du binaire Node Exporter, service systemd, ouverture éventuelle du firewall. |
| `Ansible/roles/node_exporter/templates/node_exporter.service.j2` | Non | Unit file systemd Node Exporter. |
| `Ansible/roles/node_exporter/handlers/main.yml` | Non | Handler de redémarrage du service Node Exporter. |
| `Ansible/playbooks/monitoring.yml` | Point d’entrée | Playbook de déploiement de la stack monitoring et de Node Exporter sur toutes les VMs. |
| `Ansible/inventory/host_vars/bind9dns.yml` | SSOT DNS | Zones dynamiques Bind9, dont `lab.local` et les enregistrements `monitoring`, `grafana`, `prometheus`, `alertmanager`. |
| `Ansible/playbooks/bind9-docker.yml` | Non | Playbook d’application de la configuration Bind9. |
| `Docs/stackMonitoring/stackMonitoring.md` | Documentation | Document courant décrivant la stack monitoring et son cycle de vie. |

---

## 5. Vision SSOT du projet

Le projet s’appuie sur une séparation claire des responsabilités et une **Single Source Of Truth** (SSOT) par type de données :

- **Infrastructure (VMs, IP, ressources)** :
  - SSOT : `terraform.tfvars` (map `nodes`).
  - Implémentation : `main.tf`, `variables.tf` et le provider Proxmox.
  - Effet : création / suppression / modification des VMs, dont `monitoring-stack`.

- **Configuration Ansible globale** :
  - SSOT : `Ansible/inventory/group_vars/all.yml`.
  - Effet : options communes (bastion, comportements partagés) utilisées par tous les playbooks.

- **Stack monitoring** :
  - SSOT fonctionnelle : `Ansible/inventory/group_vars/monitoring_hosts.yml`.
  - SSOT technique (chemins, noms de services) : `Ansible/roles/monitoring/defaults/main.yml`.
  - Implémentation : tâches et templates du rôle `monitoring` + rôle `node_exporter`.

- **Secrets (mots de passe, SMTP, etc.)** :
  - SSOT : `Ansible/secrets/monitoring.vault` (à chiffrer avec Ansible Vault).
  - Effet : aucun secret en clair dans les playbooks ou les inventaires.

- **DNS interne** :
  - SSOT : `Ansible/inventory/host_vars/bind9dns.yml`.
  - Implémentation : rôle Bind9 et playbook `bind9-docker.yml`.
  - Effet : tous les noms (dont `monitoring.lab.local`, `grafana.lab.local`, `prometheus.lab.local`, `alertmanager.lab.local`) sont dérivés de ce fichier.

- **Documentation** :
  - SSOT pour la compréhension : `Docs/stackMonitoring/stackMonitoring.md` et les autres documents dans `docs/`.
  - Effet : décrit le *comment* et le *pourquoi*, mais ne remplace pas les fichiers de configuration comme source de vérité opérationnelle.

En résumé :

- **Terraform** décrit *ce qui existe* (VMs et infrastructure).
- **Ansible** décrit *comment configurer* ces ressources (Docker, services, monitoring, DNS).
- **Vault** contient *ce qui doit rester secret*.
- **Bind9** (via Ansible) expose *comment on y accède par nom*.
- **La documentation** explique *comment tout s’articule* mais renvoie toujours vers la SSOT adéquate pour chaque type de donnée.
