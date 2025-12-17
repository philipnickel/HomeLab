job "radarr" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "radarr" {
    count = 1

    task "radarr" {
      driver = "docker"

      config {
        image        = "linuxserver/radarr:latest"
        network_mode = "container:gluetun"

        volumes = [
          "/opt/nomad/config-volumes/radarr:/config",
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
