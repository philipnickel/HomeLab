# HomeLab

Infrastructure-as-Code home server running on Proxmox with HashiCorp Nomad orchestration and OpenMediaVault for shared storage.

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                            ACEMAGIC Mini PC                                  │
│                         Intel N97 / 16GB RAM                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│                              Proxmox VE                                      │
│                                                                              │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────────────────────┐ │
│  │  nomad-server  │  │  nomad-client  │  │       openmediavault          │ │
│  │    (1.5GB)     │  │    (10GB)      │  │          (2GB)                │ │
│  │                │  │                │  │                                │ │
│  │ • Nomad Server │  │ • Nomad Client │  │ • SMB → Mac/Laptop            │ │
│  │ • Consul       │  │ • Docker       │  │ • NFS → Shared Data           │ │
│  │ • Traefik      │  │ • Containers   │  │ • Tailscale → Remote Access  │ │
│  └────────────────┘  │ • Local Configs│  └────────────────────────────────┘ │
│                      └────────────────┘                                      │
│         │                    │                         │                     │
│         │ Consul DNS         │                         │                     │
│         │ (service.consul)   │                         │                     │
│         └────────────────────┤                         │                     │
│                              │                         │                     │
│  ┌───────────────────────────┴─────┐    ┌─────────────▼─────────────────┐   │
│  │         NVMe 500GB              │    │         SSD 2TB               │   │
│  │  ├── Proxmox OS (30GB)          │    │      + NVMe ~300GB            │   │
│  │  ├── nomad-server disk (20GB)   │    │                               │   │
│  │  ├── nomad-client disk (40GB)   │    │  ┌─────────────────────────┐  │   │
│  │  │   └── /opt/nomad/configs/    │    │  │   mergerfs (~2.2TB)     │  │   │
│  │  ├── OMV disk (10GB)            │    │  │  ├── /media             │  │   │
│  │  └── NAS pool (~300GB) ─────────│───►│  │  ├── /downloads         │  │   │
│  └─────────────────────────────────┘    │  │  └── /personal          │  │   │
│                                          │  └─────────────────────────┘  │   │
│                                          └───────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────┘
                                    │
                              Tailscale VPN
                                    │
                 ┌──────────────────┼──────────────────┐
                 ▼                  ▼                  ▼
              MacBook           iPhone            Anywhere
           (mount SMB)       (Jellyfin)        (via Tailscale)
```

## Service Discovery

Services communicate via **Consul DNS** instead of hardcoded IPs:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Sonarr    │────►│   Consul    │◄────│   SABnzbd   │
│             │     │    DNS      │     │             │
│ connects to:│     │             │     │ registered: │
│ sabnzbd.    │     │ *.service.  │     │ sabnzbd.    │
│ service.    │     │   consul    │     │ service.    │
│ consul:8082 │     │             │     │ consul:8082 │
└─────────────┘     └─────────────┘     └─────────────┘
```

| Service | Consul Address |
|---------|----------------|
| Sonarr | `sonarr.service.consul:8989` |
| Radarr | `radarr.service.consul:7878` |
| Prowlarr | `prowlarr.service.consul:9696` |
| Bazarr | `bazarr.service.consul:6767` |
| SABnzbd | `sabnzbd.service.consul:8082` |
| Jellyfin | `jellyfin.service.consul:8096` |

No hardcoded IPs in service configurations!

## Services

### Media Stack

| Service | URL | Description |
|---------|-----|-------------|
| Jellyfin | `stream.kni.dk` | Media streaming server |
| Jellyseerr | `req.kni.dk` | Request management for movies/TV |

### Arr Stack (VPN Protected)

| Service | URL | Description |
|---------|-----|-------------|
| Prowlarr | `prowlarr.kni.dk` | Indexer manager |
| Sonarr | `sonarr.kni.dk` | TV show automation |
| Radarr | `radarr.kni.dk` | Movie automation |
| Bazarr | `bazarr.kni.dk` | Subtitle automation |
| SABnzbd | `sabnzbd.kni.dk` | Usenet downloader |

### Infrastructure

| Service | URL | Description |
|---------|-----|-------------|
| Traefik | `traefik.kni.dk` | Reverse proxy & SSL |
| Nomad | `nomad.kni.dk` | Container orchestration |
| Consul | `consul.kni.dk` | Service discovery & DNS |
| Homepage | `home.kni.dk` | Dashboard |

### Monitoring

| Service | URL | Description |
|---------|-----|-------------|
| Grafana | `grafana.kni.dk` | Dashboards & visualization |
| Prometheus | `prometheus.kni.dk` | Metrics collection |

## Storage Architecture

### What Lives Where

| Location | Type | Contents | Access |
|----------|------|----------|--------|
| **nomad-client local** | Host Volume | Service configs | Single service |
| **OMV: /media** | NFS | Movies, TV, Photos | Multi-reader |
| **OMV: /downloads** | NFS | SABnzbd temp files | SABnzbd + *arrs |
| **OMV: /personal** | SMB only | Notes, courses, docs | Mac/Laptop |

### Why This Split?

- **Configs stay local**: Fast, no NFS overhead, only one service needs them
- **Media on NFS**: Shared between Jellyfin, Sonarr, Radarr
- **Downloads on NFS**: SABnzbd writes, *arrs read and import
- **Personal on SMB**: Not for Nomad, just for your Mac

### Download Workflow

```
SABnzbd                         Sonarr/Radarr                    Media
┌─────────────┐                ┌─────────────┐                ┌─────────────┐
│ /downloads/ │                │             │                │ /media/     │
│ ├── incomplete/ ──download──►│  Import &   │───hardlink────►│ ├── Film/   │
│ └── complete/   ◄──move──────│  Organize   │   or copy      │ └── Shows/  │
└─────────────┘                └─────────────┘                └─────────────┘
     (temp)                                                      (permanent)
```

## Infrastructure as Code

This repository is the **source of truth** for the entire homelab.

```
HomeLab/
├── terraform/
│   └── proxmox/
│       ├── main.tf                 # Provider configuration
│       ├── variables.tf            # VM specs, IPs, resources
│       ├── vms.tf                  # VM definitions
│       └── terraform.tfvars        # Your values (gitignored)
│
├── ansible/
│   ├── inventory.yml               # Host definitions
│   ├── site.yml                    # Main playbook
│   └── roles/
│       ├── common/                 # Base setup, packages
│       ├── docker/                 # Docker installation
│       ├── consul/                 # Consul server/agent + DNS
│       ├── nomad-server/           # Nomad server config
│       ├── nomad-client/           # Nomad client + host volumes
│       ├── tailscale/              # Tailscale on all nodes
│       └── nomad-jobs/             # Deploy all Nomad jobs
│
├── nomad_jobs/
│   ├── csi/
│   │   └── nfs-csi.nomad.hcl       # NFS CSI plugin
│   ├── volumes/
│   │   ├── media.volume.hcl        # Shared media volume
│   │   └── downloads.volume.hcl    # Shared downloads volume
│   └── core/
│       ├── traefik.nomad.hcl
│       ├── arr-stack.nomad.hcl     # Prowlarr, Sonarr, Radarr, Bazarr
│       ├── downloaders.nomad.hcl   # SABnzbd + Gluetun
│       ├── jellyfin.nomad.hcl
│       ├── jellyseerr.nomad.hcl
│       ├── homepage.nomad.hcl
│       └── monitoring.nomad.hcl
│
└── docs/
    ├── setup-guide.md
    ├── disaster-recovery.md
    └── adding-services.md
```

## Quick Start (New Hardware)

### Prerequisites

- Proxmox VE installed on the host
- Terraform and Ansible installed locally
- Tailscale account

### Full Deployment (One Command)

```bash
# Clone repo
git clone https://github.com/yourusername/HomeLab.git
cd HomeLab

# Configure
cp terraform/proxmox/terraform.tfvars.example terraform/proxmox/terraform.tfvars
cp ansible/inventory.yml.example ansible/inventory.yml
# Edit both files with your values

# Deploy everything
make deploy
```

### Step-by-Step Deployment

```bash
# 1. Provision VMs
cd terraform/proxmox
terraform init && terraform apply

# 2. Configure VMs + Deploy Jobs
cd ../../ansible
ansible-playbook site.yml
```

### Selective Deployment

```bash
# Infrastructure only (no jobs)
ansible-playbook site.yml --tags infrastructure

# Jobs only (infra already exists)
ansible-playbook site.yml --tags nomad-jobs

# Single role
ansible-playbook site.yml --tags consul
```

### Post-Deployment: OpenMediaVault Setup

```bash
# Access OMV web UI at http://192.168.0.202
# 1. Create mergerfs pool (2TB SSD + NVMe partition)
# 2. Create shared folders: media, downloads, personal
# 3. Enable NFS (media, downloads) and SMB (personal, media)
# 4. Install Tailscale plugin for remote access
```

## Consul DNS Configuration

For containers to resolve `*.service.consul`:

```hcl
# In Nomad job, Docker config:
config {
  image = "linuxserver/sonarr:latest"
  dns_servers = ["${attr.unique.network.ip-address}"]
  dns_search_domains = ["service.consul"]
}
```

Or configure system-wide on nomad-client:
```bash
# /etc/systemd/resolved.conf.d/consul.conf
[Resolve]
DNS=127.0.0.1:8600
Domains=~consul
```

## Remote Access

### Tailscale Setup

1. **OpenMediaVault** has Tailscale installed
2. **SMB shares** accessible at `100.x.x.x` (Tailscale IP)
3. **Mac/Laptop** can mount shares persistently

### Mount NAS on Mac

```bash
# Connect via Finder: Go → Connect to Server
smb://100.x.x.x/personal

# Or via command line
mount_smbfs //user@100.x.x.x/personal ~/NAS/personal
```

## Resilience & Recovery

### Automatic Recovery

| Event | Recovery |
|-------|----------|
| Container crash | Nomad restarts (check_restart) |
| Health check fail | Nomad restarts after 3 failures |
| VM reboot | Services auto-start via systemd |
| Proxmox reboot | VMs auto-start (onboot: 1) |
| Complete rebuild | `terraform apply` + `ansible-playbook site.yml` |

### Backup Strategy

| Data | Location | Method | Frequency |
|------|----------|--------|-----------|
| Service configs | nomad-client | VM snapshot | Weekly |
| Media | OMV | N/A (replaceable) | - |
| Personal files | OMV | Backblaze B2 sync | Daily |
| Infrastructure | Git repo | Commit on change | Always |

## Secrets Management

Secrets stored in **Nomad Variables** (encrypted at rest):

```bash
# VPN credentials
nomad var put nomad/jobs/vpn \
  WIREGUARD_PRIVATE_KEY="..." \
  SERVER_COUNTRIES="Denmark"

# Monitoring
nomad var put nomad/jobs/monitoring \
  PVE_USER="root@pam" \
  PVE_TOKEN_NAME="prometheus" \
  PVE_TOKEN_VALUE="..."
```

## Hardware

| Component | Spec |
|-----------|------|
| **Host** | ACEMAGIC S1 Mini PC |
| **CPU** | Intel N97 (4 cores) |
| **RAM** | 16GB DDR4 |
| **Storage** | 500GB NVMe + 2TB SATA SSD |
| **Network** | 1Gbps Ethernet |

### RAM Allocation

| VM | RAM | Purpose |
|----|-----|---------|
| Proxmox | ~1GB | Hypervisor overhead |
| nomad-server | 1.5GB | Nomad, Consul, Traefik |
| nomad-client | 10GB | Container workloads |
| openmediavault | 2GB | NAS services |
| **Buffer** | 1.5GB | Safety margin |

## Network

| IP | Hostname | Purpose |
|----|----------|---------|
| 192.168.0.245 | proxmox | Hypervisor |
| 192.168.0.200 | nomad-server | Nomad/Consul/Traefik |
| 192.168.0.201 | nomad-client | Container workloads |
| 192.168.0.202 | omv | OpenMediaVault NAS |

## License

MIT
