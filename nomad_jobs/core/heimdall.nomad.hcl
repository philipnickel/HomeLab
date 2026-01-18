job "heimdall" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "default"

  group "heimdall" {
    count = 1

    restart {
      attempts = 10
      interval = "30m"
      delay    = "15s"
      mode     = "delay"
    }

    network {
      port "http" {
        static = 8088
        to     = 80
      }
    }

    task "heimdall" {
      driver = "docker"

      config {
        image = "linuxserver/heimdall:latest"
        ports = ["http"]
        volumes = [
          "/opt/nomad/config-volumes/heimdall:/config",
        ]
      }

      env {
        TZ   = "Europe/Copenhagen"
        PUID = "1000"
        PGID = "1000"
      }

      resources {
        cpu    = 100
        memory = 128
      }

      service {
        name = "heimdall"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.heimdall.rule=Host(`dash.kni.dk`)",
          "traefik.http.routers.heimdall.entrypoints=web",
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
