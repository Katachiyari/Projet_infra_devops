Parfait.
Voici **la démarche complète, propre et jury-compatible** pour **relier Harbor (172.16.100.50 – harbor.lab.local) à GitLab**, en expliquant **le pourquoi**, **le comment**, et **ce que cela apporte**.

Je structure en **3 niveaux** : architecture → configuration → justification sécurité.

---

# 1️⃣ Principe d’architecture (à expliquer au jury)

## Rôle de Harbor dans l’architecture

Harbor est utilisé comme **registre de conteneurs d’entreprise** (OCI registry) pour :

* stocker les images construites par GitLab CI/CD
* appliquer des politiques de sécurité (scan, rétention)
* éviter l’usage direct de Docker Hub en production

### Flux logique

```
GitLab CI/CD
   └── GitLab Runner
         └── docker build
         └── docker push
               └── Harbor (harbor.lab.local)
```

👉 **GitLab ne “parle pas directement” à Harbor**
👉 **Le Runner CI/CD est l’acteur technique** qui pousse les images

---

# 2️⃣ Prérequis (déjà OK chez toi)

D’après ton contexte :

| Élément                   | État                 |
| ------------------------- | -------------------- |
| Harbor déployé            | ✅                    |
| Harbor accessible via DNS | ✅ `harbor.lab.local` |
| TLS actif (auto-signé)    | ✅                    |
| GitLab Runner fonctionnel | ✅                    |
| Réseau interne commun     | ✅                    |

Il ne reste **qu’une intégration CI/CD**.

---

# 3️⃣ Intégration Harbor ↔ GitLab (méthode recommandée)

## 3.1 Création du projet Harbor

Sur Harbor (UI) :

* **Projet** : `gitlab-builds`
* **Visibilité** : Private
* **Scan à l’upload** : Activé (si Trivy)
* **Rétention** : Activée (optionnel mais pro)

👉 Tu l’as déjà prévu dans tes variables :

```yaml
harbor_project: "gitlab-builds"
```

---

## 3.2 Compte technique Harbor (best practice)

Créer un **robot account** ou utilisateur dédié :

* Nom : `gitlab-ci`
* Permissions :

  * `push`
  * `pull`
* Portée : projet `gitlab-builds`

📌 **Jamais utiliser un compte admin** (point DevSecOps important).

---

## 3.3 Stockage des secrets dans GitLab (obligatoire)

Dans GitLab → **Settings → CI/CD → Variables**

Ajouter :

| Variable          | Type     | Valeur             |
| ----------------- | -------- | ------------------ |
| `HARBOR_URL`      | variable | `harbor.lab.local` |
| `HARBOR_PROJECT`  | variable | `gitlab-builds`    |
| `HARBOR_USERNAME` | masked   | `gitlab-ci`        |
| `HARBOR_PASSWORD` | masked   | ****               |

👉 **Ne jamais les mettre dans le repo**
👉 Le jury attend exactement ce point

---

# 4️⃣ Configuration du pipeline GitLab (`.gitlab-ci.yml`)

## Exemple minimal et propre (à présenter au jury)

```yaml
image: docker:27

services:
  - docker:27-dind

variables:
  DOCKER_TLS_CERTDIR: ""
  IMAGE_TAG: "$CI_COMMIT_SHORT_SHA"

stages:
  - build
  - push

before_script:
  - echo "$HARBOR_PASSWORD" | docker login \
      -u "$HARBOR_USERNAME" \
      --password-stdin \
      "$HARBOR_URL"

build-image:
  stage: build
  script:
    - docker build -t "$HARBOR_URL/$HARBOR_PROJECT/app:$IMAGE_TAG" .

push-image:
  stage: push
  script:
    - docker push "$HARBOR_URL/$HARBOR_PROJECT/app:$IMAGE_TAG"
```

📌 **Points importants à expliquer** :

* `docker login` dynamique
* aucune donnée sensible dans le fichier
* tag basé sur le commit (traçabilité)

---

# 5️⃣ Gestion du certificat Harbor (auto-signé)

### Cas 1 – Certificat auto-signé (ton cas)

Deux options acceptables :

#### Option A (rapide – formation / lab)

Dans le Runner (daemon Docker) :

```json
{
  "insecure-registries": ["harbor.lab.local"]
}
```

📌 À documenter comme **exception temporaire**.

#### Option B (recommandée en prod)

* Import du CA Harbor dans :

  * `/etc/docker/certs.d/harbor.lab.local/ca.crt`
* Redémarrage Docker

👉 **Très bon point jury si mentionné**

---

# 6️⃣ Mise à jour du schéma d’architecture (commentaire)

### Bloc à ajouter au schéma

```
GitLab Runner
   └── CI/CD Jobs
         ├── docker build
         └── docker push
                └── Harbor Registry
                     - Projets privés
                     - Scan de vulnérabilités
                     - Rétention
```

### Commentaire associé (oral / écrit)

> « GitLab est utilisé comme orchestrateur CI/CD.
> Les images produites ne sont jamais stockées localement ni sur Docker Hub,
> mais poussées vers un registre interne Harbor, renforçant la sécurité,
> la traçabilité et la conformité. »

---

# 7️⃣ Points DevSecOps à valoriser devant le jury

| Sujet                         | Argument               |
| ----------------------------- | ---------------------- |
| Séparation des rôles          | GitLab ≠ Registry      |
| Secrets                       | Variables CI/CD        |
| Principe du moindre privilège | Compte Harbor dédié    |
| Traçabilité                   | Tag commit             |
| Sécurité réseau               | TLS + DNS interne      |
| Industrialisation             | Pipeline reproductible |

---

# 8️⃣ Conclusion claire (à dire au jury)

> « GitLab est le moteur CI/CD, Harbor est le registre d’entreprise.
> Le Runner agit comme agent technique entre les deux.
> Cette séparation respecte les bonnes pratiques DevSecOps
> et permet une montée en charge maîtrisée. »

---