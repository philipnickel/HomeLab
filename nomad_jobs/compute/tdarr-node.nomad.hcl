job "tdarr-node" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "compute"

  group "tdarr-node" {
    count = 1

    network {
      port "node" { static = 8267 }
    }

    task "tdarr-node" {
      driver = "docker"

      config {
        image = "ghcr.io/haveagitgat/tdarr_node:latest"
        ports = ["node"]

        volumes = [
          "/tmp/tdarr-cache:/temp",
          "/tmp/homelab-media/media:/media",
        ]
      }

      env {
        nodeName       = "MacBook"
        serverIP       = "192.168.0.39"
        serverPort     = "8266"
        inContainer    = "true"
        ffmpegVersion  = "6"
      }

      resources {
        cpu    = 4000
        memory = 4096
      }
    }
  }
}
