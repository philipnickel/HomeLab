job "homarr" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "homarr" {
    count = 1

    network {
      port "http" { static = 7575 }
    }

    task "homarr" {
      driver = "docker"

      config {
        image = "ghcr.io/ajnart/homarr:latest"
        ports = ["http"]

        volumes = [
          "/opt/nomad/config-volumes/homarr/configs:/app/data/configs",
          "/opt/nomad/config-volumes/homarr/icons:/app/public/icons",
          "/opt/nomad/config-volumes/homarr/data:/data",
          "/var/run/docker.sock:/var/run/docker.sock:ro",
        ]
      }

      env {
        TZ = "Europe/Copenhagen"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    service {
      name = "homarr"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.homarr.rule=Host(`kni.dk`) || Host(`homarr.kni.dk`)",
        "traefik.http.routers.homarr.entrypoints=web",
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
