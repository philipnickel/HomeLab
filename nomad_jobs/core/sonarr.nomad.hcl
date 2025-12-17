job "sonarr" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "sonarr" {
    count = 1

    task "sonarr" {
      driver = "docker"

      config {
        image        = "linuxserver/sonarr:latest"
        network_mode = "container:gluetun"

        volumes = [
          "/opt/nomad/config-volumes/sonarr:/config",
          "/opt/nomad/downloads:/downloads",
          "/media/t7/media:/media",
        ]
      }

      env {
        PUID = "1000"
        PGID = "1000"
        TZ   = "Europe/Copenhagen"
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
