job "jellyseerr" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "default"

  # Run on Proxmox node alongside other services
  constraint {
    attribute = "${node.class}"
    value     = "proxmox"
  }

  group "jellyseerr" {
    count = 1

    restart {
      attempts = 10
      interval = "30m"
      delay    = "15s"
      mode     = "delay"
    }

    # Config volume - local for fast access
    volume "config" {
      type      = "host"
      source    = "jellyseerr-config-local"
      read_only = false
    }

    network {
      port "http" {
        static = 5055
        to     = 5055
      }
    }

    task "jellyseerr" {
      driver = "docker"

      volume_mount {
        volume      = "config"
        destination = "/app/config"
        read_only   = false
      }

      config {
        image = "fallenbagel/jellyseerr:latest"
        ports = ["http"]
      }

      env {
        TZ        = "Europe/Copenhagen"
        LOG_LEVEL = "info"
      }

      resources {
        cpu    = 500
        memory = 768
      }

      service {
        name = "jellyseerr"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.jellyseerr.rule=Host(`req.kni.dk`)",
          "traefik.http.routers.jellyseerr.entrypoints=web",
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
