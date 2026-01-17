# 🔷 Réseau : Création d'un Linux Bridge (vmbr)


***

## 📍 Explication : Rôle du Linux Bridge dans Proxmox

### Définition

Un **Linux Bridge** (vmbr) est un switch virtuel logiciel qui permet de connecter les VMs entre elles et au réseau physique. Proxmox utilise des bridges Linux pour isoler ou interconnecter les réseaux virtuels.

### Comparaison des types de réseau Proxmox

| Type | Nom | Usage | Isolation | Performance |
| :-- | :-- | :-- | :-- | :-- |
| **Linux Bridge** | vmbr0, vmbr1... | Production (par défaut) | Partielle (VLANs) | Excellente |
| **OVS Bridge** | vmbr0 (OpenVSwitch) | SDN avancé | Complète (VXLANs) | Bonne |
| **NAT Network** | nat0 | Réseau privé sortant | Totale | Moyenne |
| **Bonding** | bond0 | Agrégation liens | N/A | Très haute |

### Rôle dans l'architecture SSOT

```
┌─────────────────────────────────────────────────────────────┐
│ SSOT Infrastructure Réseau                                  │
├─────────────────────────────────────────────────────────────┤
│ • Terraform configure bridges VMs (vmbr0, vmbr1)           │
│ • Ansible configure interfaces VMs (IP statiques)          │
│ • Proxmox gère bridges physiques (création manuelle)       │
│ • Cloud-init applique config réseau au boot                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Topologie Réseau Segmentée                                  │
├─────────────────────────────────────────────────────────────┤
│ vmbr0 → WAN/LAN (172.16.100.0/24) - Production            │
│ vmbr1 → DMZ (172.16.200.0/24) - Services publics          │
│ vmbr2 → MANAGEMENT (172.16.10.0/24) - Admin               │
│ vmbr3 → STORAGE (10.0.0.0/24) - iSCSI/NFS                 │
└─────────────────────────────────────────────────────────────┘
```


***

## 📍 Cycle de vie : Création Linux Bridge

### Phase 1 : Planification réseau (Design SSOT)

```
1. Définition architecture réseau (SSOT)
   └─> Documentation (network-design.md)
       ├─> vmbr0: Réseau production (accès Internet)
       ├─> vmbr1: DMZ (services publics)
       ├─> vmbr2: Management (administration)
       └─> vmbr3: Storage (SAN/NAS)

2. Attribution plages IP (SSOT)
   └─> terraform.tfvars
       ├─> network_production = "172.16.100.0/24"
       ├─> network_dmz = "172.16.200.0/24"
       ├─> network_mgmt = "172.16.10.0/24"
       └─> network_storage = "10.0.0.0/24"

3. Choix interfaces physiques
   └─> eth0 → vmbr0 (production)
   └─> eth1 → vmbr1 (DMZ)
   └─> eth2 → vmbr2 (management)
```


### Phase 2 : Création bridge Proxmox (Manuelle ou Ansible)

```
Méthode 1 : Création manuelle (GUI Proxmox)
  └─> Datacenter → <node> → System → Network
      └─> Create → Linux Bridge
          ├─> Name: vmbr1
          ├─> IP: 172.16.200.1/24 (gateway Proxmox)
          ├─> Bridge ports: eth1 (optionnel)
          ├─> Autostart: ✓
          └─> Apply Configuration

Méthode 2 : Création via script (SSH Proxmox)
  └─> ./scripts/create-proxmox-bridge.sh vmbr1 eth1 172.16.200.1/24
      └─> Modification /etc/network/interfaces
      └─> ifreload -a (application sans reboot)

Méthode 3 : Création via Ansible (idempotent)
  └─> ansible-playbook playbooks/proxmox-network.yml
      └─> Rôle proxmox_network
          └─> Template /etc/network/interfaces
          └─> Handler ifreload
```


### Phase 3 : Configuration VMs Terraform (SSOT)

```
1. Définition networks dans terraform.tfvars (SSOT)
   └─> nodes = {
         web-server = {
           # ...
           bridge = "vmbr1"  # DMZ
         }
         db-server = {
           # ...
           bridge = "vmbr0"  # Production
         }
       }

2. Terraform applique configuration
   └─> terraform apply
       └─> network_device {
             model  = "virtio"
             bridge = each.value.bridge
           }

3. VMs connectées au bon bridge
   └─> web-server → vmbr1 (DMZ)
   └─> db-server → vmbr0 (Production)
```


### Phase 4 : Configuration IP statiques Cloud-init/Ansible

```
1. Cloud-init configure IP au boot (SSOT)
   └─> initialization {
         ip_config {
           ipv4 {
             address = "172.16.200.10/24"
             gateway = "172.16.200.1"
           }
         }
       }

2. Ansible ajuste config réseau (idempotent)
   └─> roles/network/tasks/main.yml
       └─> Création /etc/netplan/01-netcfg.yaml
       └─> netplan apply
```


***

## 📍 Architecture SSOT : Réseau segmenté

### Diagramme de flux SSOT

```
┌─────────────────────────────────────────────────────────────┐
│ SSOT Sources Réseau                                         │
├─────────────────────────────────────────────────────────────┤
│ • docs/network-design.md → Architecture réseau              │
│ • terraform.tfvars → Plages IP, bridges VMs                │
│ • group_vars/all.yml → DNS, gateway, routes                │
│ • proxmox:/etc/network/interfaces → Bridges physiques      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Création Bridges Proxmox (Infrastructure physique)          │
├─────────────────────────────────────────────────────────────┤
│ /etc/network/interfaces (Proxmox node)                      │
│                                                             │
│ auto vmbr0                                                  │
│ iface vmbr0 inet static                                     │
│     address 172.16.100.1/24                                │
│     bridge-ports eth0                                       │
│     bridge-stp off                                          │
│     bridge-fd 0                                             │
│                                                             │
│ auto vmbr1                                                  │
│ iface vmbr1 inet static                                     │
│     address 172.16.200.1/24                                │
│     bridge-ports eth1                                       │
│     bridge-stp off                                          │
│     bridge-fd 0                                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Provisionnement VMs (Terraform)                             │
├─────────────────────────────────────────────────────────────┤
│ network_device {                                            │
│   model  = "virtio"                                         │
│   bridge = var.nodes[each.key].bridge  # SSOT               │
│ }                                                           │
│                                                             │
│ initialization {                                            │
│   ip_config {                                               │
│     ipv4 {                                                  │
│       address = "${each.value.ip}/${var.cidr_suffix}"      │
│       gateway = var.gateway                                 │
│     }                                                       │
│   }                                                         │
│ }                                                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Configuration Réseau VMs (Cloud-init + Ansible)             │
├─────────────────────────────────────────────────────────────┤
│ • Cloud-init → IP statique + gateway (premier boot)        │
│ • Ansible → Routes statiques, DNS, firewall (continu)      │
│ • Résultat → Connectivité selon segmentation SSOT          │
└─────────────────────────────────────────────────────────────┘
```


### Topologie réseau segmentée (exemple)

```
                    ┌──────────────────┐
                    │   Internet       │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │   Firewall       │
                    │   (pfSense)      │
                    └────────┬─────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
    ┌─────▼─────┐    ┌──────▼──────┐    ┌─────▼─────┐
    │   vmbr0   │    │    vmbr1    │    │   vmbr2   │
    │ Production│    │     DMZ     │    │ Management│
    │172.16.100 │    │ 172.16.200  │    │ 172.16.10 │
    └─────┬─────┘    └──────┬──────┘    └─────┬─────┘
          │                  │                  │
    ┌─────▼─────┐    ┌──────▼──────┐    ┌─────▼─────┐
    │ DB Server │    │ Web Server  │    │  Bastion  │
    │ .100.20   │    │  .200.10    │    │  .10.10   │
    └───────────┘    └─────────────┘    └───────────┘
          │                  │                  │
          └──────────────────┼──────────────────┘
                             │
                    ┌────────▼─────────┐
                    │     vmbr3        │
                    │    Storage       │
                    │   10.0.0.0/24    │
                    └──────────────────┘
```


***

## 📍 Fichiers et code détaillés

### Fichier 1 : `docs/network-design.md` (SSOT architecture réseau)

**Chemin** : `docs/network-design.md`
**Rôle** : Documentation architecture réseau (SSOT)
**Versionné** : ✅ Oui

```markdown
# Architecture Réseau Segmentée (SSOT)

## Vue d'ensemble

L'infrastructure utilise **4 bridges Linux** pour segmenter le trafic réseau selon les best practices DevSecOps.

---

## Segmentation Réseau

### vmbr0 : Production/LAN (172.16.100.0/24)

**Rôle** : Réseau principal pour VMs production avec accès Internet

| Paramètre | Valeur |
|-----------|--------|
| **Bridge Proxmox** | vmbr0 |
| **Interface physique** | eth0 |
| **Gateway Proxmox** | 172.16.100.1 |
| **Plage DHCP** | 172.16.100.100-200 (désactivé) |
| **Plage statique** | 172.16.100.10-99 |
| **DNS** | 1.1.1.1, 1.0.0.1 |

**VMs connectées** :
- `tools-manager` : 172.16.100.20 (Taiga, console web)
- `gitlab-server` : 172.16.100.30 (GitLab CE)
- `monitoring` : 172.16.100.40 (Prometheus, Grafana)

---

### vmbr1 : DMZ (172.16.200.0/24)

**Rôle** : Zone démilitarisée pour services publics

| Paramètre | Valeur |
|-----------|--------|
| **Bridge Proxmox** | vmbr1 |
| **Interface physique** | eth1 (dédiée) |
| **Gateway Proxmox** | 172.16.200.1 |
| **Accès Internet** | Via firewall uniquement |
| **Accès Production** | ❌ Bloqué (firewall) |

**VMs connectées** :
- `web-frontend` : 172.16.200.10 (Nginx reverse proxy)
- `api-gateway` : 172.16.200.20 (Kong API Gateway)

**Règles firewall** :
```bash
# Autoriser Internet → DMZ (ports 80, 443)
# Bloquer DMZ → Production
# Autoriser DMZ → Storage (lecture seule)
```


---

### vmbr2 : Management (172.16.10.0/24)

**Rôle** : Réseau administration isolé (Bastion, backups)


| Paramètre | Valeur |
| :-- | :-- |
| **Bridge Proxmox** | vmbr2 |
| **Interface physique** | - (bridge-only) |
| **Gateway Proxmox** | 172.16.10.1 |
| **Accès Internet** | ❌ Non (sécurité) |
| **Accès via** | Bastion uniquement |

**VMs connectées** :

- `bastion` : 172.16.10.10 (Jump host SSH)
- `backup-server` : 172.16.10.20 (Proxmox Backup Server)

---

### vmbr3 : Storage (10.0.0.0/24)

**Rôle** : Réseau stockage iSCSI/NFS (isolation performance)


| Paramètre | Valeur |
| :-- | :-- |
| **Bridge Proxmox** | vmbr3 |
| **Interface physique** | eth2 (10GbE si dispo) |
| **Gateway** | - (pas de routage) |
| **MTU** | 9000 (jumbo frames) |

**Équipements connectés** :

- NAS TrueNAS : 10.0.0.10
- Proxmox nodes : 10.0.0.1-5

---

## Règles Routage

### VMs Production → Internet

```
172.16.100.0/24 → 172.16.100.1 (Proxmox) → Internet
```


### VMs DMZ → Internet (via firewall)

```
172.16.200.0/24 → 172.16.200.1 (Proxmox) → 172.16.100.254 (Firewall) → Internet
```


### Accès Management (via Bastion)

```
Admin PC → Bastion (172.16.10.10) → VMs Production (ProxyJump SSH)
```


---

## Matrice de Connectivité

| Depuis ↓ / Vers → | Production | DMZ | Management | Storage | Internet |
| :-- | :-- | :-- | :-- | :-- | :-- |
| **Production** | ✅ | ❌ | ❌ | ✅ | ✅ |
| **DMZ** | ❌ | ✅ | ❌ | ✅ (RO) | ✅ |
| **Management** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Storage** | ✅ | ✅ | ✅ | ✅ | ❌ |


---

## VLANs (optionnel)

Pour isoler davantage sans multiplier les bridges physiques :

```
vmbr0.10 → VLAN 10 (Production)
vmbr0.20 → VLAN 20 (DMZ)
vmbr0.30 → VLAN 30 (Management)
```

Configuration Terraform :

```hcl
network_device {
  model   = "virtio"
  bridge  = "vmbr0"
  vlan_id = 10  # VLAN Production
}
```

```

***

### Fichier 2 : `scripts/create-proxmox-bridge.sh` (Création bridge automatique)

**Chemin** : `scripts/create-proxmox-bridge.sh`  
**Rôle** : Script création bridge Proxmox (idempotent)  
**Versionné** : ✅ Oui

```bash
#!/usr/bin/env bash
set -euo pipefail

# ===================================================================
# Création Linux Bridge Proxmox (idempotent)
# ===================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Vérifier arguments
if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <bridge-name> <physical-iface> <ip-cidr> [mtu]"
    echo ""
    echo "Exemples:"
    echo "  $0 vmbr1 eth1 172.16.200.1/24"
    echo "  $0 vmbr3 eth2 10.0.0.1/24 9000  # Jumbo frames"
    exit 1
fi

BRIDGE_NAME="$1"
PHYSICAL_IFACE="$2"
IP_CIDR="$3"
MTU="${4:-1500}"

INTERFACES_FILE="/etc/network/interfaces"
BACKUP_FILE="${INTERFACES_FILE}.backup-$(date +%Y%m%d-%H%M%S)"

echo "=========================================="
echo "Création Bridge Proxmox (SSOT)"
echo "=========================================="
echo "Bridge : ${BRIDGE_NAME}"
echo "Interface physique : ${PHYSICAL_IFACE}"
echo "IP/CIDR : ${IP_CIDR}"
echo "MTU : ${MTU}"
echo "=========================================="
echo ""

# Vérifier exécution sur Proxmox
if [[ ! -f /usr/bin/pvesh ]]; then
    log_error "Ce script doit être exécuté sur un node Proxmox"
    exit 1
fi

# Vérifier interface physique existe
if [[ "${PHYSICAL_IFACE}" != "-" ]] && ! ip link show "${PHYSICAL_IFACE}" &>/dev/null; then
    log_error "Interface physique '${PHYSICAL_IFACE}' introuvable"
    log_warn "Interfaces disponibles :"
    ip -br link | awk '{print "  - " $1}'
    exit 1
fi

# Vérifier si bridge existe déjà
if ip link show "${BRIDGE_NAME}" &>/dev/null; then
    log_warn "Bridge '${BRIDGE_NAME}' existe déjà"
    CURRENT_IP=$(ip -4 addr show "${BRIDGE_NAME}" | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' || echo "")
    if [[ "${CURRENT_IP}" == "${IP_CIDR}" ]]; then
        log_info "Configuration identique (idempotent), rien à faire"
        exit 0
    else
        log_warn "IP actuelle : ${CURRENT_IP}, demandée : ${IP_CIDR}"
        read -rp "Modifier configuration ? (y/N) " CONFIRM
        if [[ "${CONFIRM}" != "y" ]]; then
            log_info "Annulation"
            exit 0
        fi
    fi
fi

# Backup configuration réseau
log_info "Backup configuration : ${BACKUP_FILE}"
cp "${INTERFACES_FILE}" "${BACKUP_FILE}"

# Génération configuration bridge
log_info "Génération configuration bridge..."

BRIDGE_CONFIG="

# ===================================================================
# Bridge ${BRIDGE_NAME} (créé le $(date '+%Y-%m-%d %H:%M:%S'))
# ===================================================================
auto ${BRIDGE_NAME}
iface ${BRIDGE_NAME} inet static
    address ${IP_CIDR}
    bridge-ports $([ "${PHYSICAL_IFACE}" = "-" ] && echo "none" || echo "${PHYSICAL_IFACE}")
    bridge-stp off
    bridge-fd 0"

# Ajouter MTU si différent de 1500
if [[ "${MTU}" != "1500" ]]; then
    BRIDGE_CONFIG+="
    mtu ${MTU}"
fi

# Vérifier si bridge déjà dans fichier
if grep -q "^auto ${BRIDGE_NAME}$" "${INTERFACES_FILE}"; then
    log_warn "Bridge déjà dans ${INTERFACES_FILE}, remplacement..."
    
    # Supprimer ancienne config (dangereux, utiliser sed prudemment)
    sed -i "/^# ===.*${BRIDGE_NAME}/,/^$/d" "${INTERFACES_FILE}"
fi

# Ajouter nouvelle config
echo "${BRIDGE_CONFIG}" >> "${INTERFACES_FILE}"

log_info "Configuration ajoutée à ${INTERFACES_FILE}"

# Appliquer configuration (sans reboot)
log_info "Application configuration (ifreload)..."
if ifreload -a; then
    log_info "✓ Configuration appliquée avec succès"
else
    log_error "Échec application configuration"
    log_warn "Restauration backup..."
    mv "${BACKUP_FILE}" "${INTERFACES_FILE}"
    ifreload -a
    exit 1
fi

# Vérification bridge actif
sleep 2
if ip link show "${BRIDGE_NAME}" | grep -q "state UP"; then
    log_info "✓ Bridge ${BRIDGE_NAME} actif"
else
    log_error "Bridge inactif après application"
    exit 1
fi

# Afficher résumé
echo ""
echo "=========================================="
log_info "Bridge créé avec succès"
echo "=========================================="
echo "Bridge : ${BRIDGE_NAME}"
echo "État : $(ip -br link show "${BRIDGE_NAME}" | awk '{print $2}')"
echo "IP : $(ip -4 addr show "${BRIDGE_NAME}" | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+')"
echo "MTU : $(ip link show "${BRIDGE_NAME}" | grep -oP '(?<=mtu )\d+')"
if [[ "${PHYSICAL_IFACE}" != "-" ]]; then
    echo "Interface physique : ${PHYSICAL_IFACE}"
fi
echo "=========================================="
echo ""
log_info "Commandes suivantes :"
log_info "  # Vérifier bridges : ip -br link | grep vmbr"
log_info "  # Tester connectivité : ping 172.16.200.1"
log_info "  # Rollback si problème : mv ${BACKUP_FILE} ${INTERFACES_FILE} && ifreload -a"
```

**Utilisation** :

```bash
# Copier script sur Proxmox
scp scripts/create-proxmox-bridge.sh root@proxmox:/tmp/

# Exécuter sur Proxmox
ssh root@proxmox

# Créer vmbr1 (DMZ)
/tmp/create-proxmox-bridge.sh vmbr1 eth1 172.16.200.1/24

# Créer vmbr2 (Management, sans interface physique)
/tmp/create-proxmox-bridge.sh vmbr2 - 172.16.10.1/24

# Créer vmbr3 (Storage, jumbo frames)
/tmp/create-proxmox-bridge.sh vmbr3 eth2 10.0.0.1/24 9000
```


***

### Fichier 3 : `terraform.tfvars` (SSOT bridges VMs)

**Chemin** : `terraform.tfvars`
**Modification** : Ajout sélection bridge par VM
**Versionné** : ❌ Non (secrets)

```hcl
# ===================================================================
# SSOT Infrastructure : Attribution bridges (segmentation réseau)
# ===================================================================

# Configuration Proxmox
proxmox_endpoint = "https://192.168.1.100:8006"
proxmox_insecure = true
node_name        = "pve4"
template_vmid    = 9000
datastore_vm     = "local-lvm"

# Clé SSH SSOT
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKey ansible@lab"

# Configuration réseau globale (SSOT)
cidr_suffix = 24
gateway     = "172.16.100.1"

# ===================================================================
# SSOT : Attribution VMs par bridge (segmentation)
# ===================================================================
nodes = {
  # Réseau Production (vmbr0)
  tools-manager = {
    ip     = "172.16.100.20"
    cpu    = 4
    mem    = 8192
    disk   = 50
    bridge = "vmbr0"              # ← SSOT bridge
    tags   = ["tools", "prod"]
  }

  gitlab-server = {
    ip     = "172.16.100.30"
    cpu    = 4
    mem    = 8192
    disk   = 100
    bridge = "vmbr0"
    tags   = ["git", "prod"]
  }

  # Réseau DMZ (vmbr1)
  web-frontend = {
    ip     = "172.16.200.10"
    cpu    = 2
    mem    = 4096
    disk   = 30
    bridge = "vmbr1"              # ← DMZ
    tags   = ["web", "dmz"]
  }

  api-gateway = {
    ip     = "172.16.200.20"
    cpu    = 2
    mem    = 4096
    disk   = 30
    bridge = "vmbr1"
    tags   = ["api", "dmz"]
  }

  # Réseau Management (vmbr2)
  bastion = {
    ip     = "172.16.10.10"
    cpu    = 1
    mem    = 1024
    disk   = 20
    bridge = "vmbr2"              # ← Management
    tags   = ["bastion", "mgmt"]
  }

  backup-server = {
    ip     = "172.16.10.20"
    cpu    = 2
    mem    = 4096
    disk   = 500
    bridge = "vmbr2"
    tags   = ["backup", "mgmt"]
  }

  # Réseau DNS (vmbr0 mais IP spécifique)
  dns-server = {
    ip     = "172.16.100.254"     # Gateway custom pour DNS
    cpu    = 1
    mem    = 1024
    disk   = 20
    bridge = "vmbr0"
    tags   = ["dns", "infra"]
  }
}
```


***

### Fichier 4 : `variables.tf` (Variables bridge)

**Chemin** : `variables.tf`
**Modification** : Ajout variable bridge dans nodes
**Versionné** : ✅ Oui

```hcl
# ===================================================================
# Variables : Infrastructure réseau (SSOT)
# ===================================================================

variable "nodes" {
  description = "Configuration VMs (SSOT)"
  type = map(object({
    ip     = string
    cpu    = number
    mem    = number
    disk   = number
    bridge = string        # ← NOUVEAUTÉ : Bridge Linux
    tags   = list(string)
  }))

  validation {
    condition = alltrue([
      for node in values(var.nodes) : 
      can(regex("^vmbr[0-9]+$", node.bridge))
    ])
    error_message = "Bridge doit être au format vmbr0, vmbr1, etc."
  }
}

variable "gateway" {
  description = "Gateway par défaut (SSOT)"
  type        = string

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.gateway))
    error_message = "Gateway doit être une IP valide"
  }
}

variable "cidr_suffix" {
  description = "CIDR suffix (/24)"
  type        = number
  default     = 24

  validation {
    condition     = var.cidr_suffix >= 16 && var.cidr_suffix <= 30
    error_message = "CIDR doit être entre /16 et /30"
  }
}

# ===================================================================
# NOUVEAUTÉ : Variables réseaux additionnels (optionnel)
# ===================================================================
variable "networks" {
  description = "Configuration réseaux supplémentaires (SSOT)"
  type = map(object({
    bridge  = string
    cidr    = string
    gateway = string
    vlan_id = optional(number)
  }))
  default = {}

  # Exemple d'utilisation :
  # networks = {
  #   dmz = {
  #     bridge  = "vmbr1"
  #     cidr    = "172.16.200.0/24"
  #     gateway = "172.16.200.1"
  #   }
  #   storage = {
  #     bridge  = "vmbr3"
  #     cidr    = "10.0.0.0/24"
  #     gateway = ""
  #   }
  # }
}
```


***

### Fichier 5 : `main.tf` (Utilisation bridge SSOT)

**Chemin** : `main.tf`
**Modification** : Utilisation `each.value.bridge`
**Versionné** : ✅ Oui

```hcl
resource "proxmox_virtual_environment_vm" "vm" {
  for_each  = var.nodes
  name      = each.key
  node_name = var.node_name
  tags      = sort(distinct([for t in each.value.tags : lower(t)]))

  clone {
    vm_id = var.template_vmid
  }

  cpu {
    cores = each.value.cpu
  }

  memory {
    dedicated = each.value.mem
  }

  disk {
    datastore_id = var.datastore_vm
    interface    = "scsi0"
    size         = each.value.disk
  }

  # ===================================================================
  # SSOT : Utilisation bridge défini dans terraform.tfvars
  # ===================================================================
  network_device {
    model  = "virtio"
    bridge = each.value.bridge    # ← SSOT depuis terraform.tfvars
  }

  # ===================================================================
  # OPTIONNEL : Multi-NIC (plusieurs bridges par VM)
  # ===================================================================
  # network_device {
  #   model  = "virtio"
  #   bridge = "vmbr3"             # Réseau Storage additionnel
  # }

  vga {
    type   = "qxl"
    memory = 32
  }

  initialization {
    ip_config {
      ipv4 {
        address = format("%s/%d", each.value.ip, var.cidr_suffix)
        gateway = var.gateway
      }
    }

    user_account {
      username = "ansible"
      keys     = [var.ssh_public_key]
    }
    
    dns {
      servers = ["1.1.1.1", "1.0.0.1"]
    }
  }

  agent {
    enabled = true
  }
}
```


***

### Fichier 6 : `group_vars/all.yml` (Routes statiques Ansible)

**Chemin** : `Ansible/group_vars/all.yml`
**Ajout** : Configuration routes statiques
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# SSOT Configuration réseau globale (routes, DNS)
# ===================================================================

# ... (config existante)

# ===================================================================
# NOUVEAUTÉ : Routes statiques (SSOT)
# ===================================================================
static_routes:
  # Route vers réseau DMZ via firewall
  - destination: "172.16.200.0/24"
    gateway: "172.16.100.254"
    metric: 100
  
  # Route vers réseau Storage (direct)
  - destination: "10.0.0.0/24"
    gateway: "0.0.0.0"          # Direct (pas de gateway)
    metric: 10

# Désactivation IPv6 (optionnel)
disable_ipv6: true

# Configuration MTU personnalisé (optionnel)
network_interfaces:
  - name: eth0
    mtu: 1500
  - name: eth1                  # Interface Storage si multi-NIC
    mtu: 9000                   # Jumbo frames

# ===================================================================
# Configuration Firewall par bridge (SSOT)
# ===================================================================
firewall_rules_by_bridge:
  vmbr0:  # Production
    - rule: allow
      from: "172.16.100.0/24"
      to: any
      port: 80,443
      proto: tcp
  
  vmbr1:  # DMZ
    - rule: deny
      from: "172.16.200.0/24"
      to: "172.16.100.0/24"     # Bloquer DMZ → Production
    - rule: allow
      from: any
      to: "172.16.200.0/24"
      port: 80,443
      proto: tcp
  
  vmbr2:  # Management
    - rule: deny
      from: "172.16.10.0/24"
      to: any                    # Isoler Management
    - rule: allow
      from: "172.16.10.0/24"
      to: "172.16.100.0/24"
      port: 22
      proto: tcp
```


***

### Fichier 7 : `roles/network/tasks/main.yml` (Config réseau Ansible)

**Chemin** : `Ansible/roles/network/tasks/main.yml`
**Rôle** : Configuration routes statiques (idempotent)
**Versionné** : ✅ Oui

```yaml
---
# ===================================================================
# Rôle network : Configuration réseau avancée (idempotent)
# ===================================================================

# ===================================================================
# 1. Configuration routes statiques (SSOT - idempotent)
# ===================================================================
- name: Installer package iproute2
  ansible.builtin.apt:
    name: iproute2
    state: present
  tags: ['network', 'routes']

- name: Créer répertoire systemd-networkd
  ansible.builtin.file:
    path: /etc/systemd/network
    state: directory
    mode: '0755'
  tags: ['network', 'routes']

- name: Configurer routes statiques (SSOT)
  ansible.builtin.template:
    src: 10-static-routes.network.j2
    dest: /etc/systemd/network/10-static-routes.network
    owner: root
    group: root
    mode: '0644'
  notify: Restart systemd-networkd
  when: static_routes is defined and static_routes | length > 0
  tags: ['network', 'routes']

# ===================================================================
# 2. Configuration MTU interfaces (idempotent)
# ===================================================================
- name: Configurer MTU interfaces (SSOT)
  ansible.builtin.command:
    cmd: "ip link set dev {{ item.name }} mtu {{ item.mtu }}"
  loop: "{{ network_interfaces }}"
  when: network_interfaces is defined
  changed_when: false
  tags: ['network', 'mtu']

- name: Rendre MTU persistant (netplan)
  ansible.builtin.template:
    src: 99-custom-mtu.yaml.j2
    dest: /etc/netplan/99-custom-mtu.yaml
    owner: root
    group: root
    mode: '0644'
  notify: Apply netplan
  when: network_interfaces is defined
  tags: ['network', 'mtu']

# ===================================================================
# 3. Désactivation IPv6 (optionnel)
# ===================================================================
- name: Désactiver IPv6 (SSOT)
  ansible.posix.sysctl:
    name: "{{ item }}"
    value: "1"
    state: present
    sysctl_set: true
    reload: true
  loop:
    - net.ipv6.conf.all.disable_ipv6
    - net.ipv6.conf.default.disable_ipv6
    - net.ipv6.conf.lo.disable_ipv6
  when: disable_ipv6 | default(false)
  tags: ['network', 'ipv6']

# ===================================================================
# 4. Vérification connectivité réseau
# ===================================================================
- name: Test connectivité gateway
  ansible.builtin.command:
    cmd: "ping -c 1 {{ gateway }}"
  register: ping_gateway
  changed_when: false
  failed_when: false
  tags: ['network', 'test']

- name: Test résolution DNS
  ansible.builtin.command:
    cmd: "nslookup google.com 1.1.1.1"
  register: dns_test
  changed_when: false
  failed_when: false
  tags: ['network', 'test']

- name: Afficher résultat tests réseau
  ansible.builtin.debug:
    msg:
      - "Gateway ({{ gateway }}) : {{ 'OK' if ping_gateway.rc == 0 else 'FAIL' }}"
      - "DNS (1.1.1.1) : {{ 'OK' if dns_test.rc == 0 else 'FAIL' }}"
  tags: ['network', 'test']
```


***

### Fichier 8 : `roles/network/templates/10-static-routes.network.j2` (Routes systemd)

**Chemin** : `Ansible/roles/network/templates/10-static-routes.network.j2`
**Rôle** : Template routes statiques systemd-networkd
**Versionné** : ✅ Oui

```ini
# ===================================================================
# Routes statiques (SSOT)
# Généré par Ansible le {{ ansible_date_time.iso8601 }}
# ===================================================================

[Match]
Name=eth0

[Route]
{% for route in static_routes %}
# Route vers {{ route.destination }}
{% if route.gateway != "0.0.0.0" %}
Destination={{ route.destination }}
Gateway={{ route.gateway }}
Metric={{ route.metric | default(100) }}
{% else %}
# Route directe (pas de gateway)
Destination={{ route.destination }}
Metric={{ route.metric | default(10) }}
{% endif %}

{% endfor %}
```


***

## 📊 Tableau récapitulatif des fichiers Réseau

| Fichier | Chemin | Rôle SSOT | Versionné |
| :-- | :-- | :-- | :-- |
| `network-design.md` | `docs/` | Documentation architecture | ✅ Oui |
| `create-proxmox-bridge.sh` | `scripts/` | Création bridge Proxmox | ✅ Oui |
| `terraform.tfvars` | Racine | Attribution bridges VMs | ❌ Non |
| `variables.tf` | Racine | Définition variable bridge | ✅ Oui |
| `main.tf` | Racine | Utilisation bridge SSOT | ✅ Oui |
| `group_vars/all.yml` | `Ansible/group_vars/` | Routes statiques SSOT | ✅ Oui |
| `roles/network/tasks/main.yml` | `Ansible/roles/network/` | Config réseau avancée | ✅ Oui |
| `roles/network/templates/10-static-routes.network.j2` | `Ansible/roles/network/templates/` | Template routes | ✅ Oui |


***

## 🎯 Workflow DevOps Réseau

### Déploiement initial

```bash
# 1. Créer bridges sur Proxmox
ssh root@proxmox
/tmp/create-proxmox-bridge.sh vmbr1 eth1 172.16.200.1/24
/tmp/create-proxmox-bridge.sh vmbr2 - 172.16.10.1/24

# 2. Définir attribution bridges dans terraform.tfvars (SSOT)
vim terraform.tfvars
# Modifier nodes[].bridge

# 3. Appliquer Terraform
terraform plan
terraform apply

# 4. Configurer routes statiques Ansible
cd Ansible/
ansible-playbook playbooks/site.yml --tags network

# 5. Valider connectivité
./scripts/validate-network.sh
```


### Ajout d'un nouveau réseau

```bash
# 1. Créer bridge Proxmox
ssh root@proxmox
/tmp/create-proxmox-bridge.sh vmbr4 eth3 192.168.50.1/24

# 2. Documenter (SSOT)
vim docs/network-design.md
# Ajouter section vmbr4

# 3. Ajouter VMs sur nouveau bridge
vim terraform.tfvars
# Modifier nodes[<vm>].bridge = "vmbr4"

# 4. Appliquer
terraform apply
```


### Modification segmentation réseau

```bash
# Déplacer VM de Production (vmbr0) vers DMZ (vmbr1)

# 1. Modifier SSOT
vim terraform.tfvars
# web-server.bridge: "vmbr0" → "vmbr1"
# web-server.ip: "172.16.100.X" → "172.16.200.X"

# 2. Appliquer (recrée VM ou hot-plug si supporté)
terraform plan
terraform apply

# 3. Ajuster firewall Ansible
vim Ansible/group_vars/all.yml
# Ajouter règles firewall_rules_by_bridge[vmbr1]

# 4. Appliquer config
cd Ansible/
ansible-playbook playbooks/site.yml --tags firewall --limit web-server
```


***


