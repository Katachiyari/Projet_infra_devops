# Stack Monitoring (Prometheus, Grafana, Alertmanager)

## 1. Objectif

Déployer une stack de supervision complète sur une VM dédiée `monitoring-stack` (172.16.100.60) avec :
- Prometheus (scraping métriques, port 9090)
- Grafana (dashboards, port 3000)
- Alertmanager (alertes, port 9093)
- Node Exporter sur toutes les VMs (port 9100)

## 2. Architecture

- VM : `monitoring-stack` (Terraform, template cloud-init Proxmox)
- Domaine logique : `monitoring.lab.local`
- DNS : Bind9 sur `bind9dns` (172.16.100.254) expose :
  - `monitoring.lab.local` → 172.16.100.60
  - `grafana.lab.local` (CNAME) → `monitoring.lab.local`
  - `prometheus.lab.local` (CNAME) → `monitoring.lab.local`
  - `alertmanager.lab.local` (CNAME) → `monitoring.lab.local`

Stack déployée via Ansible :
- Groupe Ansible : `monitoring_hosts`
- Rôle : `monitoring` (stack Docker Compose)
- Rôle : `node_exporter` (binaire officiel + systemd sur toutes les VMs)

## 3. Terraform – VM monitoring-stack

La VM est déclarée dans [terraform.tfvars](terraform.tfvars) :

- Nom : `monitoring-stack`
- IP : `172.16.100.60`
- CPU : 2 vCPU
- RAM : 4096 MB
- Disque : 50 GB
- Bridge : `vmbr23`
- Tags : `["monitoring", "observability", "prod"]`

Le tag `monitoring` est mappé vers le groupe Ansible `monitoring_hosts` via `ansible_group_by_tag`.

Création ciblée de la VM :

```bash
terraform apply -target=proxmox_virtual_environment_vm.vm["monitoring-stack"]
```

## 4. Ansible – Variables SSOT

Les variables de la stack monitoring sont centralisées dans :

- [Ansible/inventory/group_vars/monitoring_hosts.yml](Ansible/inventory/group_vars/monitoring_hosts.yml)

Ce fichier définit notamment :
- Versions : `prometheus_version`, `grafana_version`, `alertmanager_version`, `node_exporter_version`
- Ports : `prometheus_port` (9090), `grafana_port` (3000), `alertmanager_port` (9093), `node_exporter_port` (9100)
- Stockage : `monitoring_data_volume` (`/data/monitoring`)
- Secrets référencés : `grafana_admin_password`, `alertmanager_smtp_password` (fournis par le vault)

Les secrets sont dans :

- [Ansible/secrets/monitoring.vault](Ansible/secrets/monitoring.vault)

À chiffrer avec Ansible Vault :

```bash
cd Ansible
ansible-vault encrypt secrets/monitoring.vault
```

## 5. Rôle monitoring

Chemin : [Ansible/roles/monitoring](Ansible/roles/monitoring)

Fonctions principales :
- Installer Docker + dépendances (`prerequisites.yml`)
- Créer les répertoires de données et de configuration sous `/data/monitoring`
- Générer les fichiers de configuration :
  - `prometheus.yml` (scrape configs et règles)
  - `alert-rules.yml` (règles d’alerte de base)
  - `alertmanager.yml` (route par défaut + email)
  - `grafana-datasources.yml` (datasource Prometheus)
- Déployer une stack Docker Compose avec 3 services :
  - `prometheus` (image prom/prometheus, non-root)
  - `grafana` (image grafana/grafana, user 472)
  - `alertmanager` (image prom/alertmanager, non-root)

### 5.1. Auto-discovery des cibles Prometheus

Le template [prometheus.yml.j2](Ansible/roles/monitoring/templates/prometheus.yml.j2) génère une job `node-exporter` à partir de l’inventaire Ansible :
- Pour chaque hôte de `groups['all']` ayant `ansible_host` défini, une cible `ansible_host:9100` est ajoutée.

Ainsi, dès que Node Exporter est installé sur une nouvelle VM avec `ansible_host` défini, Prometheus commence à la scrapper.

### 5.2. Déploiement Docker Compose

Le template [docker-compose.yml.j2](Ansible/roles/monitoring/templates/docker-compose.yml.j2) décrit la stack :
- Réseau dédié `monitoring_net`
- Volumes de données sous `/data/monitoring/{prometheus,grafana,alertmanager}`
- Volumes de configuration sous `/data/monitoring/config`

Le handler `restart monitoring stack` relance la stack quand un fichier de configuration change.

## 6. Rôle node_exporter

Chemin : [Ansible/roles/node_exporter](Ansible/roles/node_exporter)

Fonctions :
- Téléchargement du binaire officiel Node Exporter depuis GitHub (version contrôlée)
- Installation sous `/usr/local/bin/node_exporter`
- Création d’un utilisateur système dédié `node_exporter`
- Création d’un service systemd `node_exporter.service`
- Démarrage + activation au boot
- Si UFW est actif :
  - Ouverture du port 9100 uniquement depuis `172.16.100.60` (monitoring-stack)

## 7. Playbook monitoring

Playbook : [Ansible/playbooks/monitoring.yml](Ansible/playbooks/monitoring.yml)

- Déploiement de la stack monitoring sur `monitoring_hosts` :

```yaml
- name: Déploiement Stack Monitoring
  hosts: monitoring_hosts
  become: true
  vars_files:
    - "../secrets/monitoring.vault"
  roles:
    - monitoring
```

- Installation de Node Exporter sur toutes les VMs :

```yaml
- name: Installation Node Exporter (toutes VMs)
  hosts: all
  become: true
  vars_files:
    - "../secrets/monitoring.vault"
  roles:
    - role: node_exporter
      tags: ["node_exporter"]
```

## 8. DNS Bind9

Les enregistrements DNS sont gérés via les variables de l’hôte Bind9 :

- Fichier : [Ansible/inventory/host_vars/bind9dns.yml](Ansible/inventory/host_vars/bind9dns.yml)
- Zone dynamique ajoutée : `lab.local` avec les enregistrements :
  - `monitoring.lab.local` → 172.16.100.60
  - `grafana.lab.local` → CNAME vers `monitoring.lab.local.`
  - `prometheus.lab.local` → CNAME vers `monitoring.lab.local.`
  - `alertmanager.lab.local` → CNAME vers `monitoring.lab.local.`

Application de la configuration DNS :

```bash
cd Ansible
ansible-playbook -i inventory/hosts.yml playbooks/bind9-docker.yml
```

## 9. Commandes de déploiement

1. **Créer la VM monitoring-stack** (si pas encore présente) :

```bash
terraform apply -target=proxmox_virtual_environment_vm.vm["monitoring-stack"]
```

2. **Attendre la fin de cloud-init** (SSH OK sur ansible@monitoring-stack) puis :

```bash
cd Ansible
ansible-playbook playbooks/monitoring.yml --ask-vault-pass
```

3. **Réappliquer la config DNS Bind9 si nécessaire** :

```bash
ansible-playbook -i inventory/hosts.yml playbooks/bind9-docker.yml
```

## 10. Validation

- Prometheus :
  - UI : `http://monitoring.lab.local:9090`
  - Targets : `http://monitoring.lab.local:9090/targets`
- Grafana :
  - UI : `http://grafana.lab.local:3000`
  - Login : user `admin`, mot de passe vault
- Alertmanager :
  - UI : `http://alertmanager.lab.local:9093`

Tests de résolution DNS :

```bash
dig monitoring.lab.local @172.16.100.254
dig grafana.lab.local @172.16.100.254
```

Tests d’idempotence :

```bash
cd Ansible
ansible-playbook playbooks/monitoring.yml --ask-vault-pass
# Attendu : 0 failed, et uniquement quelques "changed" si mise à jour de version
```

## 11. Troubleshooting

- Vérifier le statut des services sur monitoring-stack :

```bash
sudo systemctl status docker
sudo docker ps
```

- Vérifier Prometheus :
  - `docker logs prometheus`
- Vérifier Grafana :
  - `docker logs grafana`
- Vérifier Alertmanager :
  - `docker logs alertmanager`

- Vérifier Node Exporter sur une VM :

```bash
sudo systemctl status node_exporter
curl http://localhost:9100/metrics | head
```

- Vérifier que les cibles Node Exporter apparaissent dans la page `/targets` de Prometheus.
