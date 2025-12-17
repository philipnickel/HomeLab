job "bazarr" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "bazarr" {
    count = 1

    task "bazarr" {
      driver = "docker"

      config {
        image        = "linuxserver/bazarr:latest"
        network_mode = "container:gluetun"

        volumes = [
          "/opt/nomad/config-volumes/bazarr:/config",
          "/media/t7/media:/media",
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
