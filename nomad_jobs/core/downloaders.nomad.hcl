job "downloaders" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "downloaders" {
    count = 1

    network {
      port "sabnzbd" { static = 8082 }
    }

    # Gluetun VPN - main task that owns the network
    task "gluetun" {
      driver = "docker"

      config {
        image   = "qmcgaw/gluetun:latest"
        ports   = ["sabnzbd"]
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
          FIREWALL_INPUT_PORTS=8082
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

    # Traefik service registration
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
  }
}
