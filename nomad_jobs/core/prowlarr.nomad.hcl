job "prowlarr" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "prowlarr" {
    count = 1

    task "prowlarr" {
      driver = "docker"

      config {
        image        = "linuxserver/prowlarr:latest"
        network_mode = "container:gluetun"

        volumes = [
          "/opt/nomad/config-volumes/prowlarr:/config",
        ]
      }

      env {
        PUID = "1000"
        PGID = "1000"
        TZ   = "Europe/Copenhagen"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
