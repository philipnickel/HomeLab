# HomeLab

Self-hosted media server stack on HashiCorp Nomad with VPN protection.

## Architecture

```
ThinkPad Server (services pool)
├── Consul  (Service Discovery)
├── Vault   (Secrets)
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

# Bootstrap server (installs Consul, Vault, Nomad)
# Vault is auto-initialized and unsealed
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
│           ├── vault/
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
| Consul | http://100.75.14.19:8500 |
| Vault | http://100.75.14.19:8200 |
| Nomad | http://100.75.14.19:4646 |
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
make bootstrap       # Setup server with Consul, Vault, Nomad
make client          # Setup MacBook as Nomad client
make deploy          # Deploy all Nomad jobs
make deploy-traefik  # Deploy Traefik only
make deploy-vpn      # Deploy VPN stack only
make deploy-jellyfin # Deploy Jellyfin only
make clean           # Stop all services on server
```

## Secrets

Secrets are stored in Vault at `secret/vpn`:
- `wireguard_private_key`: ProtonVPN WireGuard private key
- `server_countries`: VPN server country (e.g., "Denmark")

To add/update secrets:
```bash
ssh homelab
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=<root-token-from-.vault-keys>
vault kv put secret/vpn wireguard_private_key="your-key" server_countries="Denmark"
```
