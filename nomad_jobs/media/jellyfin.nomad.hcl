job "jellyfin" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "jellyfin" {
    count = 1

    network {
      port "http" {
        static = 8096
        to     = 8096
      }
    }

    volume "config" {
      type      = "host"
      source    = "config"
      read_only = false
    }

    volume "media" {
      type      = "host"
      source    = "media"
      read_only = false
    }

    update {
      max_parallel     = 1
      min_healthy_time = "30s"
      auto_revert      = true
    }

    task "jellyfin" {
      driver = "docker"

      config {
        image = "jellyfin/jellyfin:latest"
        ports = ["http"]
        volumes = [
          "/opt/nomad/volumes/config/jellyfin:/config",
          "/opt/nomad/volumes/config/jellyfin/cache:/cache",
        ]
      }

      volume_mount {
        volume      = "media"
        destination = "/media"
        read_only   = false
      }

      env {
        JELLYFIN_PublishedServerUrl = "http://jellyfin.kni.dk"
      }

      service {
        name = "jellyfin"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.jellyfin.rule=Host(`jellyfin.kni.dk`)",
          "traefik.http.routers.jellyfin.entrypoints=web",
        ]

        check {
          type     = "http"
          path     = "/health"
          interval = "30s"
          timeout  = "5s"
        }
      }

      resources {
        cpu    = 2000
        memory = 2048
      }
    }
  }
}
