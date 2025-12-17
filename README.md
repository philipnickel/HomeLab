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
├── config/nomad/
│   ├── thinkpad.hcl               # ThinkPad server + client
│   └── macbook.hcl                # MacBook client
└── nomad_jobs/
    ├── core/
    │   ├── traefik.nomad.hcl      # Reverse proxy
    │   └── vpn.nomad.hcl          # Gluetun + arr stack + jellyseerr
    └── media/
        └── jellyfin.nomad.hcl     # Media server (no VPN)
```

## Deployment

### Start Nomad Client (Mac)

Join the cluster as a client to deploy jobs:

```bash
sudo nomad agent -config=config/nomad/macbook.hcl
```

### Deploy Jobs

Once connected to the cluster:

```bash
# Set WireGuard key
export NOMAD_VAR_wireguard_private_key="..."

# Deploy all jobs
nomad job run nomad_jobs/core/traefik.nomad.hcl
nomad job run nomad_jobs/core/vpn.nomad.hcl
nomad job run nomad_jobs/media/jellyfin.nomad.hcl
```

Jobs target the ThinkPad via the `shared_mount` constraint.

### Stop Jobs

```bash
nomad job stop vpn
nomad job stop -purge vpn  # Also removes history
```

## Server Setup

Copy the Nomad config to the ThinkPad:

```bash
scp config/nomad/thinkpad.hcl homelab:/tmp/
ssh homelab "sudo cp /tmp/thinkpad.hcl /etc/nomad.d/nomad.hcl && sudo systemctl restart nomad"
```

## Monitoring

```bash
# Cluster status
nomad node status

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
