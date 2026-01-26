# Résolution : EdgeDoc (HedgeDoc) en 502 Bad Gateway + Healthcheck instable ✅

## Contexte 🧭
EdgeDoc (HedgeDoc) est exposé via un reverse-proxy Nginx en HTTPS sur :
- `https://edgedoc.lab.local`

Le backend réel est publié sur la VM `tools-manager` :
- `172.16.100.20:8080` (hôte) → `3000` (conteneur HedgeDoc)

Symptôme côté navigateur / reverse-proxy :
- **502 Bad Gateway** 😵

## Symptômes observés 🔎

### 1) Côté reverse-proxy
Erreur Nginx typique :
- `connect() failed (111: Connection refused) while connecting to upstream`

Cela signifie :
- Nginx a bien résolu le backend,
- mais **le backend refuse la connexion** (service down / crash / pas prêt).

### 2) Côté tools-manager (Docker)
- Le conteneur HedgeDoc démarrait puis redevenait instable (health: starting / exit).
- Les logs montraient une incapacité à joindre la DB :
  - `Access denied` (mauvais mot de passe) ou `ECONNREFUSED` (DB pas encore prête).

## Fondamentaux à comprendre 🧠

### A) Un 502 Nginx = problème en amont, pas un bug “DNS” 🌐
Le reverse-proxy est un intermédiaire :
- si l’application en amont ne répond pas, Nginx renvoie 502.

Donc la méthode :
1. Vérifier le backend directement (sans Nginx),
2. Puis seulement après valider le FQDN HTTPS.

### B) Un healthcheck doit valider un endpoint “garanti” 🩺
Un healthcheck est un test automatique de santé.
Erreur classique :
- utiliser un endpoint non garanti par l’application (`/api/status` → 404).

Conclusion :
- un healthcheck fiable doit tester un endpoint stable comme `/` (page principale).

### C) Secrets en clair = risque DevSecOps 🔐
Des mots de passe en dur dans Git :
- exposent l’infrastructure,
- rendent les audits jurys défavorables,
- compliquent la rotation.

Solution :
- stocker les secrets dans **Ansible Vault**.

### D) “Pinning” des images = reproductibilité + rollback 📌
Utiliser `:latest` est instable :
- la version peut changer sans prévenir.

Bonne pratique :
- pinner une version (`:1.9.9`) ou un digest (`@sha256:...`).

## Diagnostic pas à pas 🧪

### 1) Tester le backend sans reverse-proxy
Depuis la VM reverse-proxy ou un poste de contrôle :
```bash
curl -I http://172.16.100.20:8080/ | head
