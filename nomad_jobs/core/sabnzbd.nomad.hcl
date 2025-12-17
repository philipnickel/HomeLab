job "sabnzbd" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "sabnzbd" {
    count = 1

    task "sabnzbd" {
      driver = "raw_exec"

      # Use Consul template to discover gluetun container name
      template {
        data = <<-EOF
          {{- range service "gluetun" }}
          GLUETUN_CONTAINER={{ .ServiceMeta.container_name }}
          {{- end }}
        EOF
        destination = "local/gluetun.env"
        env         = true
      }

      template {
        data = <<-EOF
          #!/bin/bash
          set -e

          if [ -z "$GLUETUN_CONTAINER" ]; then
            echo "ERROR: GLUETUN_CONTAINER not set - gluetun service not found in Consul"
            exit 1
          fi

          echo "Connecting to gluetun container: $GLUETUN_CONTAINER"
          docker rm -f sabnzbd-vpn 2>/dev/null || true

          exec docker run --rm \
            --name sabnzbd-vpn \
            --network "container:$GLUETUN_CONTAINER" \
            -v /opt/nomad/config-volumes/sabnzbd:/config \
            -v /opt/nomad/downloads:/downloads \
            -v /media/t7/media:/media \
            -e PUID=1000 \
            -e PGID=1000 \
            -e TZ=Europe/Copenhagen \
            linuxserver/sabnzbd:latest
        EOF
        destination = "local/start.sh"
        perms       = "755"
      }

      config {
        command = "local/start.sh"
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      service {
        name = "sabnzbd"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.sabnzbd.rule=Host(`sabnzbd.kni.dk`)",
          "traefik.http.routers.sabnzbd.entrypoints=web",
          "traefik.http.services.sabnzbd.loadbalancer.server.port=8082",
        ]
      }
    }
  }
}
