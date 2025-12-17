# HomeLab

Self-hosted media server stack on HashiCorp Nomad with VPN protection.

## Architecture

```
ThinkPad Server (services pool)
├── Consul    (Service Discovery)
├── Nomad     (Orchestration)
├── Traefik   (Reverse Proxy)
│
├── arr-stack (VPN: Gluetun + Prowlarr + Sonarr + Radarr + Bazarr)
├── downloaders (VPN: Gluetun + SABnzbd + qBittorrent)
│
├── Jellyfin   (Media Streaming)
├── Jellyseerr (Request Management)
│
└── monitoring (Prometheus + Grafana + Node Exporter)

MacBook Client (compute pool)
└── Nomad Client
```

## Services

| Service | URL | Description |
|---------|-----|-------------|
| **Infrastructure** |||
| Nomad | http://100.75.14.19:4646 | Orchestration |
| Consul | http://100.75.14.19:8500 | Service Discovery |
| Traefik | http://100.75.14.19:8080 | Reverse Proxy Dashboard |
| **Arr Stack** (VPN Protected) |||
| Prowlarr | http://prowlarr.kni.dk | Indexer Manager |
| Sonarr | http://sonarr.kni.dk | TV Shows |
| Radarr | http://radarr.kni.dk | Movies |
| Bazarr | http://bazarr.kni.dk | Subtitles |
| **Downloaders** (VPN Protected) |||
| SABnzbd | http://sabnzbd.kni.dk | Usenet Downloader |
| qBittorrent | http://qbittorrent.kni.dk | Torrent Client |
| **Media** |||
| Jellyfin | http://jellyfin.kni.dk | Media Server |
| Jellyseerr | http://jellyseerr.kni.dk | Request Management |
| **Monitoring** |||
| Prometheus | http://prometheus.kni.dk | Metrics Collection |
| Grafana | http://grafana.kni.dk | Dashboards |

## Prerequisites

- Tailscale configured on all machines
- Ansible installed locally

## Quick Start

```bash
cd ansible

# Bootstrap server (installs Consul, Nomad)
make bootstrap

# Setup MacBook as Nomad client
make client

# Deploy services
make deploy
```

## Directory Structure

```
HomeLab/
├── ansible/
│   ├── Makefile
│   ├── ansible.cfg
│   ├── deploy.yml
│   └── bootstrap/
│       ├── site.yml
│       ├── hosts.yml
│       ├── group_vars/all.yml
│       └── roles/
│           ├── consul/
│           ├── nomad/
│           └── nomad_client/
└── nomad_jobs/
    └── core/
        ├── traefik.nomad.hcl
        ├── arr-stack.nomad.hcl
        ├── downloaders.nomad.hcl
        ├── jellyfin.nomad.hcl
        ├── jellyseerr.nomad.hcl
        └── monitoring.nomad.hcl
```

## Make Commands

```bash
make bootstrap       # Setup server with Consul, Nomad
make client          # Setup MacBook as Nomad client
make deploy          # Deploy all Nomad jobs
make clean           # Stop all services on server
```

## Secrets

Secrets are stored in Nomad Variables at `nomad/jobs/vpn`:
- `WIREGUARD_PRIVATE_KEY`: ProtonVPN WireGuard private key
- `SERVER_COUNTRIES`: VPN server country (e.g., "Denmark")

To add/update secrets:
```bash
nomad var put -force nomad/jobs/vpn \
  WIREGUARD_PRIVATE_KEY="your-key" \
  SERVER_COUNTRIES="Denmark"
```

## Data Paths

| Path | Purpose |
|------|---------|
| `/opt/nomad/config-volumes/{service}` | Service configurations |
| `/opt/nomad/downloads` | Download directory |
| `/media/t7/media` | Media storage |
