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

## Setup

### Prerequisites

- Tailscale configured on target machine
- Ansible installed locally

### Server Setup

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml setup-server.yml
```

This installs and configures:
- Consul (service discovery)
- Vault (secrets management)
- Nomad (job orchestration)

### Client Setup (optional)

Add another machine as a Nomad client:

```bash
ansible-playbook -i inventory/hosts.yml setup-client.yml --limit macbook
```

### Initialize Vault (first time)

```bash
export VAULT_ADDR=http://192.168.0.39:8200
vault operator init
vault operator unseal  # Run 3 times with different keys
```

### Deploy Jobs

```bash
export NOMAD_ADDR=http://192.168.0.39:4646
nomad job run nomad_jobs/core/traefik.nomad.hcl
nomad job run nomad_jobs/core/vpn.nomad.hcl
nomad job run nomad_jobs/media/jellyfin.nomad.hcl
```

## Directory Structure

```
HomeLab/
├── ansible/
│   ├── inventory/hosts.yml
│   ├── group_vars/all.yml
│   ├── setup-server.yml
│   ├── setup-client.yml
│   └── roles/
│       ├── consul/
│       ├── vault/
│       ├── nomad/
│       └── nomad_client/
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
| Consul | 8500 | http://192.168.0.39:8500 |
| Vault | 8200 | http://192.168.0.39:8200 |
| Nomad | 4646 | http://192.168.0.39:4646 |
| Traefik | 80/8080 | traefik.kni.dk |
| Jellyfin | 8096 | jelly.kni.dk |
