job "vpn" {
  datacenters = ["dc1"]
  type        = "service"

  constraint {
    attribute = "${meta.shared_mount}"
    operator  = "="
    value     = "true"
  }

  group "vpn" {
    count = 1

    network {
      mode = "bridge"

      port "sabnzbd" {
        static = 8082
        to     = 8082
      }
      port "prowlarr" {
        static = 9696
        to     = 9696
      }
      port "sonarr" {
        static = 8989
        to     = 8989
      }
      port "radarr" {
        static = 7878
        to     = 7878
      }
      port "bazarr" {
        static = 6767
        to     = 6767
      }
      port "jellyseerr" {
        static = 5055
        to     = 5055
      }
      # Future: uncomment when adding torrents
      # port "qbittorrent" {
      #   static = 8085
      #   to     = 8085
      # }
    }

    # ============================================
    # GLUETUN - VPN Container (Main Task)
    # ============================================
    task "gluetun" {
      driver = "docker"

      config {
        image = "qmcgaw/gluetun:latest"
        ports = ["sabnzbd", "prowlarr", "sonarr", "radarr", "bazarr", "jellyseerr"]

        cap_add = ["NET_ADMIN"]
        devices = [
          {
            host_path      = "/dev/net/tun"
            container_path = "/dev/net/tun"
          }
        ]

        sysctl = {
          "net.ipv6.conf.all.disable_ipv6" = "1"
        }
      }

      env {
        VPN_SERVICE_PROVIDER  = "protonvpn"
        VPN_TYPE              = "wireguard"
        WIREGUARD_PRIVATE_KEY = "${NOMAD_VAR_wireguard_private_key}"
        SERVER_COUNTRIES      = "Denmark"
        TZ                    = "Europe/Copenhagen"
        HTTPPROXY             = "off"
        SHADOWSOCKS           = "off"
        FIREWALL_INPUT_PORTS  = "8082,9696,8989,7878,6767,5055"
        # Future: add 8085 for qBittorrent
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "gluetun"
        port = "sabnzbd"

        check {
          type     = "tcp"
          interval = "30s"
          timeout  = "5s"
        }
      }
    }

    # ============================================
    # SABNZBD - Usenet Downloader
    # ============================================
    task "sabnzbd" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      config {
        image        = "linuxserver/sabnzbd:latest"
        network_mode = "container:${NOMAD_ALLOC_ID}-gluetun"
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

      service {
        name = "sabnzbd"
        port = "sabnzbd"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.sabnzbd.rule=Host(`sabnzbd.kni.dk`)",
          "traefik.http.routers.sabnzbd.entrypoints=web",
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "5s"
        }
      }
    }

    # ============================================
    # PROWLARR - Indexer Manager
    # ============================================
    task "prowlarr" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      config {
        image        = "linuxserver/prowlarr:latest"
        network_mode = "container:${NOMAD_ALLOC_ID}-gluetun"
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

      service {
        name = "prowlarr"
        port = "prowlarr"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.prowlarr.rule=Host(`prowlarr.kni.dk`)",
          "traefik.http.routers.prowlarr.entrypoints=web",
        ]

        check {
          type     = "http"
          path     = "/ping"
          interval = "30s"
          timeout  = "5s"
        }
      }
    }

    # ============================================
    # SONARR - TV Show Management
    # ============================================
    task "sonarr" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      config {
        image        = "linuxserver/sonarr:latest"
        network_mode = "container:${NOMAD_ALLOC_ID}-gluetun"
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

      service {
        name = "sonarr"
        port = "sonarr"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.sonarr.rule=Host(`sonarr.kni.dk`)",
          "traefik.http.routers.sonarr.entrypoints=web",
        ]

        check {
          type     = "http"
          path     = "/ping"
          interval = "30s"
          timeout  = "5s"
        }
      }
    }

    # ============================================
    # RADARR - Movie Management
    # ============================================
    task "radarr" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      config {
        image        = "linuxserver/radarr:latest"
        network_mode = "container:${NOMAD_ALLOC_ID}-gluetun"
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

      service {
        name = "radarr"
        port = "radarr"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.radarr.rule=Host(`radarr.kni.dk`)",
          "traefik.http.routers.radarr.entrypoints=web",
        ]

        check {
          type     = "http"
          path     = "/ping"
          interval = "30s"
          timeout  = "5s"
        }
      }
    }

    # ============================================
    # BAZARR - Subtitle Management
    # ============================================
    task "bazarr" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      config {
        image        = "linuxserver/bazarr:latest"
        network_mode = "container:${NOMAD_ALLOC_ID}-gluetun"
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

      service {
        name = "bazarr"
        port = "bazarr"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.bazarr.rule=Host(`bazarr.kni.dk`)",
          "traefik.http.routers.bazarr.entrypoints=web",
        ]

        check {
          type     = "http"
          path     = "/ping"
          interval = "30s"
          timeout  = "5s"
        }
      }
    }

    # ============================================
    # JELLYSEERR - Media Requests
    # ============================================
    task "jellyseerr" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      config {
        image        = "fallenbagel/jellyseerr:latest"
        network_mode = "container:${NOMAD_ALLOC_ID}-gluetun"
        volumes = [
          "/opt/nomad/config-volumes/jellyseerr:/app/config",
        ]
      }

      env {
        TZ        = "Europe/Copenhagen"
        LOG_LEVEL = "info"
      }

      resources {
        cpu    = 500
        memory = 512
      }

      service {
        name = "jellyseerr"
        port = "jellyseerr"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.jellyseerr.rule=Host(`jellyseerr.kni.dk`)",
          "traefik.http.routers.jellyseerr.entrypoints=web",
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "5s"
        }
      }
    }

    # ============================================
    # Future: QBITTORRENT - Torrent Client
    # ============================================
    # task "qbittorrent" {
    #   driver = "docker"
    #
    #   lifecycle {
    #     hook    = "poststart"
    #     sidecar = true
    #   }
    #
    #   config {
    #     image        = "linuxserver/qbittorrent:latest"
    #     network_mode = "container:${NOMAD_ALLOC_ID}-gluetun"
    #     volumes = [
    #       "/opt/nomad/config-volumes/qbittorrent:/config",
    #       "/opt/nomad/downloads:/downloads",
    #     ]
    #   }
    #
    #   env {
    #     PUID       = "1000"
    #     PGID       = "1000"
    #     TZ         = "Europe/Copenhagen"
    #     WEBUI_PORT = "8085"
    #   }
    #
    #   resources {
    #     cpu    = 500
    #     memory = 512
    #   }
    #
    #   service {
    #     name = "qbittorrent"
    #     port = "qbittorrent"
    #     tags = [
    #       "traefik.enable=true",
    #       "traefik.http.routers.qbittorrent.rule=Host(`qbit.kni.dk`)",
    #       "traefik.http.routers.qbittorrent.entrypoints=web",
    #     ]
    #
    #     check {
    #       type     = "http"
    #       path     = "/"
    #       interval = "30s"
    #       timeout  = "5s"
    #     }
    #   }
    # }
  }
}

variable "wireguard_private_key" {
  type        = string
  description = "ProtonVPN WireGuard private key"
}
