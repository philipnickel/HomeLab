job "gluetun" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "gluetun" {
    count = 1

    network {
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
      port "sabnzbd" {
        static = 8082
        to     = 8082
      }
    }

    task "gluetun" {
      driver = "docker"

      config {
        image = "qmcgaw/gluetun:latest"
        ports = ["prowlarr", "sonarr", "radarr", "bazarr", "sabnzbd"]

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

      template {
        data        = <<-EOF
          {{ with nomadVar "nomad/jobs/vpn" }}
          VPN_SERVICE_PROVIDER=protonvpn
          VPN_TYPE=wireguard
          WIREGUARD_PRIVATE_KEY={{ .WIREGUARD_PRIVATE_KEY }}
          SERVER_COUNTRIES={{ .SERVER_COUNTRIES }}
          {{ end }}
          TZ=Europe/Copenhagen
          HTTPPROXY=off
          SHADOWSOCKS=off
          FIREWALL_INPUT_PORTS=9696,8989,7878,6767,8082
        EOF
        destination = "secrets/gluetun.env"
        env         = true
      }

      resources {
        cpu    = 200
        memory = 256
      }

      # Register with Consul - other services will discover this
      service {
        name = "gluetun"
        port = "prowlarr"

        # Store allocation info in meta for discovery
        meta {
          alloc_id = "${NOMAD_ALLOC_ID}"
        }

        tags = [
          "traefik.enable=false",
        ]

        check {
          type     = "tcp"
          interval = "30s"
          timeout  = "5s"
        }
      }
    }
  }
}
