job "jellyfin" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "default"

  # Run on Proxmox node
  constraint {
    attribute = "${node.class}"
    value     = "proxmox"
  }

  group "jellyfin" {
    count = 1

    restart {
      attempts = 10
      interval = "30m"
      delay    = "15s"
      mode     = "delay"
    }

    # Media volume via CSI (NFS from Unraid) - streaming is fine over NFS
    volume "media" {
      type            = "csi"
      source          = "media"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    # Config volume - local for fast access
    volume "config" {
      type      = "host"
      source    = "jellyfin-config-local"
      read_only = false
    }

    network {
      port "http" {
        static = 8096
        to     = 8096
      }
    }

    task "jellyfin" {
      driver = "docker"

      volume_mount {
        volume      = "media"
        destination = "/media"
        read_only   = false
      }

      volume_mount {
        volume      = "config"
        destination = "/config"
        read_only   = false
      }

      config {
        image = "linuxserver/jellyfin:latest"
        ports = ["http"]
      }

      env {
        PUID = "1000"
        PGID = "1000"
        TZ   = "Europe/Copenhagen"
      }

      resources {
        cpu    = 2000
        memory = 1536
      }

      service {
        name = "jellyfin"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.jellyfin.rule=Host(`stream.kni.dk`)",
          "traefik.http.routers.jellyfin.entrypoints=web",
        ]

        check {
          type     = "tcp"
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
