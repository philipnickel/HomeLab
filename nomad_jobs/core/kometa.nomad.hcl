job "kometa" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "kometa" {
    count = 1

    task "kometa" {
      driver = "docker"

      config {
        image = "kometateam/kometa:latest"

        volumes = [
          "/opt/nomad/config-volumes/kometa:/config",
        ]
      }

      env {
        PUID           = "1000"
        PGID           = "1000"
        TZ             = "Europe/Copenhagen"
        KOMETA_RUN     = "true"
        KOMETA_TIME    = "03:00"  # Run daily at 3 AM
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
