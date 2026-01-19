# Docker Compose Stacks for Portainer

These compose files are designed for Unraid with Portainer. They use standard Unraid paths.

## Folder Structure (Unraid)

```
/mnt/user/
├── appdata/          # Container configs
│   ├── radarr/
│   ├── sonarr/
│   ├── jellyfin/
│   └── ...
└── data/             # Shared data
    ├── media/
    │   ├── movies/
    │   ├── tv/
    │   └── music/
    └── usenet/       # Downloads
        ├── complete/
        └── incomplete/
```

## How to Deploy in Portainer

1. Go to **Stacks** → **Add Stack**
2. Name your stack (e.g., `arr-stack`)
3. Paste the contents of the `.yml` file
4. Click **Deploy the stack**

## Available Stacks

| Stack | Services | Ports |
|-------|----------|-------|
| `arr-stack.yml` | Gluetun VPN, Radarr, Sonarr, Lidarr, Readarr, Prowlarr, Bazarr | 7878, 8989, 8686, 8787, 9696, 6767, 8001 |
| `downloaders.yml` | Gluetun (VPN), SABnzbd | 8080, 8001 |
| `jellyfin.yml` | Jellyfin | 8096 |
| `jellyseerr.yml` | Jellyseerr | 5055 |
| `navidrome.yml` | Navidrome (music) | 4533 |
| `monitoring.yml` | Uptime Kuma, Glances | 3001, 61208 |
| `immich.yml` | Immich (photos) | 2283 |
| `traefik.yml` | Traefik (reverse proxy) | 80, 8080 |

## Environment Variables

For `downloaders.yml`, set these in Portainer's environment section:
- `WIREGUARD_PRIVATE_KEY` - Your ProtonVPN WireGuard key
- `SERVER_COUNTRIES` - VPN server country (default: Netherlands)

## Notes

- All configs persist in `/mnt/user/appdata/<app>`
- PUID/PGID are set to 1000 (adjust if needed)
- Timezone is set to `Europe/Copenhagen`
- `restart: unless-stopped` ensures containers survive reboots
