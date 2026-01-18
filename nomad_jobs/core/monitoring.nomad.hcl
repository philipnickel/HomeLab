job "monitoring" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "default"

  group "monitoring" {
    count = 1

    restart {
      attempts = 10
      interval = "30m"
      delay    = "15s"
      mode     = "delay"
    }

    network {
      port "prometheus"    { static = 9090 }
      port "grafana"       { static = 3000 }
      port "pve_exporter"  { static = 9221 }
    }

    # Proxmox VE Exporter
    task "pve-exporter" {
      driver = "docker"

      config {
        image = "prompve/prometheus-pve-exporter:latest"
        ports = ["pve_exporter"]
      }

      template {
        data = <<-EOF
          {{ with nomadVar "nomad/jobs/monitoring" }}
          PVE_USER={{ .PVE_USER }}
          PVE_TOKEN_NAME={{ .PVE_TOKEN_NAME }}
          PVE_TOKEN_VALUE={{ .PVE_TOKEN_VALUE }}
          PVE_VERIFY_SSL=false
          {{ end }}
        EOF
        destination = "secrets/pve.env"
        env         = true
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }

    # Prometheus - metrics collection with Consul service discovery
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

            # Node Exporter - auto-discover all nodes via Consul
            - job_name: 'node-exporter'
              consul_sd_configs:
                - server: '{{ env "attr.unique.network.ip-address" }}:8500'
                  services: ['node-exporter']
              relabel_configs:
                - source_labels: ['__meta_consul_service_metadata_node']
                  target_label: 'node'
                - source_labels: ['__meta_consul_node']
                  target_label: 'instance'

            # Proxmox VE metrics
            - job_name: 'proxmox'
              static_configs:
                - targets: ['{{ env "NOMAD_ADDR_pve_exporter" }}']
              params:
                target: ['192.168.0.245']
              metrics_path: /pve
              relabel_configs:
                - source_labels: [__param_target]
                  target_label: instance

            # Nomad server metrics
            - job_name: 'nomad'
              metrics_path: /v1/metrics
              params:
                format: ['prometheus']
              scheme: http
              static_configs:
                - targets: ['192.168.0.200:4646']
                  labels:
                    node: 'nomad-server'

            # Consul metrics
            - job_name: 'consul'
              metrics_path: /v1/agent/metrics
              params:
                format: ['prometheus']
              static_configs:
                - targets: ['{{ env "attr.unique.network.ip-address" }}:8500']

            # Traefik metrics
            - job_name: 'traefik'
              metrics_path: /metrics
              static_configs:
                - targets: ['{{ env "attr.unique.network.ip-address" }}:8080']
        EOF
        destination = "local/prometheus.yml"
      }

      resources {
        cpu    = 100
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
          "local/dashboards.yml:/etc/grafana/provisioning/dashboards/dashboards.yml:ro",
          "local/dashboards:/var/lib/grafana/dashboards:ro",
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

      template {
        data = <<-EOF
          apiVersion: 1
          providers:
            - name: 'HomeLab'
              orgId: 1
              folder: 'HomeLab'
              type: file
              disableDeletion: false
              editable: true
              options:
                path: /var/lib/grafana/dashboards
        EOF
        destination = "local/dashboards.yml"
      }

      # Nomad Cluster Dashboard
      template {
        data = <<-EOF
{
  "annotations": {"list": []},
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "links": [],
  "panels": [
    {
      "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
      "id": 1,
      "options": {"colorMode": "value", "graphMode": "none", "justifyMode": "auto", "orientation": "auto", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": false}, "textMode": "auto"},
      "targets": [{"expr": "count(nomad_client_uptime)", "refId": "A"}],
      "title": "Nodes Online",
      "type": "stat"
    },
    {
      "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0},
      "id": 2,
      "options": {"colorMode": "value", "graphMode": "none", "justifyMode": "auto", "orientation": "auto", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": false}, "textMode": "auto"},
      "targets": [{"expr": "nomad_nomad_job_summary_running", "refId": "A"}],
      "title": "Running Jobs",
      "type": "stat"
    },
    {
      "gridPos": {"h": 4, "w": 6, "x": 12, "y": 0},
      "id": 3,
      "options": {"colorMode": "value", "graphMode": "none", "justifyMode": "auto", "orientation": "auto", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": false}, "textMode": "auto"},
      "targets": [{"expr": "sum(nomad_client_allocs_running)", "refId": "A"}],
      "title": "Running Allocations",
      "type": "stat"
    },
    {
      "gridPos": {"h": 4, "w": 6, "x": 18, "y": 0},
      "id": 4,
      "options": {"colorMode": "value", "graphMode": "none", "justifyMode": "auto", "orientation": "auto", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": false}, "textMode": "auto"},
      "targets": [{"expr": "sum(nomad_client_allocs_terminal{terminal_state=\"failed\"})", "refId": "A"}],
      "title": "Failed Allocations",
      "type": "stat"
    },
    {
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4},
      "id": 5,
      "options": {"legend": {"calcs": [], "displayMode": "list", "placement": "bottom"}},
      "targets": [{"expr": "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) by (node) * 100)", "legendFormat": "{{ "{{node}}" }}", "refId": "A"}],
      "title": "CPU Usage by Node",
      "type": "timeseries"
    },
    {
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4},
      "id": 6,
      "options": {"legend": {"calcs": [], "displayMode": "list", "placement": "bottom"}},
      "targets": [{"expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100", "legendFormat": "{{ "{{node}}" }}", "refId": "A"}],
      "title": "Memory Usage by Node",
      "type": "timeseries"
    },
    {
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 12},
      "id": 7,
      "options": {"legend": {"calcs": [], "displayMode": "list", "placement": "bottom"}},
      "targets": [{"expr": "rate(node_network_receive_bytes_total{device=\"eth0\"}[5m])", "legendFormat": "{{ "{{node}}" }} RX", "refId": "A"}, {"expr": "rate(node_network_transmit_bytes_total{device=\"eth0\"}[5m])", "legendFormat": "{{ "{{node}}" }} TX", "refId": "B"}],
      "title": "Network Traffic",
      "type": "timeseries"
    },
    {
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 12},
      "id": 8,
      "options": {"legend": {"calcs": [], "displayMode": "list", "placement": "bottom"}},
      "targets": [{"expr": "(1 - (node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"})) * 100", "legendFormat": "{{ "{{node}}" }} /", "refId": "A"}],
      "title": "Disk Usage",
      "type": "timeseries"
    }
  ],
  "schemaVersion": 39,
  "title": "HomeLab Cluster",
  "uid": "homelab-cluster"
}
        EOF
        destination = "local/dashboards/cluster.json"
      }

      # Proxmox VE Dashboard
      template {
        data = <<-EOF
{
  "annotations": {"list": []},
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "links": [],
  "panels": [
    {
      "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
      "id": 1,
      "options": {"colorMode": "value", "graphMode": "none", "justifyMode": "auto", "orientation": "auto", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": false}, "textMode": "auto"},
      "targets": [{"expr": "pve_up", "refId": "A"}],
      "title": "PVE Status",
      "type": "stat"
    },
    {
      "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0},
      "id": 2,
      "options": {"colorMode": "value", "graphMode": "none", "justifyMode": "auto", "orientation": "auto", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": false}, "textMode": "auto"},
      "targets": [{"expr": "count(pve_guest_info)", "refId": "A"}],
      "title": "Total VMs/CTs",
      "type": "stat"
    },
    {
      "gridPos": {"h": 4, "w": 6, "x": 12, "y": 0},
      "id": 3,
      "options": {"colorMode": "value", "graphMode": "none", "justifyMode": "auto", "orientation": "auto", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": false}, "textMode": "auto"},
      "targets": [{"expr": "sum(pve_guest_info{status=\"running\"})", "refId": "A"}],
      "title": "Running VMs",
      "type": "stat"
    },
    {
      "gridPos": {"h": 4, "w": 6, "x": 18, "y": 0},
      "id": 4,
      "options": {"colorMode": "value", "graphMode": "none", "justifyMode": "auto", "orientation": "auto", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": false}, "textMode": "auto"},
      "targets": [{"expr": "pve_node_info", "refId": "A"}],
      "title": "PVE Version",
      "type": "stat",
      "fieldConfig": {"defaults": {"mappings": []}}
    },
    {
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4},
      "id": 5,
      "options": {"legend": {"calcs": [], "displayMode": "list", "placement": "bottom"}},
      "targets": [{"expr": "pve_cpu_usage_ratio * 100", "legendFormat": "CPU %", "refId": "A"}],
      "title": "Proxmox Host CPU",
      "type": "timeseries",
      "fieldConfig": {"defaults": {"unit": "percent", "max": 100}}
    },
    {
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4},
      "id": 6,
      "options": {"legend": {"calcs": [], "displayMode": "list", "placement": "bottom"}},
      "targets": [{"expr": "pve_memory_usage_bytes / pve_memory_size_bytes * 100", "legendFormat": "Memory %", "refId": "A"}],
      "title": "Proxmox Host Memory",
      "type": "timeseries",
      "fieldConfig": {"defaults": {"unit": "percent", "max": 100}}
    },
    {
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 12},
      "id": 7,
      "options": {"legend": {"calcs": [], "displayMode": "list", "placement": "bottom"}},
      "targets": [{"expr": "pve_disk_usage_bytes", "legendFormat": "Used", "refId": "A"}, {"expr": "pve_disk_size_bytes", "legendFormat": "Total", "refId": "B"}],
      "title": "Proxmox Storage",
      "type": "timeseries",
      "fieldConfig": {"defaults": {"unit": "bytes"}}
    },
    {
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 12},
      "id": 8,
      "options": {"legend": {"calcs": [], "displayMode": "list", "placement": "bottom"}},
      "targets": [{"expr": "pve_guest_cpu_usage_ratio * 100", "legendFormat": "{{ "{{name}}" }}", "refId": "A"}],
      "title": "VM CPU Usage",
      "type": "timeseries",
      "fieldConfig": {"defaults": {"unit": "percent", "max": 100}}
    },
    {
      "gridPos": {"h": 8, "w": 24, "x": 0, "y": 20},
      "id": 9,
      "options": {"legend": {"calcs": [], "displayMode": "list", "placement": "bottom"}},
      "targets": [{"expr": "pve_guest_memory_usage_bytes / pve_guest_memory_size_bytes * 100", "legendFormat": "{{ "{{name}}" }}", "refId": "A"}],
      "title": "VM Memory Usage",
      "type": "timeseries",
      "fieldConfig": {"defaults": {"unit": "percent", "max": 100}}
    }
  ],
  "schemaVersion": 39,
  "title": "Proxmox VE",
  "uid": "proxmox-ve"
}
        EOF
        destination = "local/dashboards/proxmox.json"
      }

      env {
        GF_SECURITY_ADMIN_PASSWORD = "admin"
        GF_USERS_ALLOW_SIGN_UP     = "false"
        GF_SERVER_ROOT_URL         = "http://grafana.kni.dk"
      }

      resources {
        cpu    = 100
        memory = 256
      }
    }

    # Service registrations
    service {
      name = "pve-exporter"
      port = "pve_exporter"
      check {
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "5s"
      }
      check_restart {
        limit           = 3
        grace           = "60s"
        ignore_warnings = false
      }
    }

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
      check_restart {
        limit           = 3
        grace           = "60s"
        ignore_warnings = false
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
      check_restart {
        limit           = 3
        grace           = "60s"
        ignore_warnings = false
      }
    }
  }
}
