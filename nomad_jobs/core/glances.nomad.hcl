job "glances" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "default"

  group "glances" {
    count = 1

    restart {
      attempts = 10
      interval = "30m"
      delay    = "15s"
      mode     = "delay"
    }

    network {
      port "http" {
        static = 61208
        to     = 61208
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

        # Mount host filesystems for accurate disk monitoring
        mount {
          type     = "bind"
          source   = "/"
          target   = "/rootfs"
          readonly = true
          bind_options {
            propagation = "rslave"
          }
        }
      }

      env {
        TZ                      = "Europe/Copenhagen"
        GLANCES_OPT             = "-w"
      }

      resources {
        cpu    = 100
        memory = 256
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
        check_restart {
          limit           = 3
          grace           = "60s"
          ignore_warnings = false
        }
      }
    }
  }
}
