job "downloaders" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "default"

  # Constrain to Proxmox node for fast local storage
  constraint {
    attribute = "${node.class}"
    value     = "proxmox"
  }

  group "downloaders" {
    count = 1

    restart {
      attempts = 10
      interval = "30m"
      delay    = "15s"
      mode     = "delay"
    }

    # Media volume via CSI (NFS from Unraid) - for moving completed downloads
    volume "media" {
      type            = "csi"
      source          = "media"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    # Local config volume (fast SSD on Proxmox)
    volume "sabnzbd-config" {
      type      = "host"
      source    = "sabnzbd-config-local"
      read_only = false
    }

    # Local downloads volume (fast SSD on Proxmox)
    volume "downloads" {
      type      = "host"
      source    = "downloads"
      read_only = false
    }

    network {
      port "sabnzbd"         { static = 8082 }
      port "gluetun_control" { static = 8001 }
    }

    # Gluetun VPN - main task that owns the network
    task "gluetun" {
      driver = "docker"

      config {
        image   = "qmcgaw/gluetun:latest"
        ports   = ["sabnzbd", "gluetun_control"]
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
          FIREWALL_INPUT_PORTS=8082,8001
          HTTP_CONTROL_SERVER_ADDRESS=:8001
          FREE_ONLY=off
          SERVER_FEATURES=p2p
          # Performance optimizations
          WIREGUARD_MTU=1420
          DOT=off
          BLOCK_MALICIOUS=off
          BLOCK_SURVEILLANCE=off
          BLOCK_ADS=off
        EOF
        destination = "secrets/gluetun.env"
        env         = true
      }

      resources {
        cpu    = 1500
        memory = 512
      }
    }

    # SABnzbd - usenet downloader
    task "sabnzbd" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      volume_mount {
        volume      = "media"
        destination = "/media"
        read_only   = false
      }

      volume_mount {
        volume      = "sabnzbd-config"
        destination = "/config"
        read_only   = false
      }

      volume_mount {
        volume      = "downloads"
        destination = "/downloads"
        read_only   = false
      }

      config {
        image        = "linuxserver/sabnzbd:latest"
        network_mode = "container:gluetun-${NOMAD_ALLOC_ID}"
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
    }

    # Traefik service registration
    service {
      name = "sabnzbd"
      port = "sabnzbd"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.sabnzbd.rule=Host(`sabnzbd.kni.dk`)",
        "traefik.http.routers.sabnzbd.entrypoints=web",
        "traefik.http.routers.sabnzbd.middlewares=sabnzbd-prefix",
        "traefik.http.middlewares.sabnzbd-prefix.addprefix.prefix=/sabnzbd",
      ]
      check {
        type     = "tcp"
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
