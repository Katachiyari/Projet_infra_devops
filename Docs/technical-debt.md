# Évaluation de la dette technique (21/01/2026)

## Synthèse par gravité

### Élevée
- **Secrets & états dans le repo** : `terraform.tfstate*`, `terraform.tfvars*`, mots de passe/clefs non vaultés. Risque de fuite et dérive d’état.
- **TLS non fiable** : certificats auto-signés sans fullchain ; validation TLS contournée (Harbor). Besoin d’une PKI interne ou AC publique.
- **Taiga non idempotent** : corrections manuelles (conf.json dans le conteneur) non gérées par Ansible → risque de régression à chaque redeploy.
- **Compose v3 avec warnings** : « version is obsolete » pour reverse-proxy/EdgeDoc, masquant d’autres problèmes et limitant l’usage de features récentes.
- **Pas de CI/CD ni lint** : pas de terraform fmt/validate, ansible-lint, yamllint ou tests de convergence avant déploiement.

### Moyenne
- **Images non durcies** : nginx et autres tournent souvent en root ; pas d’image hardened (Chainguard/IronBank/custom), ports privilégiés non traités.
- **Secrets en clair** : mots de passe DB EdgeDoc, session secret, variables exposées dans defaults/host_vars et logs.
- **Config réseau dupliquée** : backends définis en defaults + host_vars pour le reverse-proxy → risque d’incohérence.
- **Observabilité limitée** : pas de logs centralisés (ELK/Loki) ni métriques applicatives (hors exporter Nginx).
- **Sécurité HTTP** : headers présents au proxy, mais CORS/cookies/app non audités pour Taiga/EdgeDoc.
- **Backups non automatisés** : procédures manuelles, pas de scheduling ni tests de restauration.

### Faible
- **Versions figées sans plan d’upgrade** : nginx 1.25, mariadb 10.11, postgres 12.3, rabbitmq 3.8.
- **Factorisation Ansible faible** : TLS mutualisable, templating conf.json Taiga, gestion d’images.
- **Documentation partielle** : SSOT tools-manager OK, reste à aligner Terraform/Proxmox, cloud-init, bind9.

## Chantiers de réduction (priorisés)
1) **Sécurité & secrets** : sortir tfstate/tfvars et secrets du VCS ; Ansible Vault ; PKI interne ou Let’s Encrypt DNS-01 ; distribuer/importer la root CA ou fullchain valide.
2) **Idempotence Taiga** : rôle Ansible pour la stack + templating conf.json (API/WS en HTTPS) ; supprimer les edits en conteneur.
3) **Hardening images** : variable `nginx_image` pour image hardened ; exécution non-root ; ports non privilégiés si besoin.
4) **CI/CD & lint** : pipeline terraform fmt/validate, ansible-lint, yamllint, docker compose config ; tests curl via proxy post-deploy.
5) **Backups auto** : cron/Ansible pour dumps MariaDB/PostgreSQL + archives de volumes (EdgeDoc uploads, Taiga static) vers stockage externe ; playbook de restauration testé.
6) **Nettoyage repo** : retirer tfstate/tfplan/tfvars du dépôt, renforcer `.gitignore`, documenter backend distant Terraform.
7) **Observabilité** : centraliser logs (Loki/ELK) ; exposer métriques app (Taiga `/api/v1/stats`, HedgeDoc `/api/status`) ; alertes basiques (conteneur down, disque >80%, queues RabbitMQ).
8) **Plan d’upgrade** : cycle de mises à jour pour nginx/mariadb/postgres/rabbitmq et tests en staging.
