# HomeLab

Self-hosted media server stack on HashiCorp Nomad with VPN protection.

## Architecture

```
ThinkPad Server
├── Consul  (Service Discovery)
├── Vault   (Secrets)
├── Nomad   (Orchestration)
└── Traefik (Reverse Proxy)

Services:
├── Gluetun + Arr Stack (VPN protected)
└── Jellyfin (Streaming)
```

## Prerequisites

- Tailscale configured on target machine
- Ansible installed locally

## Quick Start

```bash
cd ansible

# Bootstrap server (installs Consul, Vault, Nomad)
make bootstrap

# Initialize Vault (first time only)
export VAULT_ADDR=http://homelab:8200
vault operator init
vault operator unseal  # Run 3 times with different keys

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
│       ├── group_vars/
│       │   └── all.yml
│       └── roles/
│           ├── consul/
│           ├── vault/
│           └── nomad/
└── nomad_jobs/
    ├── core/
    │   ├── traefik.nomad.hcl
    │   └── vpn.nomad.hcl
    └── media/
        └── jellyfin.nomad.hcl
```

## Services

| Service | Port | URL |
|---------|------|-----|
| Consul | 8500 | http://homelab:8500 |
| Vault | 8200 | http://homelab:8200 |
| Nomad | 4646 | http://homelab:4646 |
| Traefik | 80/8080 | traefik.kni.dk |
| Jellyfin | 8096 | jelly.kni.dk |

## Make Commands

```bash
make bootstrap  # Setup server with Consul, Vault, Nomad
make deploy     # Deploy Nomad jobs (Traefik, VPN, Jellyfin)
make clean      # Stop all services on server
```
