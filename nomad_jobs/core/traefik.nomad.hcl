job "traefik" {
  datacenters = ["homelab"]
  type        = "service"

  group "traefik" {
    count = 1

    network {
      port "http" {
        static       = 80
        host_network = "lan"
      }
      port "https" {
        static       = 443
        host_network = "lan"
      }
      port "dashboard" {
        static       = 8080
        host_network = "lan"
      }
    }

    volume "config" {
      type      = "host"
      source    = "config"
      read_only = false
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v3.2"
        network_mode = "host"
        ports        = ["http", "https", "dashboard"]

        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml:ro",
        ]
      }

      volume_mount {
        volume      = "config"
        destination = "/config"
        read_only   = false
      }

      template {
        data = <<-EOF
          [entryPoints]
            [entryPoints.web]
              address = ":80"
            [entryPoints.websecure]
              address = ":443"
            [entryPoints.traefik]
              address = ":8080"

          [api]
            dashboard = true
            insecure = true

          [providers]
            [providers.consulCatalog]
              prefix = "traefik"
              exposedByDefault = false
              [providers.consulCatalog.endpoint]
                address = "127.0.0.1:8500"
                scheme = "http"

          [log]
            level = "INFO"

          [accessLog]
        EOF
        destination = "local/traefik.toml"
      }

      service {
        name = "traefik"
        port = "dashboard"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.traefik.rule=Host(`traefik.kni.dk`)",
          "traefik.http.routers.traefik.entrypoints=web",
          "traefik.http.routers.traefik.service=api@internal",
        ]

        check {
          type     = "http"
          path     = "/ping"
          port     = "dashboard"
          interval = "10s"
          timeout  = "2s"
        }
      }

      resources {
        cpu    = 200
        memory = 128
      }
    }
  }
}
