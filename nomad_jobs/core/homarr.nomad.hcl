job "homarr" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "default"

  group "homarr" {
    count = 1

    restart {
      attempts = 10
      interval = "30m"
      delay    = "15s"
      mode     = "delay"
    }

    network {
      port "http" {
        static = 7575
        to     = 3000
      }
    }

    task "homarr" {
      driver = "docker"

      config {
        image = "ghcr.io/homarr-labs/homarr:latest"
        ports = ["http"]
        volumes = [
          "/opt/nomad/config-volumes/homarr:/appdata",
        ]
      }

      env {
        TZ                    = "Europe/Copenhagen"
        SECRET_ENCRYPTION_KEY = "6c70ab6bf59d2b0cc6a0d94cb75b665365129c05cb1c4133bd1cc304a7edcdc9"
      }

      resources {
        cpu    = 500
        memory = 2048
      }

      service {
        name = "homarr"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.homarr.rule=Host(`dash.kni.dk`)",
          "traefik.http.routers.homarr.entrypoints=web",
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
