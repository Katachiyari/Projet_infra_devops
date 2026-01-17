# Déploiement de Bind9 et ajout d'hôtes

Ce document explique comment déployer Bind9 avec Ansible dans ce dépôt, et comment ajouter un hôte (par exemple `ubuntu-host` 172.16.100.100) pour qu'il soit résolu par ce DNS.

## 1. Architecture et prérequis

- **Serveur DNS Bind9** :
  - Nom d'inventaire : `bind9dns`
  - Adresse IP : `172.16.100.254`
  - Rôle Ansible : `systemli.bind9`
- **Client Ubuntu** :
  - Nom logique : `ubuntu-host`
  - Adresse IP : `172.16.100.100`
  - Utilisera `172.16.100.254` comme serveur DNS.
- **Zone DNS** : `jdk.lab`

Prérequis sur la machine depuis laquelle tu lances Ansible :
- Accès SSH par clé vers `bind9dns` (172.16.100.254)
- Python + Ansible installés
- Rôles Ansible installés (une fois) :

```bash
cd Ansible
ansible-galaxy install -r requirements.yml
```

## 2. Inventaire et variables Bind9

### 2.1 Inventaire

L'inventaire Ansible définit le serveur DNS dans le groupe `bind9_hosts` :

- Fichier : `Ansible/inventory/hosts.yml`
- Définition principale :
  - Hôte : `bind9dns`
  - IP : `172.16.100.254`

### 2.2 Variables de Bind9

La configuration de la zone dynamique `jdk.lab` est centralisée dans :

- Fichier : `Ansible/inventory/host_vars/bind9dns.yml`
- Cette variable décrit la zone et ses enregistrements (RRs) :
  - `bind9_zones_dynamic` → liste des zones dynamiques
  - Chaque zone contient : nom, type, serial, NS, et `rrs` (A, CNAME, etc.).

Exemple (simplifié) de zone `jdk.lab` :
- Zone : `jdk.lab`
- NS : `ns1.jdk.lab`
- Enregistrements A principaux :
  - `ns1.jdk.lab` → `172.16.100.254`
  - `ubuntu-host.jdk.lab` → `172.16.100.100`

## 3. Déploiement de Bind9 (mode "classique" sur la VM)

Depuis la racine du rôle Ansible :

```bash
cd Ansible
ansible-playbook -i inventory/hosts.yml playbooks/bind9-docker.yml
```

Remarques :
- Le playbook `playbooks/bind9-docker.yml` appelle le rôle `systemli.bind9` pour installer et configurer Bind9 directement sur la VM `bind9dns`.
- Le playbook alternatif `playbooks/bind9-container.yml` est prévu pour un déploiement Bind9 en conteneur Docker via le rôle `bind9_docker` (non utilisé dans ce scénario).

Si tout se passe bien, le recap doit montrer :
- `bind9dns : failed=0` et `unreachable=0`

## 4. Ajouter un hôte à la zone (exemple : ubuntu-host)

Pour rattacher un nouvel hôte à Bind9 (le rendre résolvable par nom) :

1. **Éditer la zone dans les variables**
   - Fichier : `Ansible/inventory/host_vars/bind9dns.yml`
   - Dans la zone `jdk.lab`, ajouter un enregistrement dans `rrs`, par exemple :

   ```yaml
   bind9_zones_dynamic:
     - name: "jdk.lab"
       type: master
       serial: 2026011701
       admin: "postmaster.jdk.lab"
       ns_records:
         - "ns1.jdk.lab"
       rrs:
         - { label: "ns1", type: "A", rdata: "172.16.100.254" }
         - { label: "ubuntu-host", type: "A", rdata: "172.16.100.100" }
   ```

   - Le `label` sera préfixé par la zone, donc `ubuntu-host` devient `ubuntu-host.jdk.lab`.
   - Mettre à jour `serial` à une valeur plus récente lors de chaque modification de zone.

2. **Réappliquer la configuration Bind9**

   Depuis `Ansible/` :

   ```bash
   cd Ansible
   ansible-playbook -i inventory/hosts.yml playbooks/bind9-docker.yml
   ```

   Cela régénère les fichiers de zone et recharge Bind9.

## 5. Configurer le client Ubuntu (172.16.100.100)

Objectif : faire en sorte que `ubuntu-host` (172.16.100.100) utilise `172.16.100.254` comme DNS, et que le nom `ubuntu-host.jdk.lab` soit résolu.

1. **Configurer le DNS sur la machine 172.16.100.100**

   Sur une Ubuntu récente (avec Netplan), éditer le fichier de configuration réseau (par exemple `/etc/netplan/01-netcfg.yaml`) et ajouter :

   ```yaml
   nameservers:
     addresses:
       - 172.16.100.254
   ```

   Puis appliquer :

   ```bash
   sudo netplan apply
   ```

   (La commande exacte dépend de la configuration existante de Netplan sur la machine.)

2. **(Optionnel) Définir le nom d’hôte local**

   S'assurer que la machine 172.16.100.100 a bien pour hostname `ubuntu-host` :

   ```bash
   sudo hostnamectl set-hostname ubuntu-host
   ```

## 6. Vérifications

Depuis n'importe quelle machine qui utilise `172.16.100.254` comme DNS (y compris 172.16.100.100 une fois configurée) :

- Vérifier la résolution du NS :

  ```bash
  dig @172.16.100.254 ns1.jdk.lab
  ```

- Vérifier la résolution de l'hôte :

  ```bash
  dig @172.16.100.254 ubuntu-host.jdk.lab
  ```

- Vérifier avec un ping (si l'ICMP est autorisé) :

  ```bash
  ping ubuntu-host.jdk.lab
  ```

Si les commandes `dig` renvoient l'adresse `172.16.100.100` pour `ubuntu-host.jdk.lab`, la configuration DNS est correcte. Tu peux alors configurer définitivement `172.16.100.254` comme DNS dans la configuration réseau de `172.16.100.100` (et des autres hôtes du réseau) pour utiliser Bind9 comme serveur DNS central.

## 7. (Optionnel) Faire utiliser Bind9 par le serveur bind9dns lui-même

Sur la VM `bind9dns` (172.16.100.254), il peut être utile que la résolution système passe aussi par Bind9, afin que des commandes comme `ping ubuntu-host.jdk.lab` fonctionnent directement sans préciser `@172.16.100.254`.

Exemples de configuration possibles (selon la distro et les outils réseau) :

- Avec `systemd-resolved` (Debian/Ubuntu récents) :

  - Éditer `/etc/systemd/resolved.conf` et ajouter dans `[Resolve]` :

    ```ini
    DNS=172.16.100.254
    Domains=jdk.lab
    ```

  - Puis :

    ```bash
    sudo systemctl restart systemd-resolved
    ```

- Avec un `/etc/resolv.conf` classique :

  - Mettre par exemple :

    ```text
    nameserver 172.16.100.254
    search jdk.lab
    ```

Une fois la configuration appliquée, tu peux vérifier côté `bind9dns` :

```bash
getent hosts ubuntu-host.jdk.lab
ping ubuntu-host.jdk.lab
```
