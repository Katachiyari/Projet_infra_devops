réinitialisation du compte admin Harbor

---

# 🔐 Récupération du compte administrateur Harbor (Docker)

## 🎯 Objectif

Permettre la **reprise de contrôle du compte `admin` Harbor** lorsque :

* le mot de passe par défaut ne fonctionne plus,
* le déploiement a été automatisé (Ansible / Docker),
* aucun accès UI administrateur n’est possible.

Cette procédure est **non destructive**, **traçable**, et **adaptée à un contexte DevSecOps**.

---

## 🧠 Fondamentaux à comprendre (important)

### 🔹 1. Où Harbor stocke les comptes ?

Harbor stocke les utilisateurs **dans sa base PostgreSQL interne**, table :

```
public.harbor_user
```

Champs critiques :

* `username`
* `password` → **hash SHA1 (40 caractères)**
* `salt` → **16 caractères hexadécimaux**
* `sysadmin_flag` → doit être `true` pour `admin`

👉 **Harbor ne stocke PAS les mots de passe en bcrypt** (contrairement à GitLab).

---

### 🔹 2. Algorithme utilisé par Harbor

Harbor utilise historiquement :

```
SHA1(password + salt)
```

➡️ Le hash final doit faire **exactement 40 caractères**
➡️ Le `salt` doit faire **16 caractères**

---

### 🔹 3. Ordre de démarrage critique

Harbor utilise **rsyslog via TCP 1514**.

➡️ Le service `harbor-log` **doit être démarré en premier**, sinon :

* les conteneurs échouent,
* erreurs `failed to initialize logging driver`.

---

## 🛠️ Procédure pas à pas

### ✅ Étape 1 — Accès à la base PostgreSQL Harbor

```bash
sudo docker exec -it harbor-db psql -U postgres
```

Puis :

```sql
\c registry
\pset pager off
```

Vérifier l’utilisateur admin :

```sql
SELECT user_id, username, sysadmin_flag
FROM public.harbor_user
WHERE username = 'admin';
```

---

### ✅ Étape 2 — Génération d’un nouveau mot de passe

#### 2.1 Définir le mot de passe

```bash
NEW_PASS='Harbor-Admin-CHANGE-ME-2026!'
```

#### 2.2 Générer le salt

```bash
SALT="$(openssl rand -hex 8)"
echo "$SALT"
```

➡️ Doit faire **16 caractères**

#### 2.3 Générer le hash SHA1

```bash
HASH="$(printf '%s' "${NEW_PASS}${SALT}" | sha1sum | awk '{print $1}')"
echo "$HASH"
echo -n "$HASH" | wc -c
```

➡️ Résultat attendu : **40**

---

### ✅ Étape 3 — Mise à jour du compte admin

Dans `psql` :

```sql
UPDATE public.harbor_user
SET password = 'HASH_GENERE',
    salt     = 'SALT_GENERE'
WHERE username = 'admin';

SELECT username,
       length(password) AS pwd_len,
       length(salt)     AS salt_len,
       sysadmin_flag
FROM public.harbor_user
WHERE username = 'admin';
```

✔️ Attendus :

* `pwd_len = 40`
* `salt_len = 16`
* `sysadmin_flag = t`

Quitter :

```sql
\q
```

---

### ✅ Étape 4 — Redémarrage propre de Harbor (CRITIQUE)

```bash
cd /opt/harbor/harbor
```

#### 4.1 Arrêt complet

```bash
sudo docker compose down
```

#### 4.2 Démarrage du service de logs en premier

```bash
sudo docker compose up -d log
sudo ss -lntp | grep ':1514'
```

➡️ Le port **1514** doit être **LISTEN**

#### 4.3 Démarrage du reste de la stack

```bash
sudo docker compose up -d
sudo docker compose ps
```

---

### ✅ Étape 5 — Connexion UI

* 🌐 URL : `http://harbor.lab.local`
* 👤 Utilisateur : `admin`
* 🔑 Mot de passe : celui défini à l’étape 2

---

## 🔐 Bonnes pratiques DevSecOps (à retenir)

* ❌ Ne jamais laisser le mot de passe admin par défaut
* ✅ Changer immédiatement le mot de passe après récupération
* ✅ Stocker les secrets dans :

  * GitLab CI Variables (masked / protected)
  * ou un coffre (Vault, SOPS, etc.)
* ✅ Documenter les procédures de reprise (PRA / runbook)

---

## 🧾 À intégrer dans la documentation finale

Cette procédure doit apparaître dans :

* 📄 **Runbook Harbor**
* 📄 **Documentation Étape 1 — Base CI/CD**
* 📄 **Justification sécurité (jury)**

---

Quand tu veux, on peut :

* 🔜 transformer cette procédure en **runbook officiel**
* 🔜 l’intégrer au **README d’architecture**
* 🔜 automatiser la rotation du mot de passe via **Ansible**

👉 Dis simplement **“suivant”**.
