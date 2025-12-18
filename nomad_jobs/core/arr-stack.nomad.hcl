job "arr-stack" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "arr" {
    count = 1

    network {
      port "prowlarr"        { static = 9696 }
      port "sonarr"          { static = 8989 }
      port "radarr"          { static = 7878 }
      port "bazarr"          { static = 6767 }
      port "gluetun_control" { static = 8000 }
    }

    # Gluetun VPN - main task that owns the network
    task "gluetun" {
      driver = "docker"

      config {
        image   = "qmcgaw/gluetun:latest"
        ports   = ["prowlarr", "sonarr", "radarr", "bazarr", "gluetun_control"]
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
          FIREWALL_INPUT_PORTS=9696,8989,7878,6767,8000
          FIREWALL_OUTBOUND_SUBNETS=192.168.0.0/24
          HTTP_CONTROL_SERVER_ADDRESS=:8000
        EOF
        destination = "secrets/gluetun.env"
        env         = true
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    # Prowlarr - indexer manager
    task "prowlarr" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      config {
        image        = "linuxserver/prowlarr:latest"
        network_mode = "container:gluetun-${NOMAD_ALLOC_ID}"

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
    }

    # Sonarr - TV shows
    task "sonarr" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      config {
        image        = "linuxserver/sonarr:latest"
        network_mode = "container:gluetun-${NOMAD_ALLOC_ID}"

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
    }

    # Radarr - movies
    task "radarr" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      config {
        image        = "linuxserver/radarr:latest"
        network_mode = "container:gluetun-${NOMAD_ALLOC_ID}"

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
    }

    # Bazarr - subtitles
    task "bazarr" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      config {
        image        = "linuxserver/bazarr:latest"
        network_mode = "container:gluetun-${NOMAD_ALLOC_ID}"

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
    }

    # Traefik service registrations
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
  }
}
