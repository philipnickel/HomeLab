job "homepage" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "homepage" {
    count = 1

    network {
      port "http" {
        static = 3001
        to     = 3000
      }
    }

    task "homepage" {
      driver = "docker"

      config {
        image = "ghcr.io/gethomepage/homepage:latest"
        ports = ["http"]

        volumes = [
          "/opt/nomad/config-volumes/homepage:/app/config",
          "/media/t7:/media/t7:ro",
        ]
      }

      env {
        PUID                   = "1000"
        PGID                   = "1000"
        HOMEPAGE_ALLOWED_HOSTS = "home.kni.dk,kni.dk,192.168.0.39:3001"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    service {
      name = "homepage"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.homepage.rule=Host(`home.kni.dk`) || Host(`kni.dk`)",
        "traefik.http.routers.homepage.entrypoints=web",
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
