job "glances" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "glances" {
    count = 1

    network {
      port "http" {
        static = 61208
      }
    }

    task "glances" {
      driver = "docker"

      config {
        image      = "nicolargo/glances:latest-full"
        ports      = ["http"]
        pid_mode   = "host"
        privileged = true

        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:ro",
          "/etc/os-release:/etc/os-release:ro",
        ]
      }

      env {
        GLANCES_OPT = "-w"
        TZ          = "Europe/Copenhagen"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    service {
      name = "glances"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.glances.rule=Host(`glances.kni.dk`)",
        "traefik.http.routers.glances.entrypoints=web",
      ]

      check {
        type     = "http"
        path     = "/api/4/status"
        interval = "30s"
        timeout  = "5s"
      }
    }
  }
}
