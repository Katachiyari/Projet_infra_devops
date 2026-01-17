# Ansible Role: pki_ca

Rôle Ansible dédié à la **Mission 0 : PKI CA locale** pour le domaine `lab.local`.

## Objectifs

- Générer la CA Root locale (`lab-root-ca`)
- Générer un certificat wildcard `*.lab.local`
- Générer des certificats serveurs spécifiques (harbor, gitlab, portainer, ...)
- Installer la CA Root dans le trust store système
- Mettre en place un script de renouvellement automatisable
- Assurer des permissions strictes et un backup de la clé privée CA

## Structure générée

Par défaut, le rôle crée la structure suivante :

```text
/opt/ca/
├── root-ca.key          # Clé privée CA (4096 bits) - SENSIBLE
├── root-ca.crt          # Certificat CA Root (public)
├── wildcard.lab.local.key
├── wildcard.lab.local.csr
├── wildcard.lab.local.crt
├── wildcard.lab.local.ext
├── harbor.lab.local.key
├── harbor.lab.local.csr
├── harbor.lab.local.crt
├── gitlab.lab.local.key
├── gitlab.lab.local.csr
├── gitlab.lab.local.crt
├── portainer.lab.local.key
├── portainer.lab.local.csr
├── portainer.lab.local.crt
├── renew_certs.sh       # Script de renouvellement
└── certs/
    └── README.md

/backup/ca/
└── root-ca.key          # Backup de la clé privée CA
```

Les chemins et durées de validité sont configurables via `defaults/main.yml`.

## Utilisation

1. Définir un groupe d'hôtes PKI dans votre inventaire (exemple) :

```yaml
pki_ca_hosts:
  hosts:
    pki-ca-1.lab.local:
      ansible_host: 172.16.100.10
```

2. Lancer le playbook dédié Mission 0 :

```bash
cd Ansible
ansible-playbook playbooks/pki_ca.yml
```

3. Le rôle est idempotent : relancer le playbook ne régénère pas les clés/certificats existants.

## Variables principales

Voir `defaults/main.yml` pour la liste complète. Exemples importants :

- `pki_ca_root_dir` (défaut: `/opt/ca`)
- `pki_ca_backup_dir` (défaut: `/backup/ca`)
- `pki_ca_root_validity_days` (10 ans)
- `pki_ca_server_validity_days` (825 jours)
- `pki_ca_server_certificates` (liste des certificats serveurs à générer)

## Validation

Le rôle inclut un fichier `tasks/validation.yml` qui :

- Vérifie la présence de la CA Root dans le trust store (`/usr/local/share/ca-certificates/lab-root-ca.crt`)
- Valide la chaîne de confiance du certificat wildcard `*.lab.local`
- Valide la chaîne de confiance de tous les certificats serveurs déclarés.

Pour des tests applicatifs (ex: `https://harbor.lab.local`), les playbooks des rôles Nginx/Harbor devront ajouter leurs propres tâches `uri:` une fois déployés.
