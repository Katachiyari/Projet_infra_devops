# avant s'occuper du DNS tu fait une documention ssot de la résolution que nous venons de faire

Parfait ! Je crée la documentation SSOT (Single Source of Truth) de la résolution.

## Document : Troubleshooting Nginx Reverse Proxy

```bash
cat > ~/Documents/Projet_infra_devops/docs/troubleshooting-nginx-reverse-proxy.md << 'EOF'
# Troubleshooting - Déploiement Nginx Reverse Proxy

**Date** : 20 janvier 2026  
**Contexte** : Déploiement Ansible du rôle `nginx_reverse_proxy`  
**Serveur** : `reverse-proxy` (172.16.100.253)

---

## Symptôme Initial

```

TASK [nginx_reverse_proxy : Test HTTP to HTTPS redirect for Harbor]
fatal: [reverse-proxy]: FAILED!
msg: 'Status code was -1 and not : Request failed:
<urlopen error [Errno 111] Connection refused>'

```

**Signification** : Nginx ne répond pas sur le port 80 (connexion refusée).

---

## Diagnostic Étape par Étape

### 1. Vérification de l'état des conteneurs

```bash
docker ps | grep nginx
```

**Résultat** :

```
nginx-prometheus-exporter   Up 5 minutes   ✅
nginx-reverse-proxy         Restarting (1) 41 seconds ago   ❌
```

**Conclusion** : Le conteneur Nginx crash en boucle (code de sortie 1).

---

### 2. Analyse des logs Docker

```bash
docker logs nginx-reverse-proxy --tail 100
```

**Erreur critique** :

```
nginx: [emerg] cannot load certificate "/etc/nginx/ssl/wildcard.lab.local.crt": 
PEM_read_bio_X509_AUX() failed (SSL: error:0480006C:PEM routines::no start line:
Expecting: TRUSTED CERTIFICATE)
```

**Signification** :

- Le fichier certificat n'est pas au format PEM valide
- OpenSSL ne trouve pas `-----BEGIN CERTIFICATE-----`
- Nginx refuse de démarrer sans certificat SSL valide

---

### 3. Vérification des volumes Docker

```bash
docker inspect nginx-reverse-proxy | grep -A10 Mounts
```

**Résultat** :

```json
"Source": "/opt/ca/wildcard.lab.local.crt",
"Destination": "/etc/nginx/ssl/wildcard.lab.local.crt"
```

**Conclusion** : Docker monte `/opt/ca/wildcard.lab.local.crt` depuis l'hôte.

---

### 4. Inspection du système de fichiers hôte

```bash
ls -lah /opt/ca/
```

**Résultat** :

```
drwxr-xr-x 2 root root 4.0K wildcard.lab.local.crt   ❌ RÉPERTOIRE
drw------- 2 root root 4.0K wildcard.lab.local.key   ❌ RÉPERTOIRE
```

**🔴 CAUSE RACINE IDENTIFIÉE** :
Les certificats sont des **répertoires vides** au lieu de fichiers PEM.

**Conséquence** :

- Docker monte des répertoires comme fichiers
- Nginx tente de lire un répertoire comme certificat PEM
- OpenSSL échoue → Nginx crash

---

## Résolution

### Étape 1 : Suppression des répertoires incorrects

```bash
ssh ansible@172.16.100.253
sudo su -
rm -rf /opt/ca/wildcard.lab.local.crt
rm -rf /opt/ca/wildcard.lab.local.key
```


---

### Étape 2 : Génération des certificats SSL

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /opt/ca/wildcard.lab.local.key \
  -out /opt/ca/wildcard.lab.local.crt \
  -subj "/C=FR/ST=IDF/L=Paris/O=Lab/CN=*.lab.local" \
  -addext "subjectAltName=DNS:*.lab.local,DNS:lab.local"
```

**Paramètres** :

- `-x509` : Certificat auto-signé
- `-nodes` : Pas de chiffrement de la clé (no DES)
- `-days 365` : Validité 1 an
- `CN=*.lab.local` : Wildcard pour tous les sous-domaines

---

### Étape 3 : Sécurisation des permissions

```bash
chmod 644 /opt/ca/wildcard.lab.local.crt  # Lecture publique
chmod 600 /opt/ca/wildcard.lab.local.key  # Root uniquement
chown root:root /opt/ca/wildcard.lab.local.*
```

**Vérification** :

```bash
ls -lh /opt/ca/wildcard.*
# -rw-r--r-- 1 root root 1.3K wildcard.lab.local.crt  ✅
# -rw------- 1 root root 1.7K wildcard.lab.local.key  ✅

file /opt/ca/wildcard.lab.local.crt
# /opt/ca/wildcard.lab.local.crt: PEM certificate  ✅
```


---

### Étape 4 : Recréation du conteneur Docker

**Erreur lors du restart** :

```bash
docker restart nginx-reverse-proxy
# Error: OCI runtime create failed: not a directory: 
# Are you trying to mount a directory onto a file (or vice-versa)?
```

**Cause** : Docker a mis en cache l'ancien type (répertoire). Il faut **supprimer** le conteneur.

**Solution** :

```bash
docker stop nginx-reverse-proxy
docker rm nginx-reverse-proxy

cd /data/nginx
docker compose up -d
```

**Vérification** :

```bash
docker logs nginx-reverse-proxy
# nginx: [warn] the "listen ... http2" directive is deprecated...  ⚠️ Non bloquant
# (Aucune erreur [emerg])  ✅

docker ps | grep nginx
# nginx-reverse-proxy   Up 2 minutes   0.0.0.0:80->80/tcp   ✅
```


---

## Problèmes Secondaires Rencontrés

### Erreur de syntaxe YAML Ansible

**Symptôme** :

```
[ERROR]: YAML parsing failed: did not find expected key
Origin: /home/admin1/.../tasks/prerequisites.yml:50:3
```

**Cause** : Code dupliqué avec mauvaise indentation dans `prerequisites.yml`.

**Résolution** :

```bash
cd ~/Documents/Projet_infra_devops/Ansible
nano roles/nginx_reverse_proxy/tasks/prerequisites.yml
# Suppression du code dupliqué après la ligne 50
```


---

### Erreur de syntaxe dans deploy.yml

**Symptôme** :

```
[ERROR]: no module/action detected in task.
Origin: .../tasks/deploy.yml:12:3
```

**Cause** : Task vide sans module ansible (ligne 12 : nom sans action).

**Résolution** :

```bash
nano roles/nginx_reverse_proxy/tasks/deploy.yml
# Suppression de la task incomplète ligne 12
```


---

### Permission denied SSH (clé manquante)

**Symptôme** :

```
ansible@172.16.100.253: Permission denied (publickey)
```

**Cause** : Inventaire spécifie `id_ed25519_common` mais la clé est `id_ed25519`.

**Résolution** :

```bash
cd ~/Documents/Projet_infra_devops/Ansible
sed -i 's/id_ed25519_common/id_ed25519/g' inventory/hosts.yml

ansible reverse-proxy -m ping  # ✅
```


---

### Erreurs de syntaxe Nginx (accolades manquantes)

**Symptôme 1** :

```
nginx: [emerg] "server" directive is not allowed here in /etc/nginx/nginx.conf:297
```

**Cause** : Accolade fermante manquante ligne 296 (bloc `server` pour `/health`).

**Résolution** :

```bash
ssh ansible@172.16.100.253
sudo nano /data/nginx/config/nginx.conf
# Ajout de } ligne 296
```


---

**Symptôme 2** :

```
nginx: [emerg] "server" directive is not allowed here in /etc/nginx/nginx.conf:319
```

**Cause** : Accolade fermante manquante ligne 318 (bloc `server` HTTPS Grafana).

**Résolution** :

```bash
sudo nano /data/nginx/config/nginx.conf
# Ajout de } ligne 318 avant le bloc Prometheus
```


---

**Symptôme 3** :

```
nginx: [emerg] unexpected end of file, expecting "}" in /etc/nginx/nginx.conf:342
```

**Cause** : Accolades manquantes à la fin du fichier (fermeture du bloc `http {}`).

**Résolution** :

```bash
sudo nano /data/nginx/config/nginx.conf
# Ajout de :
#     }  # Fermeture du server Prometheus
# }      # Fermeture du bloc http
```


---

## Validation Finale

### Test HTTP → HTTPS

```bash
curl -I http://172.16.100.253
```

**Résultat attendu** :

```http
HTTP/1.1 301 Moved Permanently
Location: https://harbor.lab.local/
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

✅ **Succès**

---

### Test HTTPS

```bash
curl -kI https://172.16.100.253
```

**Résultat attendu** :

```http
HTTP/2 200
server: nginx/1.25.5
```

✅ **Succès**

---

### État des conteneurs

```bash
docker ps | grep nginx
```

**Résultat attendu** :

```
nginx-reverse-proxy         Up X minutes   0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp   ✅
nginx-prometheus-exporter   Up X minutes   0.0.0.0:9113->9113/tcp                       ✅
```


---

## Corrections à Appliquer dans le Code

### 1. Rôle PKI CA

Ajouter une validation des certificats dans `pki_ca/tasks/main.yml` :

```yaml
- name: Verify generated certificates are regular files
  ansible.builtin.stat:
    path: "{{ item }}"
  loop:
    - "{{ pki_ca_wildcard_cert_file }}"
    - "{{ pki_ca_wildcard_key_file }}"
  register: pki_cert_check

- name: Fail if certificates are directories
  ansible.builtin.fail:
    msg: "Certificate {{ item.item }} is a directory, not a file"
  when: item.stat.isdir
  loop: "{{ pki_cert_check.results }}"
```


---

### 2. Rôle Nginx Reverse Proxy

**Fichier** : `nginx_reverse_proxy/tasks/deploy.yml`

Ajouter une suppression forcée avant déploiement :

```yaml
- name: Stop Nginx reverse proxy containers if running
  community.docker.docker_container:
    name: "{{ item }}"
    state: absent
    force_kill: true
  loop:
    - nginx-reverse-proxy
    - nginx-prometheus-exporter
  ignore_errors: true

- name: Wait for Docker cleanup
  ansible.builtin.pause:
    seconds: 3
```


---

### 3. Template nginx.conf.j2

Corriger la syntaxe HTTP/2 (Nginx 1.25+) :

```nginx
# Ancienne syntaxe (dépréciée)
listen 443 ssl http2;

# Nouvelle syntaxe
listen 443 ssl;
http2 on;
```


---

## Prévention

### Checklist de déploiement

- [ ] Vérifier que le rôle `pki_ca` s'exécute **avant** `nginx_reverse_proxy`
- [ ] Valider que les certificats sont des fichiers (pas des répertoires)
- [ ] Tester la syntaxe Nginx avant déploiement : `nginx -t`
- [ ] Vérifier les bind mounts Docker avec `docker inspect`
- [ ] Tester l'idempotence du playbook (ré-exécution sans erreur)

---

### Commandes de debug Docker

```bash
# Logs en temps réel
docker logs -f nginx-reverse-proxy

# Test de configuration sans démarrer
docker run --rm -v /data/nginx/config/nginx.conf:/etc/nginx/nginx.conf:ro \
  nginx:1.25-alpine nginx -t

# Inspection des volumes
docker inspect nginx-reverse-proxy | jq '..Mounts'

# État détaillé du conteneur
docker inspect nginx-reverse-proxy --format='{{.State.Status}}: {{.State.Error}}'
```


---

## Références

- [Documentation Nginx SSL](https://nginx.org/en/docs/http/configuring_https_servers.html)
- [OpenSSL PEM format](https://www.openssl.org/docs/man1.1.1/man1/x509.html)
- [Docker bind mounts](https://docs.docker.com/storage/bind-mounts/)
- [Ansible docker_compose_v2](https://docs.ansible.com/ansible/latest/collections/community/docker/docker_compose_v2_module.html)

---

**Auteur** : Équipe DevSecOps Lab
**Dernière mise à jour** : 20/01/2026
EOF

```

## Ajout au dépôt Git

```bash
cd ~/Documents/Projet_infra_devops

git add docs/troubleshooting-nginx-reverse-proxy.md
git commit -m "docs: ajout troubleshooting déploiement Nginx reverse proxy

- Résolution crash loop conteneur (certificats en répertoires)
- Correction erreurs syntaxe YAML Ansible
- Correction syntaxe nginx.conf (accolades manquantes)
- Procédure de génération certificats SSL
- Checklist de prévention et commandes debug"

git push
```

**Documentation SSOT créée** ✅
<span style="display:none">[^1][^2][^3][^4][^5][^6]</span>

<div align="center">⁂</div>

[^1]: Copie-d-ecran_20260120_190945-1.jpg

[^2]: Copie-d-ecran_20260120_191008.jpg

[^3]: Copie-d-ecran_20260120_191419.jpg

[^4]: Copie-d-ecran_20260120_191815-1.jpg

[^5]: Copie-d-ecran_20260120_191910.jpg

[^6]: Copie-d-ecran_20260120_192029.jpg

