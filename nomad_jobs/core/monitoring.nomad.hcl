job "monitoring" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "monitoring" {
    count = 1

    network {
      port "prometheus" { static = 9090 }
      port "grafana"    { static = 3000 }
      port "node_exp"   { static = 9100 }
    }

    # Node Exporter - host metrics
    task "node-exporter" {
      driver = "docker"

      config {
        image        = "prom/node-exporter:latest"
        ports        = ["node_exp"]
        network_mode = "host"

        args = [
          "--path.rootfs=/host",
          "--web.listen-address=:9100",
        ]

        volumes = [
          "/:/host:ro,rslave",
        ]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    # Prometheus - metrics collection
    task "prometheus" {
      driver = "docker"

      config {
        image = "prom/prometheus:latest"
        ports = ["prometheus"]

        args = [
          "--config.file=/etc/prometheus/prometheus.yml",
          "--storage.tsdb.path=/prometheus",
          "--storage.tsdb.retention.time=30d",
          "--web.enable-lifecycle",
        ]

        volumes = [
          "local/prometheus.yml:/etc/prometheus/prometheus.yml:ro",
          "/opt/nomad/config-volumes/prometheus:/prometheus",
        ]
      }

      template {
        data = <<-EOF
          global:
            scrape_interval: 15s
            evaluation_interval: 15s

          scrape_configs:
            # Prometheus itself
            - job_name: 'prometheus'
              static_configs:
                - targets: ['localhost:9090']

            # Node Exporter - host metrics
            - job_name: 'node'
              static_configs:
                - targets: ['{{ env "attr.unique.network.ip-address" }}:9100']

            # Nomad metrics
            - job_name: 'nomad'
              metrics_path: /v1/metrics
              params:
                format: ['prometheus']
              static_configs:
                - targets: ['{{ env "attr.unique.network.ip-address" }}:4646']

            # Consul metrics
            - job_name: 'consul'
              metrics_path: /v1/agent/metrics
              params:
                format: ['prometheus']
              static_configs:
                - targets: ['{{ env "attr.unique.network.ip-address" }}:8500']

            # Traefik metrics
            - job_name: 'traefik'
              static_configs:
                - targets: ['{{ env "attr.unique.network.ip-address" }}:8080']
        EOF
        destination = "local/prometheus.yml"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    # Grafana - dashboards
    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:latest"
        ports = ["grafana"]

        volumes = [
          "/opt/nomad/config-volumes/grafana:/var/lib/grafana",
          "local/datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml:ro",
        ]
      }

      template {
        data = <<-EOF
          apiVersion: 1
          datasources:
            - name: Prometheus
              type: prometheus
              access: proxy
              url: http://{{ env "NOMAD_ADDR_prometheus" }}
              isDefault: true
              editable: false
        EOF
        destination = "local/datasources.yml"
      }

      env {
        GF_SECURITY_ADMIN_PASSWORD = "admin"
        GF_USERS_ALLOW_SIGN_UP     = "false"
        GF_SERVER_ROOT_URL         = "http://grafana.kni.dk"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    # Service registrations
    service {
      name = "prometheus"
      port = "prometheus"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.prometheus.rule=Host(`prometheus.kni.dk`)",
        "traefik.http.routers.prometheus.entrypoints=web",
      ]
      check {
        type     = "http"
        path     = "/-/healthy"
        interval = "30s"
        timeout  = "5s"
      }
    }

    service {
      name = "grafana"
      port = "grafana"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.grafana.rule=Host(`grafana.kni.dk`)",
        "traefik.http.routers.grafana.entrypoints=web",
      ]
      check {
        type     = "http"
        path     = "/api/health"
        interval = "30s"
        timeout  = "5s"
      }
    }

    service {
      name = "node-exporter"
      port = "node_exp"
      check {
        type     = "http"
        path     = "/metrics"
        interval = "30s"
        timeout  = "5s"
      }
    }
  }
}
