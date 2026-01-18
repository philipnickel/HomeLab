job "navidrome" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "default"

  group "navidrome" {
    count = 1

    restart {
      attempts = 10
      interval = "30m"
      delay    = "15s"
      mode     = "delay"
    }

    # Media volume from OMV NAS
    volume "media" {
      type      = "host"
      read_only = false
      source    = "media"
    }

    network {
      port "http" {
        static = 4533
        to     = 4533
      }
    }

    task "navidrome" {
      driver = "docker"

      volume_mount {
        volume      = "media"
        destination = "/media"
        read_only   = true
      }

      config {
        image = "deluan/navidrome:latest"
        ports = ["http"]

        volumes = [
          "/opt/nomad/config-volumes/navidrome:/data",
        ]
      }

      env {
        ND_SCANSCHEDULE       = "1h"
        ND_LOGLEVEL           = "info"
        ND_SESSIONTIMEOUT     = "24h"
        ND_MUSICFOLDER        = "/media/music"
        ND_DATAFOLDER         = "/data"
        ND_ENABLETRANSCODINGCONFIG = "true"
        ND_ENABLESHARING      = "true"
      }

      resources {
        cpu    = 100
        memory = 256
      }
    }

    service {
      name = "navidrome"
      port = "http"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.navidrome.rule=Host(`music.kni.dk`)",
        "traefik.http.routers.navidrome.entrypoints=web",
      ]

      check {
        type     = "http"
        path     = "/ping"
        interval = "30s"
        timeout  = "5s"
      }

      check_restart {
        limit           = 3
        grace           = "60s"
        ignore_warnings = false
      }
    }
  }
}
