# 🌐 Nginx Reverse Proxy : Documentation Complète


***

## 📍 Présentation : Nginx Reverse Proxy

### Définition

**Nginx Reverse Proxy** est un serveur proxy inverse qui se positionne entre les clients (navigateurs, applications) et les serveurs backend (applications web, APIs, microservices). Il reçoit les requêtes des clients, les transfère aux serveurs appropriés, récupère les réponses et les renvoie aux clients.[^1]

### Architecture Reverse Proxy

```
┌────────────────────────────────────────────────────────────────┐
│ Architecture Reverse Proxy Nginx                               │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  Internet / Clients                                            │
│         │                                                      │
│         ├─> Requête HTTP/HTTPS                                │
│         │                                                      │
│         ▼                                                      │
│  ┌────────────────────────────────────┐                       │
│  │   Nginx Reverse Proxy              │                       │
│  │   (Port 80/443)                    │                       │
│  │                                    │                       │
│  │   - SSL Termination (terminaison)  │                       │
│  │   - Load Balancing (répartition)   │                       │
│  │   - Caching (cache)                │                       │
│  │   - Headers Management (gestion)   │                       │
│  │   - Rate Limiting (limitation)     │                       │
│  └──────────┬─────────────────────────┘                       │
│             │                                                  │
│             ├─> proxy_pass                                     │
│             │                                                  │
│             ▼                                                  │
│  ┌──────────────────────────────────────────────┐             │
│  │ Backend Servers (Serveurs backend)           │             │
│  ├──────────────────────────────────────────────┤             │
│  │                                              │             │
│  │  ┌────────────┐  ┌────────────┐             │             │
│  │  │ App Server │  │ API Server │             │             │
│  │  │ :3000      │  │ :8080      │             │             │
│  │  └────────────┘  └────────────┘             │             │
│  │                                              │             │
│  │  ┌────────────┐  ┌────────────┐             │             │
│  │  │ Node.js    │  │ Python     │             │             │
│  │  │ :4000      │  │ :5000      │             │             │
│  │  └────────────┘  └────────────┘             │             │
│  │                                              │             │
│  └──────────────────────────────────────────────┘             │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```


### Comparaison Forward Proxy vs Reverse Proxy

| Critère | Forward Proxy | Reverse Proxy (Nginx) |
| :-- | :-- | :-- |
| **Position** | Côté client | Côté serveur |
| **But** | Anonymat client, contournement filtres | Protection serveurs, load balancing |
| **Visibilité** | Client connaît proxy | Client ignore proxy (transparent) |
| **Use case** | VPN, filtrage contenu entreprise | Applications web, APIs publiques |
| **Direction** | Client → Proxy → Internet | Internet → Proxy → Serveurs |
| **Exemple** | Squid, Privoxy | Nginx, HAProxy, Traefik |


***

## 📍 Fonctionnalités Nginx Reverse Proxy

### Fonctionnalités Principales

**SSL/TLS Termination (Terminaison SSL)**

- Déchiffrement HTTPS en entrée (client → Nginx)
- Communication HTTP backend (Nginx → serveurs internes)
- Certificats centralisés (Let's Encrypt, certificats auto-signés)

**Load Balancing (Répartition de charge)**

- Round-robin (rotation)
- Least connections (moins de connexions)
- IP hash (affinité session)
- Weighted (pondération)

**Caching (Mise en cache)**

- Cache réponses HTTP (HTML, JSON, images)
- Réduit charge backend
- Améliore performances

**Headers Management (Gestion en-têtes)**

- Ajout/modification headers HTTP
- X-Real-IP, X-Forwarded-For (IP client réelle)
- X-Forwarded-Proto (protocole original HTTPS)

**Security (Sécurité)**

- Rate limiting (limitation débit)
- IP whitelisting/blacklisting (liste blanche/noire)
- Protection DDoS (attaque par déni de service)
- Headers sécurité (HSTS, CSP, X-Frame-Options)

**WebSocket Support**

- Proxy WebSocket (communication bidirectionnelle)
- Upgrade HTTP → WebSocket

***

## 📍 Directive proxy_pass (Proxy HTTP)

### Syntaxe proxy_pass

```nginx
Syntax:  proxy_pass URL;
Default: —
Context: location, if in location, limit_except
```

La directive `proxy_pass` transfère requêtes vers serveur backend spécifié.[^2][^3]

### Exemples proxy_pass

#### Exemple 1 : Proxy Simple (Sans URI)

```nginx
# ===================================================================
# Proxy simple : URI complète transmise au backend
# ===================================================================
location /api/ {
    proxy_pass http://127.0.0.1:8080;
}

# Comportement :
# Requête client : GET /api/users/123
# Transmis backend : GET /api/users/123
```


#### Exemple 2 : Proxy avec URI (Réécriture)

```nginx
# ===================================================================
# Proxy avec URI : Remplacement du chemin
# ===================================================================
location /api/ {
    proxy_pass http://127.0.0.1:8080/v1/;
}

# Comportement :
# Requête client : GET /api/users/123
# Transmis backend : GET /v1/users/123
#                       ↑
#                       /api/ remplacé par /v1/
```


#### Exemple 3 : Proxy avec Variables

```nginx
# ===================================================================
# Proxy dynamique avec variables
# ===================================================================
location /proxy/ {
    proxy_pass http://backend$request_uri;
}

# Variables Nginx disponibles :
# $request_uri  : URI complète avec query string
# $uri          : URI normalisée sans query string
# $args         : Query string uniquement
```


#### Exemple 4 : Proxy vers Upstream (Load Balancing)

```nginx
# ===================================================================
# Proxy vers groupe de serveurs (upstream)
# ===================================================================
upstream backend_pool {
    server 192.168.1.10:8080;
    server 192.168.1.11:8080;
    server 192.168.1.12:8080;
}

location / {
    proxy_pass http://backend_pool;
}
```


#### Exemple 5 : Proxy Unix Socket

```nginx
# ===================================================================
# Proxy vers socket Unix (local)
# ===================================================================
location / {
    proxy_pass http://unix:/var/run/app.sock:/;
}
```


***

## 📍 Headers Proxy (proxy_set_header)

### Headers Standards

Les headers suivants doivent être configurés pour transmettre informations client au backend.[^4][^1]

```nginx
# ===================================================================
# Configuration Headers Proxy (Standard)
# ===================================================================

location / {
    proxy_pass http://backend;
    
    # ===================================================================
    # Host : Nom domaine original
    # ===================================================================
    # $host = domaine depuis requête (example.com)
    # $proxy_host = domaine backend (localhost)
    proxy_set_header Host $host;
    
    # ===================================================================
    # X-Real-IP : IP client réelle
    # ===================================================================
    # $remote_addr = IP client direct (peut être proxy)
    proxy_set_header X-Real-IP $remote_addr;
    
    # ===================================================================
    # X-Forwarded-For : Chaîne IPs (client + proxies)
    # ===================================================================
    # $proxy_add_x_forwarded_for = ajoute IP à liste existante
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    
    # ===================================================================
    # X-Forwarded-Proto : Protocole original (http/https)
    # ===================================================================
    # $scheme = http ou https
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # ===================================================================
    # X-Forwarded-Host : Domaine original
    # ===================================================================
    proxy_set_header X-Forwarded-Host $host;
    
    # ===================================================================
    # X-Forwarded-Port : Port original
    # ===================================================================
    # $server_port = port serveur (80, 443)
    proxy_set_header X-Forwarded-Port $server_port;
}
```


### Template Headers Complet

```nginx
# ===================================================================
# Template Headers Proxy Complet (Production)
# ===================================================================

location / {
    proxy_pass http://backend;
    
    # ===================================================================
    # Headers obligatoires
    # ===================================================================
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Port $server_port;
    
    # ===================================================================
    # Headers optionnels (sécurité, performance)
    # ===================================================================
    
    # Connection : Fermer connexion ou keepalive
    proxy_set_header Connection "";
    
    # Upgrade : Support WebSocket
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    
    # Accept-Encoding : Désactiver compression (si nécessaire)
    # proxy_set_header Accept-Encoding "";
    
    # Authorization : Transmettre token auth
    proxy_set_header Authorization $http_authorization;
    
    # User-Agent : Transmettre user agent client
    proxy_set_header User-Agent $http_user_agent;
    
    # Referer : Transmettre referer
    proxy_set_header Referer $http_referer;
}
```


***

## 📍 Configuration Reverse Proxy (Exemples)

### Configuration 1 : Reverse Proxy Simple (HTTP)

```nginx
# ===================================================================
# Reverse Proxy Simple : Backend HTTP
# ===================================================================

# Upstream backend
upstream app_backend {
    server 127.0.0.1:3000;
}

server {
    listen 80;
    server_name example.com;
    
    # Logs
    access_log /var/log/nginx/example.com.access.log;
    error_log /var/log/nginx/example.com.error.log;
    
    # Reverse proxy
    location / {
        proxy_pass http://app_backend;
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```


### Configuration 2 : Reverse Proxy HTTPS (SSL Termination)

```nginx
# ===================================================================
# Reverse Proxy HTTPS : SSL Termination (Terminaison SSL)
# ===================================================================

# Upstream backend (HTTP interne)
upstream app_backend {
    server 192.168.1.10:3000;
}

# Redirection HTTP → HTTPS
server {
    listen 80;
    server_name example.com;
    return 301 https://$host$request_uri;
}

# Server HTTPS
server {
    listen 443 ssl http2;
    server_name example.com;
    
    # ===================================================================
    # Certificats SSL
    # ===================================================================
    ssl_certificate /etc/nginx/ssl/example.com.crt;
    ssl_certificate_key /etc/nginx/ssl/example.com.key;
    
    # SSL configuration optimale
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # ===================================================================
    # Headers sécurité
    # ===================================================================
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Logs
    access_log /var/log/nginx/example.com.access.log;
    error_log /var/log/nginx/example.com.error.log;
    
    # ===================================================================
    # Reverse proxy vers backend HTTP
    # ===================================================================
    location / {
        proxy_pass http://app_backend;
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;  # Force HTTPS
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port 443;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffering
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }
}
```


### Configuration 3 : Multi-Applications (Context Path)

```nginx
# ===================================================================
# Reverse Proxy Multi-Applications (Context Path)
# ===================================================================

# Upstreams
upstream frontend_app {
    server 192.168.1.10:3000;
}

upstream api_app {
    server 192.168.1.11:8080;
}

upstream admin_app {
    server 192.168.1.12:4000;
}

server {
    listen 443 ssl http2;
    server_name example.com;
    
    ssl_certificate /etc/nginx/ssl/example.com.crt;
    ssl_certificate_key /etc/nginx/ssl/example.com.key;
    
    # ===================================================================
    # Frontend : / (racine)
    # ===================================================================
    location / {
        proxy_pass http://frontend_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # ===================================================================
    # API : /api/
    # ===================================================================
    location /api/ {
        proxy_pass http://api_app/;
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # CORS (si nécessaire)
        add_header 'Access-Control-Allow-Origin' '*' always;
    }
    
    # ===================================================================
    # Admin : /admin/
    # ===================================================================
    location /admin/ {
        proxy_pass http://admin_app/;
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Restriction IP admin (sécurité)
        allow 192.168.1.0/24;  # Réseau interne
        deny all;
    }
}
```


### Configuration 4 : Load Balancing (Répartition Charge)

```nginx
# ===================================================================
# Reverse Proxy Load Balancing
# ===================================================================

# ===================================================================
# Upstream : Round-robin (défaut)
# ===================================================================
upstream backend_roundrobin {
    server 192.168.1.10:8080;
    server 192.168.1.11:8080;
    server 192.168.1.12:8080;
}

# ===================================================================
# Upstream : Least connections (moins de connexions)
# ===================================================================
upstream backend_leastconn {
    least_conn;
    server 192.168.1.10:8080;
    server 192.168.1.11:8080;
    server 192.168.1.12:8080;
}

# ===================================================================
# Upstream : IP Hash (affinité session)
# ===================================================================
upstream backend_iphash {
    ip_hash;
    server 192.168.1.10:8080;
    server 192.168.1.11:8080;
    server 192.168.1.12:8080;
}

# ===================================================================
# Upstream : Weighted (pondération)
# ===================================================================
upstream backend_weighted {
    server 192.168.1.10:8080 weight=3;  # 60% trafic
    server 192.168.1.11:8080 weight=2;  # 40% trafic
    server 192.168.1.12:8080 backup;    # Backup uniquement
}

# ===================================================================
# Upstream : Health checks (vérifications santé)
# ===================================================================
upstream backend_healthcheck {
    server 192.168.1.10:8080 max_fails=3 fail_timeout=30s;
    server 192.168.1.11:8080 max_fails=3 fail_timeout=30s;
    server 192.168.1.12:8080 max_fails=3 fail_timeout=30s;
}

server {
    listen 443 ssl http2;
    server_name example.com;
    
    ssl_certificate /etc/nginx/ssl/example.com.crt;
    ssl_certificate_key /etc/nginx/ssl/example.com.key;
    
    location / {
        proxy_pass http://backend_weighted;
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Keepalive (réutilisation connexions)
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
```


### Configuration 5 : WebSocket Proxy

```nginx
# ===================================================================
# Reverse Proxy WebSocket
# ===================================================================

# Upstream WebSocket
upstream websocket_backend {
    server 192.168.1.10:3000;
}

# Map Upgrade header (connexion WebSocket)
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 443 ssl http2;
    server_name ws.example.com;
    
    ssl_certificate /etc/nginx/ssl/ws.example.com.crt;
    ssl_certificate_key /etc/nginx/ssl/ws.example.com.key;
    
    # ===================================================================
    # Location WebSocket
    # ===================================================================
    location /ws/ {
        proxy_pass http://websocket_backend;
        
        # Headers WebSocket (obligatoires)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        
        # Headers standards
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts WebSocket (longs)
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }
}
```


### Configuration 6 : Caching Reverse Proxy

```nginx
# ===================================================================
# Reverse Proxy avec Caching
# ===================================================================

# ===================================================================
# Cache path configuration
# ===================================================================
proxy_cache_path /var/cache/nginx 
    levels=1:2 
    keys_zone=app_cache:10m 
    max_size=1g 
    inactive=60m 
    use_temp_path=off;

# Upstream
upstream app_backend {
    server 192.168.1.10:8080;
}

server {
    listen 443 ssl http2;
    server_name example.com;
    
    ssl_certificate /etc/nginx/ssl/example.com.crt;
    ssl_certificate_key /etc/nginx/ssl/example.com.key;
    
    # ===================================================================
    # Cache configuration
    # ===================================================================
    location / {
        proxy_pass http://app_backend;
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # ===================================================================
        # Caching
        # ===================================================================
        proxy_cache app_cache;
        proxy_cache_key "$scheme$request_method$host$request_uri";
        proxy_cache_valid 200 302 10m;
        proxy_cache_valid 404 1m;
        proxy_cache_bypass $http_cache_control;
        proxy_no_cache $http_pragma $http_authorization;
        
        # Header indiquant cache hit/miss
        add_header X-Cache-Status $upstream_cache_status always;
        
        # Utiliser cache si backend down
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
        proxy_cache_lock on;
    }
    
    # ===================================================================
    # Pas de cache pour API
    # ===================================================================
    location /api/ {
        proxy_pass http://app_backend;
        proxy_cache off;
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```


***

## 📍 Buffering Reverse Proxy

### Configuration Buffering

Le buffering permet à Nginx de stocker temporairement les réponses backend avant de les transmettre au client.[^3][^5]

```nginx
# ===================================================================
# Configuration Buffering Proxy
# ===================================================================

location / {
    proxy_pass http://backend;
    
    # ===================================================================
    # Buffering activé (défaut)
    # ===================================================================
    proxy_buffering on;
    
    # Taille buffer première partie réponse (headers)
    proxy_buffer_size 4k;  # ou 8k selon plateforme
    
    # Nombre et taille buffers pour réponse complète
    proxy_buffers 8 4k;  # 8 buffers de 4k = 32k total
    
    # Taille max buffers occupés envoi client
    proxy_busy_buffers_size 8k;
    
    # ===================================================================
    # Fichiers temporaires (si réponse > buffers)
    # ===================================================================
    proxy_max_temp_file_size 1024m;  # Taille max fichier temp
    proxy_temp_file_write_size 8k;   # Taille écriture fichier temp
}

# ===================================================================
# Buffering désactivé (streaming temps réel)
# ===================================================================
location /stream/ {
    proxy_pass http://backend;
    
    # Désactiver buffering (transmission immédiate)
    proxy_buffering off;
    
    # Buffer minimal (headers uniquement)
    proxy_buffer_size 4k;
}
```


### Comparaison Buffering ON vs OFF

| Configuration | Buffering ON | Buffering OFF |
| :-- | :-- | :-- |
| **Transmission** | Nginx buffère réponse complète | Transmission immédiate chunk par chunk |
| **Performance client lent** | ✅ Libère backend rapidement | ❌ Backend attend client lent |
| **Performance client rapide** | ⚠️ Latence ajoutée (buffering) | ✅ Latence minimale |
| **Mémoire Nginx** | ⚠️ Utilise mémoire/disque | ✅ Mémoire minimale |
| **Use case** | Pages HTML, APIs standard | Streaming vidéo, SSE, WebSocket |


***

## 📍 Timeouts Reverse Proxy

### Configuration Timeouts

```nginx
# ===================================================================
# Timeouts Proxy (Production)
# ===================================================================

location / {
    proxy_pass http://backend;
    
    # ===================================================================
    # Timeout connexion backend
    # ===================================================================
    # Délai max établissement connexion TCP
    proxy_connect_timeout 60s;  # Défaut : 60s
    
    # ===================================================================
    # Timeout envoi requête backend
    # ===================================================================
    # Délai max entre 2 opérations écriture (envoi requête)
    proxy_send_timeout 60s;  # Défaut : 60s
    
    # ===================================================================
    # Timeout lecture réponse backend
    # ===================================================================
    # Délai max entre 2 opérations lecture (réception réponse)
    proxy_read_timeout 60s;  # Défaut : 60s
}

# ===================================================================
# Timeouts longs (streaming, long polling)
# ===================================================================
location /stream/ {
    proxy_pass http://backend;
    
    proxy_connect_timeout 300s;  # 5 min
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;
}

# ===================================================================
# Timeouts courts (API rapide)
# ===================================================================
location /api/ {
    proxy_pass http://backend;
    
    proxy_connect_timeout 10s;
    proxy_send_timeout 30s;
    proxy_read_timeout 30s;
}
```


***

## 📍 Rate Limiting (Limitation Débit)

### Configuration Rate Limiting

```nginx
# ===================================================================
# Rate Limiting Reverse Proxy (Protection DDoS)
# ===================================================================

# ===================================================================
# Zone mémoire rate limiting
# ===================================================================
# Zone par IP client
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;

# Zone par IP + URI
limit_req_zone "$binary_remote_addr$request_uri" zone=uri_limit:10m rate=5r/s;

server {
    listen 443 ssl http2;
    server_name example.com;
    
    ssl_certificate /etc/nginx/ssl/example.com.crt;
    ssl_certificate_key /etc/nginx/ssl/example.com.key;
    
    # ===================================================================
    # Rate limiting API
    # ===================================================================
    location /api/ {
        proxy_pass http://backend;
        
        # Limiter à 10 req/s par IP, burst 20 req
        limit_req zone=api_limit burst=20 nodelay;
        
        # Si limite dépassée : 429 Too Many Requests
        limit_req_status 429;
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    
    # ===================================================================
    # Pas de rate limiting pour contenu statique
    # ===================================================================
    location /static/ {
        proxy_pass http://backend;
        # Pas de limit_req
    }
}
```


***

## 📍 Sécurité Reverse Proxy

### Configuration Sécurité Complète

```nginx
# ===================================================================
# Reverse Proxy Sécurisé (DevSecOps)
# ===================================================================

# ===================================================================
# Geo-blocking : Bloquer pays/IPs
# ===================================================================
geo $blocked_country {
    default 0;
    # Bloquer IPs spécifiques
    192.0.2.0/24 1;
    198.51.100.0/24 1;
}

# ===================================================================
# User-Agent blocking (bots malicieux)
# ===================================================================
map $http_user_agent $blocked_agent {
    default 0;
    "~*bot" 1;
    "~*crawler" 1;
    "~*scanner" 1;
}

# ===================================================================
# Rate limiting zones
# ===================================================================
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=api:10m rate=5r/s;
limit_req_zone $binary_remote_addr zone=login:10m rate=1r/m;

# Upstream
upstream secure_backend {
    server 192.168.1.10:8080 max_fails=3 fail_timeout=30s;
}

server {
    listen 443 ssl http2;
    server_name example.com;
    
    # ===================================================================
    # SSL Configuration (TLS 1.2/1.3 uniquement)
    # ===================================================================
    ssl_certificate /etc/nginx/ssl/example.com.crt;
    ssl_certificate_key /etc/nginx/ssl/example.com.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;
    
    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 1.1.1.1 8.8.8.8 valid=300s;
    resolver_timeout 5s;
    
    # ===================================================================
    # Headers Sécurité
    # ===================================================================
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:;" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
    
    # ===================================================================
    # Bloquer geo/user-agent malicieux
    # ===================================================================
    if ($blocked_country) {
        return 403 "Access denied";
    }
    
    if ($blocked_agent) {
        return 403 "Bot access denied";
    }
    
    # ===================================================================
    # Cacher version Nginx (sécurité)
    # ===================================================================
    server_tokens off;
    
    # ===================================================================
    # Location générale (rate limit)
    # ===================================================================
    location / {
        limit_req zone=general burst=20 nodelay;
        
        proxy_pass http://secure_backend;
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        
        # Cacher headers internes backend
        proxy_hide_header X-Powered-By;
        proxy_hide_header X-AspNet-Version;
        proxy_hide_header Server;
    }
    
    # ===================================================================
    # Location API (rate limit strict)
    # ===================================================================
    location /api/ {
        limit_req zone=api burst=10 nodelay;
        
        proxy_pass http://secure_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    
    # ===================================================================
    # Location Login (rate limit très strict)
    # ===================================================================
    location /login {
        limit_req zone=login burst=2 nodelay;
        
        proxy_pass http://secure_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    
    # ===================================================================
    # Location Admin (restriction IP)
    # ===================================================================
    location /admin/ {
        # Whitelist IPs
        allow 192.168.1.0/24;  # Réseau interne
        allow 10.0.0.0/8;      # VPN
        deny all;
        
        proxy_pass http://secure_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```


***

## 📍 Monitoring et Logs

### Configuration Logs Détaillés

```nginx
# ===================================================================
# Logs Reverse Proxy (Format personnalisé)
# ===================================================================

# ===================================================================
# Format log personnalisé (JSON)
# ===================================================================
log_format json_combined escape=json
'{'
  '"time_local":"$time_local",'
  '"remote_addr":"$remote_addr",'
  '"remote_user":"$remote_user",'
  '"request":"$request",'
  '"status":"$status",'
  '"body_bytes_sent":"$body_bytes_sent",'
  '"request_time":"$request_time",'
  '"http_referrer":"$http_referer",'
  '"http_user_agent":"$http_user_agent",'
  '"http_x_forwarded_for":"$http_x_forwarded_for",'
  '"upstream_addr":"$upstream_addr",'
  '"upstream_status":"$upstream_status",'
  '"upstream_response_time":"$upstream_response_time",'
  '"upstream_cache_status":"$upstream_cache_status"'
'}';

# ===================================================================
# Format log détaillé (texte)
# ===================================================================
log_format proxy_detailed '$remote_addr - $remote_user [$time_local] '
                          '"$request" $status $body_bytes_sent '
                          '"$http_referer" "$http_user_agent" '
                          'upstream: $upstream_addr '
                          'upstream_status: $upstream_status '
                          'request_time: $request_time '
                          'upstream_response_time: $upstream_response_time '
                          'upstream_connect_time: $upstream_connect_time';

server {
    listen 443 ssl http2;
    server_name example.com;
    
    ssl_certificate /etc/nginx/ssl/example.com.crt;
    ssl_certificate_key /etc/nginx/ssl/example.com.key;
    
    # ===================================================================
    # Logs avec format personnalisé
    # ===================================================================
    access_log /var/log/nginx/example.com.access.log json_combined;
    error_log /var/log/nginx/example.com.error.log warn;
    
    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```


### Script Analyse Logs (Bash)

```bash
#!/usr/bin/env bash
# ===================================================================
# Script : analyze_proxy_logs.sh
# Description : Analyse logs Nginx reverse proxy
# ===================================================================

set -euo pipefail

LOG_FILE="/var/log/nginx/example.com.access.log"

echo "📊 Analyse Logs Reverse Proxy Nginx"
echo "======================================"

# ===================================================================
# Top 10 IPs clients
# ===================================================================
echo ""
echo "🔍 Top 10 IPs Clients :"
awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -10

# ===================================================================
# Top 10 URIs requêtées
# ===================================================================
echo ""
echo "🔍 Top 10 URIs :"
awk '{print $7}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -10

# ===================================================================
# Codes HTTP status
# ===================================================================
echo ""
echo "📈 Codes HTTP Status :"
awk '{print $9}' "$LOG_FILE" | sort | uniq -c | sort -rn

# ===================================================================
# Requêtes lentes (> 1s)
# ===================================================================
echo ""
echo "⚠️ Requêtes Lentes (> 1s) :"
awk '$NF > 1.0 {print $7, $NF"s"}' "$LOG_FILE" | head -20

# ===================================================================
# User-Agents suspects (bots)
# ===================================================================
echo ""
echo "🤖 User-Agents Suspects :"
grep -i "bot\|crawler\|scanner" "$LOG_FILE" | awk -F'"' '{print $6}' | sort | uniq -c | sort -rn | head -10

echo ""
echo "✅ Analyse terminée"
```


***

## 📍 Rôle Ansible : Nginx Reverse Proxy

### Structure Rôle

```
roles/nginx_reverse_proxy/
├── defaults/
│   └── main.yml
├── tasks/
│   ├── main.yml
│   ├── install.yml
│   ├── configure.yml
│   ├── ssl.yml
│   └── validate.yml
├── templates/
│   ├── reverse-proxy.conf.j2
│   ├── upstream.conf.j2
│   └── ssl-params.conf.j2
├── handlers/
│   └── main.yml
└── files/
    └── dhparam.pem
```


### Fichier : `defaults/main.yml`

```yaml
---
# ===================================================================
# Variables Nginx Reverse Proxy (defaults)
# ===================================================================

# Version Nginx
nginx_version: "1.24.0"

# Domaine
domain_name: "example.com"

# Backend upstream
backend_servers:
  - ip: "192.168.1.10"
    port: 8080
    weight: 1
    max_fails: 3
    fail_timeout: "30s"
  - ip: "192.168.1.11"
    port: 8080
    weight: 1
    max_fails: 3
    fail_timeout: "30s"

# Load balancing method
lb_method: "least_conn"  # least_conn, ip_hash, round_robin

# SSL/TLS
ssl_enabled: true
ssl_certificate_path: "/etc/nginx/ssl/{{ domain_name }}.crt"
ssl_certificate_key_path: "/etc/nginx/ssl/{{ domain_name }}.key"
ssl_protocols: "TLSv1.2 TLSv1.3"

# Headers proxy
proxy_headers:
  Host: "$host"
  X-Real-IP: "$remote_addr"
  X-Forwarded-For: "$proxy_add_x_forwarded_for"
  X-Forwarded-Proto: "$scheme"
  X-Forwarded-Host: "$host"
  X-Forwarded-Port: "$server_port"

# Timeouts
proxy_connect_timeout: "60s"
proxy_send_timeout: "60s"
proxy_read_timeout: "60s"

# Buffering
proxy_buffering: true
proxy_buffer_size: "4k"
proxy_buffers: "8 4k"

# Rate limiting
rate_limit_enabled: true
rate_limit_zone: "api_limit"
rate_limit_rate: "10r/s"
rate_limit_burst: 20

# Logs
access_log_path: "/var/log/nginx/{{ domain_name }}.access.log"
error_log_path: "/var/log/nginx/{{ domain_name }}.error.log"
log_format: "combined"
```


### Fichier : `templates/reverse-proxy.conf.j2`

```nginx
# ===================================================================
# Nginx Reverse Proxy Configuration
# Généré par Ansible : {{ ansible_date_time.iso8601 }}
# Domaine : {{ domain_name }}
# ===================================================================

# ===================================================================
# Upstream backend
# ===================================================================
upstream {{ domain_name }}_backend {
{% if lb_method == 'least_conn' %}
    least_conn;
{% elif lb_method == 'ip_hash' %}
    ip_hash;
{% endif %}

{% for server in backend_servers %}
    server {{ server.ip }}:{{ server.port }} weight={{ server.weight }} max_fails={{ server.max_fails }} fail_timeout={{ server.fail_timeout }};
{% endfor %}

    keepalive 32;
}

{% if rate_limit_enabled %}
# ===================================================================
# Rate limiting zone
# ===================================================================
limit_req_zone $binary_remote_addr zone={{ rate_limit_zone }}:10m rate={{ rate_limit_rate }};
{% endif %}

{% if ssl_enabled %}
# ===================================================================
# HTTP → HTTPS redirect
# ===================================================================
server {
    listen 80;
    listen [::]:80;
    server_name {{ domain_name }};
    
    return 301 https://$host$request_uri;
}
{% endif %}

# ===================================================================
# Server block {% if ssl_enabled %}HTTPS{% else %}HTTP{% endif %}
# ===================================================================
server {
{% if ssl_enabled %}
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
{% else %}
    listen 80;
    listen [::]:80;
{% endif %}
    
    server_name {{ domain_name }};
    
{% if ssl_enabled %}
    # ===================================================================
    # SSL Configuration
    # ===================================================================
    ssl_certificate {{ ssl_certificate_path }};
    ssl_certificate_key {{ ssl_certificate_key_path }};
    
    ssl_protocols {{ ssl_protocols }};
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;
    
    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 1.1.1.1 8.8.8.8 valid=300s;
    resolver_timeout 5s;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
{% endif %}
    
    # ===================================================================
    # Logs
    # ===================================================================
    access_log {{ access_log_path }} {{ log_format }};
    error_log {{ error_log_path }} warn;
    
    # Cacher version Nginx
    server_tokens off;
    
    # ===================================================================
    # Reverse Proxy
    # ===================================================================
    location / {
{% if rate_limit_enabled %}
        limit_req zone={{ rate_limit_zone }} burst={{ rate_limit_burst }} nodelay;
        limit_req_status 429;
{% endif %}
        
        proxy_pass http://{{ domain_name }}_backend;
        
        # Headers
{% for header_name, header_value in proxy_headers.items() %}
        proxy_set_header {{ header_name }} {{ header_value }};
{% endfor %}
        
        # Timeouts
        proxy_connect_timeout {{ proxy_connect_timeout }};
        proxy_send_timeout {{ proxy_send_timeout }};
        proxy_read_timeout {{ proxy_read_timeout }};
        
        # Buffering
        proxy_buffering {{ 'on' if proxy_buffering else 'off' }};
{% if proxy_buffering %}
        proxy_buffer_size {{ proxy_buffer_size }};
        proxy_buffers {{ proxy_buffers }};
{% endif %}
        
        # Keepalive
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
    
    # ===================================================================
    # Health check endpoint
    # ===================================================================
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
}
```


### Fichier : `tasks/configure.yml`

```yaml
---
# ===================================================================
# Configuration Nginx Reverse Proxy
# ===================================================================

- name: Créer répertoire sites-available
  ansible.builtin.file:
    path: /etc/nginx/sites-available
    state: directory
    owner: root
    group: root
    mode: '0755'
  tags: ['nginx', 'config']

- name: Créer répertoire sites-enabled
  ansible.builtin.file:
    path: /etc/nginx/sites-enabled
    state: directory
    owner: root
    group: root
    mode: '0755'
  tags: ['nginx', 'config']

- name: Déployer configuration reverse proxy
  ansible.builtin.template:
    src: reverse-proxy.conf.j2
    dest: "/etc/nginx/sites-available/{{ domain_name }}.conf"
    owner: root
    group: root
    mode: '0644'
    validate: 'nginx -t -c %s'
  notify: reload nginx
  tags: ['nginx', 'config']

- name: Activer site (symlink)
  ansible.builtin.file:
    src: "/etc/nginx/sites-available/{{ domain_name }}.conf"
    dest: "/etc/nginx/sites-enabled/{{ domain_name }}.conf"
    state: link
  notify: reload nginx
  tags: ['nginx', 'config']

- name: Supprimer site default
  ansible.builtin.file:
    path: /etc/nginx/sites-enabled/default
    state: absent
  notify: reload nginx
  tags: ['nginx', 'config']

- name: Créer répertoire logs
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: www-data
    group: www-data
    mode: '0755'
  loop:
    - "/var/log/nginx"
  tags: ['nginx', 'config']
```


### Fichier : `tasks/validate.yml`

```yaml
---
# ===================================================================
# Validation configuration Nginx
# ===================================================================

- name: Test configuration Nginx
  ansible.builtin.command: nginx -t
  register: nginx_test
  changed_when: false
  failed_when: nginx_test.rc != 0
  tags: ['nginx', 'validate']

- name: Afficher résultat test
  ansible.builtin.debug:
    msg: "✅ Configuration Nginx valide"
  when: nginx_test.rc == 0
  tags: ['nginx', 'validate']

- name: Vérifier service Nginx actif
  ansible.builtin.systemd:
    name: nginx
    state: started
    enabled: yes
  tags: ['nginx', 'validate']

- name: Test HTTP health check
  ansible.builtin.uri:
    url: "http://{{ domain_name }}/health"
    return_content: yes
    status_code: 200
  register: http_health
  retries: 3
  delay: 5
  until: http_health.status == 200
  tags: ['nginx', 'validate']

- name: Afficher résultat health check
  ansible.builtin.debug:
    msg: "✅ Health check OK : {{ http_health.content }}"
  tags: ['nginx', 'validate']
```


***

## 📚 Références Officielles

- **Nginx Official Docs - Reverse Proxy** : https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/[^5]
- **Nginx Module ngx_http_proxy_module** : https://nginx.org/en/docs/http/ngx_http_proxy_module.html[^3]
- **Nginx Admin Guide** : https://nginx.org/en/docs/

***

**Nginx Reverse Proxy documenté de A à Z !** 🚀 Configuration production-ready DevSecOps ! 🔒
<span style="display:none">[^10][^11][^12][^13][^14][^15][^16][^17][^6][^7][^8][^9]</span>

<div align="center">⁂</div>

[^1]: https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/

[^2]: https://nginx.org/en/docs/http/ngx_http_proxy_module.html

[^3]: https://pve.proxmox.com/wiki/Cloud-Init_Support

[^4]: https://www.scaleway.com/en/docs/tutorials/nginx-reverse-proxy/

[^5]: https://www.reddit.com/r/Proxmox/comments/172hz58/please_elaborate_on_cloudinit/

[^6]: https://nginx.org/en/docs/index.html

[^7]: https://nginx.org/en/docs/

[^8]: https://www.digitalocean.com/community/tutorials/how-to-configure-nginx-as-a-reverse-proxy-on-ubuntu-22-04

[^9]: https://nginxtutorials.com/nginx-proxy-pass/

[^10]: https://www.tencentcloud.com/techpedia/105288

[^11]: https://www.theserverside.com/blog/Coffee-Talk-Java-News-Stories-and-Opinions/How-to-setup-Nginx-reverse-proxy-servers-by-example

[^12]: https://adamtheautomator.com/nginx-proxypass/

[^13]: https://www.samueldowling.com/2020/01/18/nginx-reverse-proxy-freenas-ssl-tls/

[^14]: https://coder.com/docs/tutorials/reverse-proxy-nginx

[^15]: https://stackoverflow.com/questions/56506814/how-to-configure-nginx-as-proxy-pass

[^16]: https://www.reddit.com/r/homelab/comments/sth14d/nginx_reverse_proxy_ssl_termination_and/

[^17]: https://www.hostinger.com/ca/tutorials/how-to-set-up-nginx-reverse-proxy

