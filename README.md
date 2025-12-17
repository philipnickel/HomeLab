# HomeLab

A self-hosted media server stack running on HashiCorp Nomad with VPN protection.

## Architecture

```
                            ThinkPad Server (192.168.0.39)

 ┌─────────────────────────────────────────────────────────────────────────┐
 │                                                                         │
 │  Infrastructure                                                         │
 │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                  │
 │  │    Nomad     │  │    Consul    │  │  Tailscale   │                  │
 │  │ (Scheduler)  │  │  (Discovery) │  │   (Access)   │                  │
 │  └──────────────┘  └──────────────┘  └──────────────┘                  │
 │                                                                         │
 │  ┌─────────────────────────────────────────────────────────────────┐   │
 │  │                         Traefik                                  │   │
 │  │              *.kni.dk → internal services                        │   │
 │  └─────────────────────────────────────────────────────────────────┘   │
 │                                                                         │
 │  ┌─────────────────────────────────────────────────────────────────┐   │
 │  │                    VPN Job (Gluetun + Sidecars)                  │   │
 │  │                      ProtonVPN / WireGuard                       │   │
 │  │                                                                  │   │
 │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │   │
 │  │  │ SABnzbd  │ │ Prowlarr │ │  Sonarr  │ │  Radarr  │           │   │
 │  │  │  :8082   │ │  :9696   │ │  :8989   │ │  :7878   │           │   │
 │  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘           │   │
 │  │  ┌──────────┐ ┌────────────┐                                    │   │
 │  │  │  Bazarr  │ │ Jellyseerr │                                    │   │
 │  │  │  :6767   │ │   :5055    │                                    │   │
 │  │  └──────────┘ └────────────┘                                    │   │
 │  └─────────────────────────────────────────────────────────────────┘   │
 │                                                                         │
 │  ┌──────────────┐                                                      │
 │  │   Jellyfin   │  ← No VPN (streaming performance)                    │
 │  │    :8096     │                                                      │
 │  └──────────────┘                                                      │
 │                                                                         │
 │  Storage (Host Volumes)                                                │
 │  ├── config    → /opt/nomad/config-volumes                             │
 │  ├── downloads → /opt/nomad/downloads (ext4)                           │
 │  └── media     → /media/t7/media (external USB)                        │
 └─────────────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Port | URL | VPN |
|---------|------|-----|-----|
| Traefik | 80, 8080 | traefik.kni.dk | No |
| Jellyfin | 8096 | jelly.kni.dk | No |
| SABnzbd | 8082 | sabnzbd.kni.dk | Yes |
| Prowlarr | 9696 | prowlarr.kni.dk | Yes |
| Sonarr | 8989 | sonarr.kni.dk | Yes |
| Radarr | 7878 | radarr.kni.dk | Yes |
| Bazarr | 6767 | bazarr.kni.dk | Yes |
| Jellyseerr | 5055 | jellyseerr.kni.dk | Yes |

## Directory Structure

```
HomeLab/
├── .github/workflows/
│   └── deploy.yml             # CI/CD pipeline
├── config/nomad/
│   └── nomad.hcl              # Nomad server config (host volumes, networks)
└── nomad_jobs/
    ├── core/
    │   ├── traefik.nomad.hcl  # Reverse proxy
    │   └── vpn.nomad.hcl      # Gluetun + arr stack + jellyseerr
    └── media/
        └── jellyfin.nomad.hcl # Media server (no VPN)
```

## Deployment

### CI/CD (GitHub Actions)

Jobs are automatically deployed when changes are pushed to `main`. The workflow:

1. **Validates** all job files
2. **Plans** changes and extracts check-index
3. **Deploys** atomically with `-check-index` to prevent race conditions

#### GitHub Secrets Required

Configure these in your repository settings (Settings → Secrets and variables → Actions):

| Secret | Description |
|--------|-------------|
| `NOMAD_ADDR` | Nomad server address (e.g., `http://192.168.0.39:4646`) |
| `WIREGUARD_PRIVATE_KEY` | ProtonVPN WireGuard private key |

#### Manual Deployment

Trigger a deployment manually from Actions → Deploy Nomad Jobs → Run workflow.

You can deploy all jobs or select a specific one (traefik, vpn, jellyfin).

### Local Deployment

For local testing or initial setup:

```bash
export NOMAD_ADDR="http://192.168.0.39:4646"
export NOMAD_VAR_wireguard_private_key="your-key"

# Validate
nomad job validate nomad_jobs/core/vpn.nomad.hcl

# Plan and deploy
nomad job plan nomad_jobs/core/traefik.nomad.hcl
nomad job run nomad_jobs/core/traefik.nomad.hcl
```

### Stop Jobs

```bash
nomad job stop vpn
nomad job stop -purge vpn  # Also removes history
```

## Server Setup

Copy the Nomad config to your server:

```bash
scp config/nomad/nomad.hcl homelab:/tmp/
ssh homelab "sudo cp /tmp/nomad.hcl /etc/nomad.d/nomad.hcl && sudo systemctl restart nomad"
```

## Monitoring

```bash
# Job status
nomad job status vpn

# Logs
nomad alloc logs -job vpn -task gluetun
nomad alloc logs -job vpn -task sabnzbd

# Consul services
consul catalog services
```

## Secrets

Required:
```bash
export NOMAD_VAR_wireguard_private_key="..."
```

Get your WireGuard key from: ProtonVPN → Downloads → WireGuard configuration

## Future

- [ ] qBittorrent (commented out in vpn.nomad.hcl)
- [ ] Prometheus + Grafana

## Sources

- [Deploy and manage jobs | Nomad](https://developer.hashicorp.com/nomad/tutorials/manage-jobs/jobs)
- [Job specification | Nomad](https://developer.hashicorp.com/nomad/docs/job-specification)
- [Nomad Pack](https://developer.hashicorp.com/nomad/tools/nomad-pack)
