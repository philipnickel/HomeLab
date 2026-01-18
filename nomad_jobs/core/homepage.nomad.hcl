job "homepage" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "default"

  group "homepage" {
    count = 1

    restart {
      attempts = 10
      interval = "30m"
      delay    = "15s"
      mode     = "delay"
    }

    network {
      port "http" {
        static = 3010
        to     = 3000
      }
    }

    task "homepage" {
      driver = "docker"

      config {
        image = "ghcr.io/gethomepage/homepage:latest"
        ports = ["http"]
        volumes = [
          "local/config:/app/config",
        ]
      }

      env {
        TZ                     = "Europe/Copenhagen"
        PUID                   = "1000"
        PGID                   = "1000"
        HOMEPAGE_ALLOWED_HOSTS = "home.kni.dk,192.168.0.201:3010"
      }

      # Services config with secrets from Nomad variables
      template {
        data = <<-EOF
---
- Infrastructure:
    - Proxmox:
        icon: proxmox.png
        href: https://192.168.0.245:8006
        description: Hypervisor
    - Traefik:
        icon: traefik.png
        href: http://traefik.kni.dk
        description: Reverse Proxy
        widget:
          type: traefik
          url: http://192.168.0.201:8080
    - Nomad:
        icon: nomad.png
        href: http://nomad.kni.dk
        description: Container Orchestration
    - OpenMediaVault:
        icon: openmediavault.png
        href: http://omv.kni.dk
        description: NAS Management
        widget:
          type: openmediavault
          url: http://192.168.0.202
          username: {{ with nomadVar "nomad/jobs/homepage" }}{{ .OMV_USERNAME }}{{ end }}
          password: {{ with nomadVar "nomad/jobs/homepage" }}{{ .OMV_PASSWORD }}{{ end }}
    - Glances:
        icon: glances.png
        href: http://glances.kni.dk
        description: System Monitor
        widget:
          type: glances
          url: http://192.168.0.201:61208
          metric: info
          version: 4

- Storage:
    - File Browser:
        icon: filebrowser.png
        href: http://192.168.0.142
        description: NAS File Manager (OMV)

- Media:
    - Jellyfin:
        icon: jellyfin.png
        href: http://jellyfin.kni.dk
        description: Media Server
    - Jellyseerr:
        icon: jellyseerr.png
        href: http://jellyseerr.kni.dk
        description: Media Requests
        widget:
          type: jellyseerr
          url: http://192.168.0.201:5055
          key: {{ with nomadVar "nomad/jobs/homepage" }}{{ .JELLYSEERR_API_KEY }}{{ end }}

- Downloads:
    - SABnzbd:
        icon: sabnzbd.png
        href: http://sabnzbd.kni.dk
        description: Usenet Downloader
        widget:
          type: sabnzbd
          url: http://192.168.0.201:8082/sabnzbd
          key: {{ with nomadVar "nomad/jobs/homepage" }}{{ .SABNZBD_API_KEY }}{{ end }}
    - Prowlarr:
        icon: prowlarr.png
        href: http://prowlarr.kni.dk
        description: Indexer Manager
        widget:
          type: prowlarr
          url: http://192.168.0.201:9696
          key: {{ with nomadVar "nomad/jobs/homepage" }}{{ .PROWLARR_API_KEY }}{{ end }}

- Media Management:
    - Sonarr:
        icon: sonarr.png
        href: http://sonarr.kni.dk
        description: TV Shows
        widget:
          type: sonarr
          url: http://192.168.0.201:8989
          key: {{ with nomadVar "nomad/jobs/homepage" }}{{ .SONARR_API_KEY }}{{ end }}
    - Radarr:
        icon: radarr.png
        href: http://radarr.kni.dk
        description: Movies
        widget:
          type: radarr
          url: http://192.168.0.201:7878
          key: {{ with nomadVar "nomad/jobs/homepage" }}{{ .RADARR_API_KEY }}{{ end }}
    - Bazarr:
        icon: bazarr.png
        href: http://bazarr.kni.dk
        description: Subtitles
        widget:
          type: bazarr
          url: http://192.168.0.201:6767
          key: {{ with nomadVar "nomad/jobs/homepage" }}{{ .BAZARR_API_KEY }}{{ end }}

- Monitoring:
    - Grafana:
        icon: grafana.png
        href: http://grafana.kni.dk
        description: Dashboards
    - Prometheus:
        icon: prometheus.png
        href: http://prometheus.kni.dk
        description: Metrics
EOF
        destination = "local/config/services.yaml"
      }

      # Settings
      template {
        data = <<-EOF
---
title: Home Lab
favicon: https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/homepage.png
theme: dark
color: slate
headerStyle: clean
statusStyle: dot
hideVersion: true
layout:
  Infrastructure:
    style: row
    columns: 5
  Storage:
    style: row
    columns: 1
  Media:
    style: row
    columns: 2
  Downloads:
    style: row
    columns: 2
  Media Management:
    style: row
    columns: 3
  Monitoring:
    style: row
    columns: 2
EOF
        destination = "local/config/settings.yaml"
      }

      # Widgets
      template {
        data = <<-EOF
---
- resources:
    cpu: true
    memory: true
    disk: /

- datetime:
    text_size: xl
    format:
      dateStyle: long
      timeStyle: short
      hourCycle: h23

- search:
    provider: duckduckgo
    target: _blank
EOF
        destination = "local/config/widgets.yaml"
      }

      # Empty files needed by Homepage
      template {
        data        = "---"
        destination = "local/config/bookmarks.yaml"
      }

      template {
        data        = "/* Custom CSS */"
        destination = "local/config/custom.css"
      }

      template {
        data        = "// Custom JS"
        destination = "local/config/custom.js"
      }

      template {
        data        = "---"
        destination = "local/config/docker.yaml"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "homepage"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.homepage.rule=Host(`home.kni.dk`)",
          "traefik.http.routers.homepage.entrypoints=web",
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "5s"
        }
        check_restart {
          limit           = 3
          grace           = "60s"
          ignore_warnings = false
        }
      }
    }
  }
}
