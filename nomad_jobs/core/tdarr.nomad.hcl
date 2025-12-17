job "tdarr" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "tdarr" {
    count = 1

    network {
      port "webui" { static = 8265 }
      port "server" { static = 8266 }
    }

    task "tdarr" {
      driver = "docker"

      config {
        image = "ghcr.io/haveagitgat/tdarr:latest"
        ports = ["webui", "server"]

        volumes = [
          "/opt/nomad/config-volumes/tdarr/server:/app/server",
          "/opt/nomad/config-volumes/tdarr/configs:/app/configs",
          "/opt/nomad/config-volumes/tdarr/logs:/app/logs",
          "/opt/nomad/tdarr-transcode-cache:/temp",
          "/media/t7/media:/media",
        ]
      }

      env {
        PUID            = "1000"
        PGID            = "1000"
        TZ              = "Europe/Copenhagen"
        serverIP        = "0.0.0.0"
        serverPort      = "8266"
        webUIPort       = "8265"
        internalNode    = "true"
        inContainer     = "true"
        ffmpegVersion   = "6"
        nodeName        = "InternalNode"
      }

      resources {
        cpu    = 2000
        memory = 2048
      }
    }

    service {
      name = "tdarr"
      port = "webui"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.tdarr.rule=Host(`tdarr.kni.dk`)",
        "traefik.http.routers.tdarr.entrypoints=web",
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
