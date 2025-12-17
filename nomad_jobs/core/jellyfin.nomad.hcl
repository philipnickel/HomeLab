job "jellyfin" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "jellyfin" {
    count = 1

    network {
      port "http" {
        static = 8096
        to     = 8096
      }
    }

    task "jellyfin" {
      driver = "docker"

      config {
        image = "linuxserver/jellyfin:latest"
        ports = ["http"]
        volumes = [
          "/opt/nomad/config-volumes/jellyfin:/config",
          "/media/t7/media:/media",
        ]
      }

      env {
        PUID = "1000"
        PGID = "1000"
        TZ   = "Europe/Copenhagen"
      }

      resources {
        cpu    = 2000
        memory = 2048
      }

      service {
        name = "jellyfin"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.jellyfin.rule=Host(`jellyfin.kni.dk`)",
          "traefik.http.routers.jellyfin.entrypoints=web",
        ]

        check {
          type     = "http"
          path     = "/health"
          interval = "30s"
          timeout  = "5s"
        }
      }
    }
  }
}
