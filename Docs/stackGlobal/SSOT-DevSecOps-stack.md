# SSOT – Stack DevSecOps Proxmox / Terraform / Ansible

## 1. Vue d’ensemble

Cette documentation décrit la **stack DevSecOps** déployée sur Proxmox dans ce projet, en appliquant le principe **SSOT (Single Source of Truth)** :

- **Terraform** : provisionnement des VMs Proxmox (réseau, IP, SSH).
- **Cloud-init** : bootstrap OS une seule fois au premier démarrage.
- **Ansible** : configuration idempotente des services.
- **Bind9** : DNS interne pour les domaines `lab.local` et `jdk.lab`.
- **PKI locale** : autorité de certification interne « Lab Root CA ».
- **Nginx reverse-proxy** : terminaison TLS HTTPS pour `*.lab.local`.
- **Harbor + Portainer** : registre d’images et UI de gestion Docker.
- **Stack monitoring** : Prometheus, Grafana, Alertmanager, Node Exporter.

Tout le trafic externe passe par le reverse-proxy HTTPS, les backends applicatifs restant **en HTTP interne uniquement**.

---

## 2. Topologie réseau et DNS

- Réseau : `172.16.100.0/24`.
- Hôtes principaux :
  - `bind9dns` : `172.16.100.254` – serveur DNS Bind9.
  - `reverse-proxy` : `172.16.100.253` – Nginx (terminaison TLS).
  - `harbor` : `172.16.100.50` – Harbor + Portainer (HTTP backends).
  - `monitoring-stack` : `172.16.100.60` – Prometheus, Grafana, Alertmanager.
  - `git-lab` : `172.16.100.40` – hôte prévu pour GitLab (mission ultérieure).

### 2.1 DNS Bind9 (SSOT noms ↔ IP)

Le rôle Bind9 gère les zones dynamiques, notamment `lab.local` :

- Les enregistrements `A` critiques pointent **vers le reverse-proxy** :
  - `harbor.lab.local` → `172.16.100.253`.
  - `portainer.lab.local` → `172.16.100.253`.
- Les services de monitoring pointent vers la VM dédiée :
  - `prometheus.lab.local` → `172.16.100.60`.
  - `grafana.lab.local` → `172.16.100.60`.
  - `alertmanager.lab.local` → `172.16.100.60`.

Les fichiers SSOT de DNS (variables Ansible) sont consommés par le rôle Bind9 pour générer les fichiers de zone.

---

## 3. PKI locale (Mission 0)

### 3.1 Autorité de certification « Lab Root CA »

Le rôle `pki_ca` gère :

- La clé privée de l’AC : `/opt/ca/root-ca.key` (RSA 4096).
- Le certificat racine : `/opt/ca/root-ca.crt`.
- L’installation du certificat racine dans le trust système via :
  - `/usr/local/share/ca-certificates/lab-root-ca.crt`.
  - `update-ca-certificates`.

Ce certificat est la **seule source de vérité** pour les certificats TLS utilisés par Nginx.

### 3.2 Certificat wildcard `*.lab.local`

- Certificat émis par la Lab Root CA.
- SANs : `*.lab.local` et `lab.local`.
- Utilisé exclusivement par Nginx sur la VM `reverse-proxy`.

Pour les navigateurs (Firefox, etc.), il faut **importer manuellement** le certificat racine (`lab-root-ca.crt`) dans les autorités de confiance.

---

## 4. Nginx reverse-proxy (Mission 1)

### 4.1 Rôle et conteneurisation

- Nginx tourne en conteneur (`nginx:1.25-alpine`) sur la VM `reverse-proxy`.
- Le rôle Ansible `nginx_reverse_proxy` :
  - Monte les certificats TLS (`lab-root-ca` + wildcard).
  - Expose les ports 80 (redirection) et 443 (HTTPS).
  - Déclare les upstreams vers les backends HTTP.

### 4.2 Politique de sécurité HTTP

- Redirection systématique `HTTP → HTTPS`.
- Protocoles TLS ≥ 1.2.
- En-têtes de sécurité : `Strict-Transport-Security`, `X-Frame-Options`, `X-Content-Type-Options`, `X-XSS-Protection`, `Referrer-Policy`, etc.
- Zones de rate limiting sur les endpoints sensibles.
- Logs JSON structurés (prêt pour collecte centralisée).

### 4.3 Routage applicatif (exemples)

- `https://harbor.lab.local/` → upstream Harbor HTTP `172.16.100.50:80`.
- `https://portainer.lab.local/` → upstream Portainer HTTP `172.16.100.50:9000`.

Le reverse-proxy est **le seul point d’entrée HTTPS** des services applicatifs.

---

## 5. Harbor + Portainer (Mission 2)

### 5.1 VM Harbor/Portainer (`172.16.100.50`)

- Harbor (registre d’images) :
  - Version : 2.11.x (offline installer).
  - Exposé en HTTP sur `0.0.0.0:80`.
  - `external_url` configurée en `https://harbor.lab.local` pour être cohérente avec le reverse-proxy.
- Portainer (UI gestion Docker) :
  - Image `portainer/portainer-ce:lts`.
  - Exposé en HTTP sur `0.0.0.0:9000`.

### 5.2 Sécurité réseau

- UFW sur la VM Harbor :
  - `allow from 172.16.100.253 to any port 80`.
  - `allow from 172.16.100.253 to any port 9000`.
  - Politique par défaut `deny incoming` pour ces ports depuis le reste du réseau.

Les backends ne sont donc accessibles qu’à partir du reverse-proxy.

### 5.3 Trivy et DevSecOps

- Trivy est utilisé pour scanner les images clés (Harbor, Portainer, etc.).
- Les builds échouent si des vulnérabilités **CRITICAL/HIGH** sont détectées (politique DevSecOps stricte).

---

## 6. Stack Monitoring

### 6.1 VM `monitoring-stack` (`172.16.100.60`)

- Prometheus : `http://prometheus.lab.local:9090`.
- Grafana : `http://grafana.lab.local:3000`.
- Alertmanager : `http://alertmanager.lab.local:9093`.

Le tout est généralement déployé via Docker Compose par le rôle `monitoring`.

### 6.2 Node Exporter

- Installé comme service systemd sur les VMs cibles.
- Expose les métriques système sur un port local.
- Scrappé par Prometheus depuis la VM `monitoring-stack`.

---

## 7. Chaîne de requête : du navigateur au backend

### 7.1 Exemple : `https://harbor.lab.local/`

1. Le client (Firefox) résout `harbor.lab.local` :
   - DNS Bind9 renvoie `172.16.100.253` (reverse-proxy).
   - Ou `/etc/hosts` sur les postes de gestion doit être cohérent avec cette valeur.
2. Connexion TLS vers `172.16.100.253:443` :
   - Nginx présente le certificat wildcard `*.lab.local`.
   - Le client le valide grâce à la **Lab Root CA** importée.
3. Nginx proxifie la requête en HTTP vers `172.16.100.50:80` (Harbor).
4. La réponse HTTP de Harbor est renvoyée chiffrée au client.

### 7.2 Exemple : `https://portainer.lab.local/`

1. Résolution DNS `portainer.lab.local` → `172.16.100.253`.
2. TLS terminé par Nginx avec le certificat wildcard.
3. Proxy HTTP vers `172.16.100.50:9000` (Portainer).
4. Portainer répond (souvent par une redirection 307/302 vers `/` ou `/timeout.html`).

---

## 8. Validation et dépannage

### 8.1 Tests côté infrastructure (depuis une VM de gestion)

- Vérifier la résolution DNS :

```bash
dig harbor.lab.local @172.16.100.254 +short
dig portainer.lab.local @172.16.100.254 +short
```

- Vérifier HTTPS via Nginx :

```bash
curl -vk https://harbor.lab.local/ -o /dev/null
curl -vk https://portainer.lab.local/ -o /dev/null
```

- Vérifier monitoring :

```bash
curl -v http://prometheus.lab.local:9090/ -o /dev/null
curl -v http://grafana.lab.local:3000/ -o /dev/null
```

### 8.2 Points d’attention récurrents

- **CA non importée dans le navigateur** :
  - Symptômes : avertissements TLS ou échec de connexion.
  - Solution : récupérer `lab-root-ca.crt` depuis le reverse-proxy et l’importer dans Firefox (Autorités).
- **Incohérences `/etc/hosts` vs DNS** :
  - `/etc/hosts` peut surcharger Bind9.
  - Toujours aligner les entrées locales sur la vraie topologie (reverse-proxy comme point d’entrée).
- **UFW** :
  - Si Harbor/Portainer sont injoignables depuis le reverse-proxy, vérifier les règles UFW sur `172.16.100.50`.

---

## 9. URLs de référence

- Reverse-proxy (terminaison TLS globale) :
  - `https://harbor.lab.local/`
  - `https://portainer.lab.local/`
- Monitoring :
  - `http://prometheus.lab.local:9090/`
  - `http://grafana.lab.local:3000/`
  - `http://alertmanager.lab.local:9093/`

Les futures missions (GitLab, Taiga, EdgeDoc) suivront **la même logique** :

- Services HTTP internes sur leurs VMs dédiées.
- TLS terminé sur `reverse-proxy` avec le wildcard `*.lab.local`.
- Résolution DNS contrôlée par Bind9.
