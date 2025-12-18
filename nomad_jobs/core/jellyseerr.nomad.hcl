job "jellyseerr" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "jellyseerr" {
    count = 1

    network {
      port "http" {
        static = 5055
        to     = 5055
      }
    }

    task "jellyseerr" {
      driver = "docker"

      config {
        image = "fallenbagel/jellyseerr:latest"
        ports = ["http"]
        volumes = [
          "/opt/nomad/config-volumes/jellyseerr:/app/config",
        ]
      }

      env {
        TZ        = "Europe/Copenhagen"
        LOG_LEVEL = "info"
      }

      resources {
        cpu    = 500
        memory = 512
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
      }
    }
  }
}
