job "speedtest-tracker" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "speedtest" {
    count = 1

    network {
      port "http" {
        static = 8765
        to     = 80
      }
    }

    task "speedtest-tracker" {
      driver = "docker"

      config {
        image = "lscr.io/linuxserver/speedtest-tracker:latest"
        ports = ["http"]

        volumes = [
          "/opt/nomad/config-volumes/speedtest-tracker:/config",
        ]
      }

      env {
        PUID            = "1000"
        PGID            = "1000"
        TZ              = "Europe/Copenhagen"
        APP_KEY         = "base64:qqXLhCEnYXvJXaDC0o5RYQP0BKiNVwxPQUUyPkuFqvU="
        DB_CONNECTION   = "sqlite"
        SPEEDTEST_SCHEDULE = "0 */3 * * *"  # Run every 3 hours
        PRUNE_RESULTS_OLDER_THAN = "30"     # Keep 30 days of results
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }

    service {
      name = "speedtest-tracker"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.speedtest.rule=Host(`speedtest.kni.dk`)",
        "traefik.http.routers.speedtest.entrypoints=web",
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
