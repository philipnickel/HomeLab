# HomeLab

Self-hosted media server stack on HashiCorp Nomad with VPN protection.

## Architecture

```
ThinkPad Server (services pool)
├── Consul  (Service Discovery)
├── Nomad   (Orchestration)
├── Traefik (Reverse Proxy)
├── Gluetun + Arr Stack (VPN protected)
└── Jellyfin (Streaming)

MacBook Client (compute pool)
└── Nomad Client
```

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
    ├── core/
    │   ├── traefik.nomad.hcl
    │   └── vpn.nomad.hcl
    └── media/
        └── jellyfin.nomad.hcl
```

## Services

| Service | URL |
|---------|-----|
| Nomad | http://nomad.kni.dk |
| Consul | http://consul.kni.dk |
| Traefik | http://traefik.kni.dk |
| SABnzbd | http://sabnzbd.kni.dk |
| Prowlarr | http://prowlarr.kni.dk |
| Sonarr | http://sonarr.kni.dk |
| Radarr | http://radarr.kni.dk |
| Bazarr | http://bazarr.kni.dk |
| Jellyseerr | http://jellyseerr.kni.dk |
| Jellyfin | http://jellyfin.kni.dk |

## Make Commands

```bash
make bootstrap       # Setup server with Consul, Nomad
make client          # Setup MacBook as Nomad client
make deploy          # Deploy all Nomad jobs
make deploy-traefik  # Deploy Traefik only
make deploy-vpn      # Deploy VPN stack only
make deploy-jellyfin # Deploy Jellyfin only
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
