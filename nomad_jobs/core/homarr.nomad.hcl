job "homarr" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "homarr" {
    count = 1

    network {
      port "http" {
        static = 7575
        to     = 7575
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

      template {
        data = <<-EOF
          {{ with nomadVar "nomad/jobs/homarr" }}
          SECRET_ENCRYPTION_KEY={{ .SECRET_ENCRYPTION_KEY }}
          {{ end }}
          TZ=Europe/Copenhagen
        EOF
        destination = "secrets/homarr.env"
        env         = true
      }

      resources {
        cpu    = 500
        memory = 1024
      }
    }

    service {
      name = "homarr"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.homarr.rule=Host(`homarr.kni.dk`)",
        "traefik.http.routers.homarr.entrypoints=web",
      ]

      check {
        type     = "tcp"
        interval = "30s"
        timeout  = "5s"
      }
    }
  }
}
