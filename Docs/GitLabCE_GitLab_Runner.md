GitLab CE + GitLab Runner

Dépannage, fiabilisation et mise en conformité SSOT / TLS

Date : 02/02/2026
Contexte : plateforme DevOps interne (GitLab CE derrière reverse-proxy Nginx, PKI interne, CI/CD sécurisée)


---

1. Objectif de l’intervention

Stabiliser et fiabiliser le déploiement GitLab CE + GitLab Runner via Ansible/Docker en assurant :

cohérence DNS / reverse-proxy / TLS

suppression de dépendances obsolètes (Ansible Vault)

idempotence réelle du rôle Ansible

confiance TLS du runner vers GitLab (CA interne)

rollback sécurisé (git tag)



---

2. Architecture cible (rappel)

GitLab CE :

VM : git-lab → 172.16.100.40

Exposé uniquement via reverse-proxy


Reverse-proxy Nginx :

IP : 172.16.100.253

FQDN : git-lab.lab.local


DNS interne (Bind9) :

git-lab.lab.local → 172.16.100.253


PKI interne :

Lab Root CA


GitLab Runner :

Docker executor

Doit faire confiance au certificat TLS GitLab



👉 Aucune IP hardcodée côté GitLab / Runner


---

3. Problèmes rencontrés

3.1 Variables Ansible manquantes

Plusieurs variables héritées d’anciens choix bloquaient la convergence :

gitlab_root_password

gitlab_ip

gitlab_ssh_port

gitlab_redis_maxmemory

gitlab_runner_token


➡️ Ces variables :

n’étaient plus cohérentes avec la SSOT actuelle

provenaient historiquement d’Ansible Vault (désormais supprimé)



---

3.2 Dépendance Vault fantôme

Le rôle faisait référence à :

../secrets/gitlab.yml

tokens et secrets non présents sur la machine


➡️ Résultat :

erreurs systématiques

impossibilité de relancer le playbook ailleurs



---

3.3 Blocage sur wait_for HTTPS

Le rôle attendait l’ouverture du port 443 :

le service était déjà disponible

mais la task wait_for bloquait (timeout / contexte réseau)


➡️ Faux positif de blocage


---

3.4 Conflit Docker (gitlab-runner)

Après modification du docker-compose.yml :

le conteneur gitlab-runner existait déjà

Docker refusait la recréation (nom déjà utilisé)


➡️ Intervention manuelle unique requise


---

4. Actions correctives appliquées

4.1 Nettoyage SSOT (Ansible)

Suppression de toute dépendance à Vault

Utilisation exclusive des variables :

gitlab_fqdn

gitlab_scheme

gitlab_workhorse_port


Ajout de default() pour les paramètres non critiques
(ex: Redis maxmemory)


👉 Le rôle devient portable et relançable partout


---

4.2 Suppression de gitlab_ip

Variable incohérente avec :

DNS

reverse-proxy

bonnes pratiques infra



➡️ Remplacée conceptuellement par :

FQDN + ports

résolution réseau Docker



---

4.3 GitLab Runner : suppression du token Ansible

gitlab_runner_token supprimé du template

plus d’enregistrement automatique du runner


Choix volontaire DevSecOps :

token court-vécu

pas stocké dans Git

pas injecté par Ansible


👉 Enregistrement du runner manuel via l’UI GitLab


---

4.4 Confiance TLS du Runner (CA interne)

Ajout d’un bind mount :

/srv/gitlab/runner/certs → /etc/gitlab-runner/certs (ro)

Résultat :

le runner fait confiance au certificat GitLab

plus d’erreurs TLS lors des jobs CI



---

4.5 Conflit Docker (résolu proprement)

Action unique et contrôlée :

docker rm -f gitlab-runner

Puis relance du playbook → convergence OK.


---

5. Validations effectuées

5.1 Services Docker

gitlab         Up (healthy)
gitlab-runner  Up (healthy)

5.2 Bind mount CA

/srv/gitlab/runner/certs:/etc/gitlab-runner/certs:ro

5.3 Accès HTTPS

curl -I https://git-lab.lab.local
# HTTP/2 302

5.4 Réseau

nc -vz git-lab.lab.local 443
# succeeded


---

6. Git – traçabilité & rollback

Commit explicite :


gitlab: fix role vars, remove vault dependency, mount CA into runner

Tag de rollback :


gitlab-runner-ca-20260202-1840

➡️ Rollback immédiat possible si nécessaire.


---

7. État final

✅ GitLab CE fonctionnel
✅ GitLab Runner opérationnel
✅ TLS validé (PKI interne)
✅ Rôle Ansible relançable / idempotent
✅ Plus aucune dépendance Vault
✅ Conforme DevSecOps / SSOT


---

8. Prochaines étapes recommandées

Enregistrement manuel du runner dans l’UI GitLab

Ajout des premiers pipelines CI (lint, test, security, build)

Monitoring runner (Prometheus)

Documentation “Procédure d’enregistrement Runner”



---

