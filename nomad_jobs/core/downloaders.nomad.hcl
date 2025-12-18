job "downloaders" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "downloaders" {
    count = 1

    network {
      port "sabnzbd"         { static = 8082 }
      port "qbittorrent"     { static = 8085 }
      port "gluetun_control" { static = 8001 }
    }

    # Gluetun VPN - main task that owns the network
    task "gluetun" {
      driver = "docker"

      config {
        image   = "qmcgaw/gluetun:latest"
        ports   = ["sabnzbd", "qbittorrent", "gluetun_control"]
        cap_add = ["NET_ADMIN"]

        devices = [{
          host_path      = "/dev/net/tun"
          container_path = "/dev/net/tun"
        }]
      }

      template {
        data = <<-EOF
          {{ with nomadVar "nomad/jobs/vpn" }}
          VPN_SERVICE_PROVIDER=protonvpn
          VPN_TYPE=wireguard
          WIREGUARD_PRIVATE_KEY={{ .WIREGUARD_PRIVATE_KEY }}
          SERVER_COUNTRIES={{ .SERVER_COUNTRIES }}
          {{ end }}
          TZ=Europe/Copenhagen
          FIREWALL_INPUT_PORTS=8082,8085,8001
          HTTP_CONTROL_SERVER_ADDRESS=:8001
        EOF
        destination = "secrets/gluetun.env"
        env         = true
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    # SABnzbd - usenet downloader
    task "sabnzbd" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      config {
        image        = "linuxserver/sabnzbd:latest"
        network_mode = "container:gluetun-${NOMAD_ALLOC_ID}"

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

    # qBittorrent - torrent downloader
    task "qbittorrent" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      config {
        image        = "linuxserver/qbittorrent:latest"
        network_mode = "container:gluetun-${NOMAD_ALLOC_ID}"

        volumes = [
          "/opt/nomad/config-volumes/qbittorrent:/config",
          "/opt/nomad/downloads:/downloads",
        ]
      }

      env {
        PUID            = "1000"
        PGID            = "1000"
        TZ              = "Europe/Copenhagen"
        WEBUI_PORT      = "8085"
      }

      resources {
        cpu    = 500
        memory = 1024
      }
    }

    # Traefik service registrations
    service {
      name = "sabnzbd"
      port = "sabnzbd"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.sabnzbd.rule=Host(`sabnzbd.kni.dk`)",
        "traefik.http.routers.sabnzbd.entrypoints=web",
      ]
      check {
        type     = "tcp"
        interval = "30s"
        timeout  = "5s"
      }
    }

    service {
      name = "qbittorrent"
      port = "qbittorrent"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.qbittorrent.rule=Host(`qbittorrent.kni.dk`)",
        "traefik.http.routers.qbittorrent.entrypoints=web",
      ]
      check {
        type     = "tcp"
        interval = "30s"
        timeout  = "5s"
      }
    }
  }
}
