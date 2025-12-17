job "gluetun" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "gluetun" {
    count = 1

    network {
      port "prowlarr" { static = 9696 }
      port "sonarr"   { static = 8989 }
      port "radarr"   { static = 7878 }
      port "bazarr"   { static = 6767 }
      port "sabnzbd"  { static = 8082 }
    }

    task "gluetun" {
      driver = "docker"

      config {
        image          = "qmcgaw/gluetun:latest"
        container_name = "gluetun"
        ports          = ["prowlarr", "sonarr", "radarr", "bazarr", "sabnzbd"]
        cap_add        = ["NET_ADMIN"]

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
          FIREWALL_INPUT_PORTS=9696,8989,7878,6767,8082
        EOF
        destination = "secrets/gluetun.env"
        env         = true
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    # Service registrations for Traefik (ports exposed on gluetun)
    service {
      name = "prowlarr"
      port = "prowlarr"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.prowlarr.rule=Host(`prowlarr.kni.dk`)",
        "traefik.http.routers.prowlarr.entrypoints=web",
      ]
      check {
        type     = "tcp"
        interval = "30s"
        timeout  = "5s"
      }
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
        type     = "tcp"
        interval = "30s"
        timeout  = "5s"
      }
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
        type     = "tcp"
        interval = "30s"
        timeout  = "5s"
      }
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
        type     = "tcp"
        interval = "30s"
        timeout  = "5s"
      }
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
        type     = "tcp"
        interval = "30s"
        timeout  = "5s"
      }
    }
  }
}
