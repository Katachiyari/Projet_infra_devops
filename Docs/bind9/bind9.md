# 🌐 Bind9 : DNS interne du lab (SSOT)


***

## 📍 Explication : DNS et Bind9

### Définition

**Bind9** (Berkeley Internet Name Domain version 9) est le serveur DNS le plus utilisé au monde. Il permet de résoudre des noms de domaine en adresses IP au sein d'un réseau local, évitant ainsi de dépendre uniquement de DNS publics (Google, Cloudflare).

### Comparaison des solutions DNS

| Solution | Type | Complexité | Performance | Web UI | Usage |
| :-- | :-- | :-- | :-- | :-- | :-- |
| **Bind9** | Serveur complet | Moyenne | Excellente | ❌ Non | Production (standard) |
| **dnsmasq** | DNS+DHCP léger | Faible | Bonne | ❌ Non | Petit réseau |
| **Pi-hole** | DNS+Blocage pub | Faible | Bonne | ✅ Oui | Home/SOHO |
| **PowerDNS** | Serveur moderne | Élevée | Excellente | ✅ Oui (API) | Entreprise |
| **Unbound** | Valideur DNSSEC | Moyenne | Excellente | ❌ Non | Sécurité avancée |

### Rôle dans l'architecture réseau

```
┌─────────────────────────────────────────────────────────────┐
│ Architecture DNS Centralisée (Bind9)                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  VM : dns-server (172.16.100.254)                          │
│  ├─ Bind9 (port 53 UDP/TCP)                                │
│  ├─ Zone : lab.local (zone interne)                        │
│  └─ Forwarders : 1.1.1.1, 9.9.9.9 (ex: Cloudflare/Quad9)   │
│                                                             │
│  Toutes VMs → DNS : 172.16.100.254                         │
│  ├─ harbor.lab.local → 172.16.100.253                      │
│  ├─ git-lab.lab.local → 172.16.100.253                     │
│  ├─ grafana.lab.local → 172.16.100.253                     │
│  └─ *.lab.local → Résolution interne                       │
│                                                             │
│  Requêtes externes (google.com, github.com)                │
│  └─ Forward vers DNS publics (ex: 1.1.1.1/9.9.9.9)          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```


***

## 📍 Cycle de vie : Bind9

## ✅ Ce qui est vrai dans ce projet (SSOT)

Source de vérité (zones + records) :
- `Ansible/inventory/host_vars/bind9dns.yml`

Serveur DNS :
- host inventory : `bind9dns`
- IP : `172.16.100.254`

Reverse-proxy (cible des FQDN `*.lab.local`) :
- IP : `172.16.100.253`

Zones gérées :
- `lab.local` (services exposés via reverse-proxy)
- `jdk.lab` (zone interne de test/historique)


### Phase 1 : Provisionnement VM DNS (Terraform)

```
1. Création VM dns-server
   └─> Terraform provisionne VM
       ├─> Hostname : dns-server
       ├─> IP statique : 172.16.100.254
       ├─> CPU : 1 core
       ├─> RAM : 1 GB
       └─> Disk : 20 GB

2. Cloud-init configure réseau
   └─> IP : 172.16.100.254/24
   └─> Gateway : 172.16.100.1
   └─> DNS temporaire : 1.1.1.1 (Cloudflare)

3. VM disponible
   └─> Accessible via SSH
   └─> Prête pour Ansible
```


### Phase 2 : Installation Bind9 (Ansible)

```
1. Installation packages
   └─> apt install bind9 bind9utils bind9-doc dnsutils

2. Configuration fichier principal
   └─> /etc/bind/named.conf.options
       ├─> Listen : 172.16.100.254 + localhost
       ├─> Allow-query : 172.16.100.0/24 (réseau local)
       ├─> Forwarders : 1.1.1.1, 9.9.9.9 (ex: Cloudflare/Quad9)
       ├─> DNSSEC : validation auto
       └─> Recursion : enabled (serveur récursif)

3. Configuration zones
   └─> /etc/bind/named.conf.local
       ├─> Zone directe : lab.local (A, CNAME records)
       └─> Zone inverse : 100.16.172.in-addr.arpa (PTR records)

4. Création fichier zone
   └─> /var/lib/bind/db.lab.local
       ├─> SOA (Start of Authority)
       ├─> NS (Name Server)
       ├─> A records (IPv4)
       ├─> CNAME records (alias)
       └─> MX records (mail, optionnel)

5. Validation configuration
   └─> named-checkconf (syntax config)
   └─> named-checkzone lab.local db.lab.local (syntax zone)

6. Redémarrage Bind9
   └─> systemctl restart bind9
```


### Phase 3 : Configuration Clients (Cloud-init + Ansible)

```
1. Cloud-init configure resolv.conf au boot
   └─> /etc/resolv.conf
       ├─> nameserver 172.16.100.254
       ├─> nameserver 1.1.1.1 (fallback)
       └─> search lab.local

2. Ansible ajuste systemd-resolved (Ubuntu 24.04)
   └─> /etc/systemd/resolved.conf
       ├─> DNS=172.16.100.254 1.1.1.1
       ├─> FallbackDNS=9.9.9.9
       └─> Domains=lab.local

3. Test résolution
   └─> dig git-lab.lab.local @172.16.100.254
   └─> nslookup harbor.lab.local
   └─> ping grafana.lab.local
```


### Phase 4 : Ajout Nouveaux Enregistrements (Maintenance)

```
1. Édition fichier zone (SSOT)
   └─> Ansible/inventory/host_vars/bind9dns.yml
       └─> Ajout nouvel enregistrement :
           - name: "newapp"
             type: A
             value: "172.16.100.50"

2. Ansible génère nouveau fichier zone
   └─> Template db.lab.local.j2
   └─> Incrément serial (YYYYMMDDNN)

3. Validation et reload
   └─> named-checkzone lab.local db.lab.local
   └─> rndc reload lab.local (reload zone sans restart)

4. Test résolution
   └─> dig newapp.lab.local @172.16.100.254
   └─> Cache DNS propagé immédiatement
```


***

## 📍 Architecture Bind9 Détaillée

### Diagramme de flux DNS

```
┌─────────────────────────────────────────────────────────────┐
│ Client VM (gitlab.lab.local)                                │
├─────────────────────────────────────────────────────────────┤
│ • Application demande : harbor.lab.local                    │
│ • OS consulte /etc/resolv.conf → 172.16.100.254            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Query DNS (UDP 53)
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ dns-server (172.16.100.254) - Bind9                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Requête reçue : harbor.lab.local ?                     │
│     └─> Check cache local                                   │
│         ├─> Si en cache → Réponse immédiate                │
│         └─> Si absent → Suite processus                     │
│                                                             │
│  2. Check zone locale (lab.local)                          │
│     └─> /var/lib/bind/db.lab.local                         │
│         ├─> harbor IN A 172.16.100.253 ✓ TROUVÉ             │
│         └─> Réponse : 172.16.100.253                        │
│                                                             │
│  3. Mise en cache (TTL 3600s)                              │
│     └─> Prochaine requête servie depuis cache              │
│                                                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Réponse DNS : 172.16.100.253
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Client VM reçoit IP                                         │
├─────────────────────────────────────────────────────────────┤
│ • Application se connecte à 172.16.100.253                  │
│ • Communication établie avec Harbor                         │
└─────────────────────────────────────────────────────────────┘
```


### Cas : Requête Externe (google.com)

```
┌─────────────────────────────────────────────────────────────┐
│ Client VM demande : google.com                              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Query DNS
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ dns-server (Bind9)                                          │
├─────────────────────────────────────────────────────────────┤
│  1. Check zone locale : google.com                          │
│     └─> Pas dans zone lab.local                            │
│                                                             │
│  2. Forward vers DNS public (Cloudflare)                   │
│     └─> Query → 1.1.1.1                                     │
│         └─> Réponse : 142.250.201.46 (Google IP)           │
│                                                             │
│  3. Cache réponse (TTL du domaine externe)                 │
│     └─> Prochaines requêtes servies depuis cache           │
│                                                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Réponse : 142.250.201.46
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Client VM se connecte à Internet                            │
└─────────────────────────────────────────────────────────────┘
```


### Résolution Inverse (PTR)

```
┌─────────────────────────────────────────────────────────────┐
│ Application demande : nom de 172.16.100.2 ?                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Query PTR : 2.100.16.172.in-addr.arpa
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ dns-server (Bind9)                                          │
├─────────────────────────────────────────────────────────────┤
│  Zone inverse : 100.16.172.in-addr.arpa                    │
│  └─> 2 IN PTR harbor.lab.local.                            │
│      └─> Réponse : harbor.lab.local                        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Réponse : harbor.lab.local
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Application reçoit hostname                                 │
└─────────────────────────────────────────────────────────────┘
```


***

## 🛠️ Runbook (opérationnel)

### 1) Déployer / mettre à jour Bind9

Selon ton mode de déploiement :

```bash
cd Ansible
# Mode conteneur (rôle bind9_docker)
ansible-playbook -i inventory/hosts.yml playbooks/bind9-container.yml --limit bind9_hosts
```

Ou :

```bash
cd Ansible
# Mode VM (rôle systemli.bind9)
ansible-playbook -i inventory/hosts.yml playbooks/bind9-docker.yml --limit bind9_hosts
```

### 2) Modifier un enregistrement DNS (SSOT)

1. Édite `Ansible/inventory/host_vars/bind9dns.yml`
2. Incrémente le `serial` de la zone (`YYYYMMDDNN`)
3. Relance le playbook (voir ci-dessus)

### 3) Vérifier la résolution

```bash
dig +short @172.16.100.254 harbor.lab.local
dig +short @172.16.100.254 git-lab.lab.local
dig +short @172.16.100.254 registry.gitlab.lab.local
```

Attendu : `172.16.100.253` pour les services exposés via reverse-proxy.

## 📍 Fichiers Configuration Bind9

### Fichier 1 : `/etc/bind/named.conf.options` (Config principale)

**Chemin** : `/etc/bind/named.conf.options`
**Rôle** : Options globales Bind9
**Généré** : ✅ Ansible template

```bind
// ===================================================================
// Configuration Bind9 (généré par Ansible)
// ===================================================================

options {
    // Répertoire de travail
    directory "/var/cache/bind";

    // ================================================================
    // Écoute réseau (listen)
    // ================================================================
    listen-on port 53 { 
        127.0.0.1;           // Localhost
        172.16.100.254;      // IP VM dns-server
    };
    
    listen-on-v6 { none; };  // Désactiver IPv6

    // ================================================================
    // Autorisation requêtes (ACL)
    // ================================================================
    allow-query { 
        localhost;           // Serveur lui-même
        172.16.100.0/24;     // Réseau production
        172.16.200.0/24;     // Réseau DMZ (si applicable)
    };
    
    allow-recursion { 
        localhost;
        172.16.100.0/24;
    };
    
    allow-transfer { none; };  // Pas de transfert zone (pas de slave)

    // ================================================================
    // DNS Forwarders (Cloudflare)
    // ================================================================
    forwarders {
        1.1.1.1;             // Cloudflare Primary
        1.0.0.1;             // Cloudflare Secondary
    };
    
    forward only;            // Toujours forwarder si zone inconnue

    // ================================================================
    // DNSSEC
    // ================================================================
    dnssec-validation auto;  // Validation DNSSEC automatique

    // ================================================================
    // Performance et Cache
    // ================================================================
    max-cache-size 128M;     // Cache DNS 128 MB
    max-cache-ttl 86400;     // TTL max cache 24h
    max-ncache-ttl 3600;     // TTL negative cache 1h
    
    recursion yes;           // Serveur récursif activé
    
    // ================================================================
    // Sécurité
    // ================================================================
    version "Not Disclosed";  // Masquer version Bind9
    hostname none;            // Masquer hostname serveur
    
    // Rate limiting (protection DoS)
    rate-limit {
        responses-per-second 10;
        window 5;
    };
    
    // ================================================================
    // Logs
    // ================================================================
    querylog no;             // Logs requêtes désactivés (performance)
};

// ===================================================================
// Configuration Logs
// ===================================================================
logging {
    channel default_log {
        file "/var/log/bind/bind.log" versions 3 size 10m;
        severity info;
        print-time yes;
        print-severity yes;
        print-category yes;
    };
    
    channel query_log {
        file "/var/log/bind/query.log" versions 3 size 10m;
        severity info;
        print-time yes;
    };
    
    category default { default_log; };
    category queries { query_log; };  // Activer si debug nécessaire
    category security { default_log; };
    category dnssec { default_log; };
};
```


***

### Fichier 2 : `/etc/bind/named.conf.local` (Zones locales)

**Chemin** : `/etc/bind/named.conf.local`
**Rôle** : Déclaration zones DNS locales
**Généré** : ✅ Ansible template

```bind
// ===================================================================
// Zones DNS locales (généré par Ansible)
// ===================================================================

// ===================================================================
// Zone directe : lab.local (résolution nom → IP)
// ===================================================================
zone "lab.local" {
    type master;                       // Serveur maître (autoritaire)
    file "/var/lib/bind/db.lab.local"; // Fichier zone
    allow-update { none; };            // Pas de mise à jour dynamique
    allow-transfer { none; };          // Pas de transfert zone
    notify no;                         // Pas de notification (pas de slave)
};

// ===================================================================
// Zone inverse : 172.16.100.0/24 (résolution IP → nom)
// ===================================================================
zone "100.16.172.in-addr.arpa" {
    type master;
    file "/var/lib/bind/db.172.16.100";
    allow-update { none; };
    allow-transfer { none; };
    notify no;
};

// ===================================================================
// Zone inverse : 172.16.200.0/24 (DMZ - optionnel)
// ===================================================================
zone "200.16.172.in-addr.arpa" {
    type master;
    file "/var/lib/bind/db.172.16.200";
    allow-update { none; };
    allow-transfer { none; };
    notify no;
};
```


***

### Fichier 3 : `/var/lib/bind/db.lab.local` (Fichier zone directe)

**Chemin** : `/var/lib/bind/db.lab.local`
**Rôle** : Enregistrements DNS zone lab.local
**Généré** : ✅ Ansible template

```bind
; ===================================================================
; Zone DNS : lab.local (généré par Ansible)
; Date : 2026-01-17
; ===================================================================

$TTL    3600
@       IN      SOA     dns.lab.local. admin.lab.local. (
                        2026011701      ; Serial (YYYYMMDDNN)
                        3600            ; Refresh (1h)
                        1800            ; Retry (30min)
                        604800          ; Expire (7 jours)
                        86400 )         ; Negative Cache TTL (24h)

; ===================================================================
; Serveur DNS autoritaire
; ===================================================================
@               IN      NS      dns.lab.local.

; ===================================================================
; Enregistrements A (nom → IPv4)
; ===================================================================

; Infrastructure DNS
dns             IN      A       172.16.100.254

; Services principaux
harbor          IN      A       172.16.100.2
registry        IN      CNAME   harbor.lab.local.    ; Alias

tools           IN      A       172.16.100.20
taiga           IN      CNAME   tools.lab.local.
docs            IN      CNAME   tools.lab.local.     ; EdgeDoc

gitlab          IN      A       172.16.100.30
git             IN      CNAME   gitlab.lab.local.    ; Alias court

monitoring      IN      A       172.16.100.40
grafana         IN      CNAME   monitoring.lab.local.
prometheus      IN      CNAME   monitoring.lab.local.
alertmanager    IN      CNAME   monitoring.lab.local.

; ===================================================================
; Enregistrements MX (mail - optionnel)
; ===================================================================
@               IN      MX      10 mail.lab.local.
mail            IN      A       172.16.100.100

; ===================================================================
; Enregistrements TXT (SPF, DKIM - optionnel)
; ===================================================================
@               IN      TXT     "v=spf1 ip4:172.16.100.0/24 -all"

; ===================================================================
; Wildcards (optionnel)
; ===================================================================
; *.dev         IN      A       172.16.100.99    ; Toutes apps dev
```


***

### Fichier 4 : `/var/lib/bind/db.172.16.100` (Zone inverse)

**Chemin** : `/var/lib/bind/db.172.16.100`
**Rôle** : Résolution inverse (IP → nom)
**Généré** : ✅ Ansible template

```bind
; ===================================================================
; Zone inverse : 172.16.100.0/24 (généré par Ansible)
; ===================================================================

$TTL    3600
@       IN      SOA     dns.lab.local. admin.lab.local. (
                        2026011701      ; Serial
                        3600            ; Refresh
                        1800            ; Retry
                        604800          ; Expire
                        86400 )         ; Negative Cache TTL

; ===================================================================
; Serveur DNS autoritaire
; ===================================================================
@               IN      NS      dns.lab.local.

; ===================================================================
; Enregistrements PTR (IP → nom)
; ===================================================================
254             IN      PTR     dns.lab.local.
2               IN      PTR     harbor.lab.local.
20              IN      PTR     tools.lab.local.
30              IN      PTR     gitlab.lab.local.
40              IN      PTR     monitoring.lab.local.
100             IN      PTR     mail.lab.local.
```


***

### Fichier 5 : `/etc/systemd/resolved.conf` (Clients Ubuntu 24.04)

**Chemin** : `/etc/systemd/resolved.conf`
**Rôle** : Configuration DNS client systemd-resolved
**Généré** : ✅ Ansible template

```ini
# ===================================================================
# Configuration systemd-resolved (généré par Ansible)
# ===================================================================

[Resolve]
# Serveurs DNS (ordre de priorité)
DNS=172.16.100.254 1.1.1.1

# DNS fallback (si DNS primaire inaccessible)
FallbackDNS=1.0.0.1 8.8.8.8

# Domaines de recherche
Domains=lab.local

# DNSSEC
DNSSEC=allow-downgrade

# DNS over TLS (DoT)
DNSOverTLS=no

# Cache DNS local
Cache=yes
CacheFromLocalhost=no

# Stub resolver
DNSStubListener=yes
DNSStubListenerExtra=

# LLMNR et MulticastDNS (désactiver pour sécurité)
LLMNR=no
MulticastDNS=no

# Timeout résolution
ReadEtcHosts=yes
ResolveUnicastSingleLabel=no
```

**Application configuration** :

```bash
# Redémarrer systemd-resolved
systemctl restart systemd-resolved

# Vérifier status
resolvectl status

# Tester résolution
resolvectl query harbor.lab.local
```


***

## 📊 Commandes Maintenance Bind9

### 🔍 Diagnostic et Tests

#### Test résolution DNS

```bash
# dig (outil complet)
dig harbor.lab.local @172.16.100.254
dig -x 172.16.100.2 @172.16.100.254  # Résolution inverse
dig gitlab.lab.local +short           # Réponse courte

# nslookup (outil simple)
nslookup harbor.lab.local 172.16.100.254
nslookup 172.16.100.2 172.16.100.254

# host (outil léger)
host harbor.lab.local 172.16.100.254
host 172.16.100.2 172.16.100.254
```


#### Vérifier configuration Bind9

```bash
# Valider syntax fichiers config
named-checkconf

# Valider syntax zone
named-checkzone lab.local /var/lib/bind/db.lab.local
named-checkzone 100.16.172.in-addr.arpa /var/lib/bind/db.172.16.100

# Afficher config effective
named -g  # Mode debug (ne pas utiliser en production)
```


#### Vérifier status service

```bash
# Status systemd
systemctl status bind9

# Logs temps réel
journalctl -u bind9 -f

# Logs fichier
tail -f /var/log/bind/bind.log
tail -f /var/log/bind/query.log  # Si querylog activé

# Statistiques Bind9
rndc stats
cat /var/cache/bind/named.stats
```


***

### 🔄 Gestion Service

#### Contrôle service

```bash
# Démarrer
systemctl start bind9

# Arrêter
systemctl stop bind9

# Redémarrer (coupe connexions)
systemctl restart bind9

# Reload config (sans couper connexions)
systemctl reload bind9
# OU
rndc reload

# Activer au boot
systemctl enable bind9
```


#### Reload zone spécifique

```bash
# Reload une seule zone (sans affecter les autres)
rndc reload lab.local
rndc reload 100.16.172.in-addr.arpa

# Vider cache DNS
rndc flush

# Vider cache zone spécifique
rndc flushname harbor.lab.local
```


***

### 🛠️ Maintenance Avancée

#### Gestion cache DNS

```bash
# Afficher cache DNS
rndc dumpdb -cache
cat /var/cache/bind/named_dump.db

# Vider tout le cache
rndc flush

# Statistiques cache
rndc stats
grep "cache hits" /var/cache/bind/named.stats
```


#### Monitoring requêtes

```bash
# Activer querylog (verbose)
rndc querylog on

# Désactiver querylog
rndc querylog off

# Voir requêtes temps réel
tail -f /var/log/bind/query.log
```


#### Freeze/Thaw zone (maintenance)

```bash
# Freeze zone (empêcher modifications)
rndc freeze lab.local

# Éditer fichier zone manuellement
vim /var/lib/bind/db.lab.local
# Incrémenter serial !

# Thaw zone (réactiver)
rndc thaw lab.local
```


***

### 📈 Performance et Monitoring

#### Statistiques Bind9

```bash
# Afficher statistiques complètes
rndc stats

# Parser statistiques
cat /var/cache/bind/named.stats | grep -A5 "++ Incoming Requests ++"
cat /var/cache/bind/named.stats | grep -A5 "++ Outgoing Queries ++"

# Nombre requêtes par seconde (approximatif)
watch -n 1 'rndc stats && grep "queries" /var/cache/bind/named.stats | tail -n1'
```


#### Test performance

```bash
# Test charge DNS (100 requêtes parallèles)
for i in {1..100}; do
    dig harbor.lab.local @172.16.100.254 &
done
wait

# Benchmark avec dnsperf (installer : apt install dnsperf)
echo "harbor.lab.local A" > query.txt
dnsperf -s 172.16.100.254 -d query.txt -c 10 -l 30
```


***

### 🔐 Sécurité

#### Logs sécurité

```bash
# Rechercher tentatives suspectes
grep "denied" /var/log/bind/bind.log
grep "error" /var/log/bind/bind.log
grep "REFUSED" /var/log/bind/query.log

# Surveiller requêtes récursives externes (potentiel abus)
grep "recursion requested" /var/log/bind/query.log | grep -v "172.16.100"
```


#### Firewall (UFW)

```bash
# Autoriser DNS depuis réseau local uniquement
ufw allow from 172.16.100.0/24 to any port 53 proto udp
ufw allow from 172.16.100.0/24 to any port 53 proto tcp

# Bloquer DNS depuis Internet (si VM exposée)
ufw deny from any to any port 53
```


#### Rate limiting (protection DoS)

```bash
# Vérifier rate-limit dans logs
grep "rate limit" /var/log/bind/bind.log

# Ajuster rate-limit (dans named.conf.options)
# rate-limit {
#     responses-per-second 20;  # Augmenter si légitime
#     window 5;
# };
```


***

### 🔧 Troubleshooting

#### Problème 1 : Zone ne se charge pas

```bash
# Symptôme
rndc reload lab.local
# Erreur : zone lab.local/IN: loading from master file failed

# Diagnostic
named-checkzone lab.local /var/lib/bind/db.lab.local
# Affiche erreur syntax

# Causes fréquentes
# - Serial non incrémenté
# - Oubli point final (harbor.lab.local.)
# - CNAME pointant vers CNAME (interdit)
# - TTL manquant

# Solution
vim /var/lib/bind/db.lab.local
# Corriger erreur
# Incrémenter serial : 2026011701 → 2026011702
rndc reload lab.local
```


#### Problème 2 : Résolution ne fonctionne pas depuis client

```bash
# Symptôme
ping harbor.lab.local
# ping: harbor.lab.local: Name or service not known

# Diagnostic 1 : Tester DNS directement
dig harbor.lab.local @172.16.100.254
# Si fonctionne → Problème client, pas serveur

# Diagnostic 2 : Vérifier /etc/resolv.conf
cat /etc/resolv.conf
# Doit contenir : nameserver 172.16.100.254

# Solution Ubuntu 24.04 (systemd-resolved)
vim /etc/systemd/resolved.conf
# DNS=172.16.100.254
systemctl restart systemd-resolved
resolvectl status
```


#### Problème 3 : Forwarding ne fonctionne pas

```bash
# Symptôme
dig google.com @172.16.100.254
# ;; connection timed out; no servers could be reached

# Diagnostic
# Tester accès DNS public depuis serveur
dig google.com @1.1.1.1
# Si timeout → Problème réseau/firewall

# Vérifier forwarders dans config
grep forwarders /etc/bind/named.conf.options
# forwarders { 1.1.1.1; 1.0.0.1; };

# Tester connectivité DNS externe
nc -zvu 1.1.1.1 53
telnet 1.1.1.1 53

# Solution : Autoriser sortie DNS dans firewall
ufw allow out 53/udp
ufw allow out 53/tcp
```


#### Problème 4 : Serial non incrémenté

```bash
# Symptôme
rndc reload lab.local
# Zone reload OK mais changements non pris en compte

# Cause
# Serial zone identique (Bind9 ignore si serial ≤ ancien)

# Diagnostic
grep Serial /var/lib/bind/db.lab.local
# 2026011701

dig lab.local @172.16.100.254 SOA
# Serial actif en mémoire : 2026011701

# Solution
vim /var/lib/bind/db.lab.local
# Serial : 2026011701 → 2026011702
rndc reload lab.local

# Vérifier
dig lab.local @172.16.100.254 SOA
# Nouveau serial : 2026011702
```


***

## 📋 Checklist Ajout Nouvel Enregistrement

### ✅ Procédure manuelle (sans Ansible)

1. **Éditer fichier zone**

```bash
sudo vim /var/lib/bind/db.lab.local
```

2. **Incrémenter serial**

```bind
; Ancien
2026011701  ; Serial

; Nouveau
2026011702  ; Serial (toujours incrémenter !)
```

3. **Ajouter enregistrement**

```bind
newapp      IN      A       172.16.100.50
```

4. **Valider syntax**

```bash
sudo named-checkzone lab.local /var/lib/bind/db.lab.local
```

5. **Reload zone**

```bash
sudo rndc reload lab.local
```

6. **Tester résolution**

```bash
dig newapp.lab.local @172.16.100.254 +short
# Doit retourner : 172.16.100.50
```

7. **Vider cache client (optionnel)**

```bash
# Sur client
sudo systemd-resolve --flush-caches
```


***

## 🎯 Best Practices Bind9

### ✅ Recommandations Production

#### Configuration

- ✅ Utiliser `listen-on` pour limiter interfaces réseau
- ✅ Restreindre `allow-query` au réseau local uniquement
- ✅ Désactiver `allow-transfer` (pas de slave)
- ✅ Utiliser `forwarders` pour requêtes externes
- ✅ Activer DNSSEC validation
- ✅ Configurer rate-limiting (protection DoS)
- ✅ Masquer version Bind9 (`version "Not Disclosed"`)


#### Fichiers zones

- ✅ **TOUJOURS** incrémenter serial lors de modifications
- ✅ Ajouter point final après FQDN : `harbor.lab.local.`
- ✅ Utiliser TTL adaptés (3600s = 1h pour local)
- ✅ Éviter CNAME vers CNAME (interdit RFC)
- ✅ Documenter changements (commentaires)


#### Sécurité

- ✅ Firewall : autoriser port 53 uniquement réseau local
- ✅ Logs : surveiller requêtes suspectes
- ✅ SELinux/AppArmor : ne pas désactiver (laisser enforce)
- ✅ Droits fichiers : `/var/lib/bind` owned by bind:bind
- ✅ Pas de récursion pour requêtes externes non autorisées


#### Monitoring

- ✅ Surveiller logs `/var/log/bind/bind.log`
- ✅ Alertes sur redémarrage service Bind9
- ✅ Métriques Prometheus : `bind_exporter` (optionnel)
- ✅ Tests résolution automatiques (Nagios, Zabbix)

***

## 📚 Références Officielles

- **Documentation Bind9** : https://bind9.readthedocs.io/
- **ISC Bind9** : https://www.isc.org/bind/
- **RFC 1034** : Domain Names - Concepts
- **RFC 1035** : Domain Names - Implementation
- **Ubuntu Bind9 Guide** : https://ubuntu.com/server/docs/service-domain-name-service-dns

***

## 🚀 Exemples Types Enregistrements

### A (IPv4)

```bind
harbor      IN      A       172.16.100.2
```


### CNAME (Alias)

```bind
registry    IN      CNAME   harbor.lab.local.
```


### MX (Mail)

```bind
@           IN      MX      10 mail.lab.local.
```


### TXT (Texte arbitraire)

```bind
@           IN      TXT     "v=spf1 ip4:172.16.100.0/24 -all"
```


### SRV (Services)

```bind
_ldap._tcp  IN      SRV     10 5 389 ldap.lab.local.
```


### PTR (Inverse)

```bind
2           IN      PTR     harbor.lab.local.
```


### NS (Name Server)

```bind
@           IN      NS      dns.lab.local.
```


### SOA (Start of Authority)

```bind
@           IN      SOA     dns.lab.local. admin.lab.local. (
                            2026011701  ; Serial
                            3600        ; Refresh
                            1800        ; Retry
                            604800      ; Expire
                            86400 )     ; Negative Cache TTL
```


***

**Bind9 est maintenant documenté de A à Z !** 🎉 DNS propagation instantanée garantie ! 🚀
