job "fileflows" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "fileflows" {
    count = 1

    network {
      port "http" { static = 5000 }
    }

    task "fileflows" {
      driver = "docker"

      config {
        image        = "revenz/fileflows:latest"
        network_mode = "host"
        privileged   = true

        devices = [
          {
            host_path      = "/dev/dri"
            container_path = "/dev/dri"
          }
        ]

        volumes = [
          "/opt/nomad/config-volumes/fileflows/data:/app/Data",
          "/opt/nomad/config-volumes/fileflows/logs:/app/Logs",
          "/opt/nomad/fileflows-temp:/temp",
          "/media/t7/media:/media",
        ]
      }

      env {
        TZ   = "Europe/Copenhagen"
        PUID = "1000"
        PGID = "1000"
      }

      resources {
        cpu    = 2000
        memory = 2048
      }
    }

    service {
      name = "fileflows"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.fileflows.rule=Host(`fileflows.kni.dk`)",
        "traefik.http.routers.fileflows.entrypoints=web",
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
