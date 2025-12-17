job "sabnzbd" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "sabnzbd" {
    count = 1

    task "sabnzbd" {
      driver = "docker"

      config {
        image        = "linuxserver/sabnzbd:latest"
        network_mode = "container:gluetun"

        volumes = [
          "/opt/nomad/config-volumes/sabnzbd:/config",
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
        memory = 1024
      }
    }
  }
}
