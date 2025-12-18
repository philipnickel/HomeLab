job "traefik" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "traefik" {
    count = 1

    network {
      port "http" {
        static = 80
      }
      port "https" {
        static = 443
      }
      port "dashboard" {
        static = 8080
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

          [ping]
            entryPoint = "traefik"

          [providers]
            [providers.consulCatalog]
              prefix = "traefik"
              exposedByDefault = false
              [providers.consulCatalog.endpoint]
                address = "127.0.0.1:8500"
                scheme = "http"
            [providers.file]
              filename = "/local/dynamic.toml"

          [metrics]
            [metrics.prometheus]
              entryPoint = "traefik"
              addEntryPointsLabels = true
              addServicesLabels = true
              addRoutersLabels = true

          [log]
            level = "INFO"

          [accessLog]
        EOF
        destination = "local/traefik.toml"
      }

      template {
        data = <<-EOF
          # Static routes for infrastructure services
          [http.routers]
            [http.routers.nomad]
              rule = "Host(`nomad.kni.dk`)"
              service = "nomad"
              entryPoints = ["web"]
            [http.routers.consul]
              rule = "Host(`consul.kni.dk`)"
              service = "consul"
              entryPoints = ["web"]

          [http.services]
            [http.services.nomad.loadBalancer]
              [[http.services.nomad.loadBalancer.servers]]
                url = "http://127.0.0.1:4646"
            [http.services.consul.loadBalancer]
              [[http.services.consul.loadBalancer.servers]]
                url = "http://127.0.0.1:8500"
        EOF
        destination = "local/dynamic.toml"
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
