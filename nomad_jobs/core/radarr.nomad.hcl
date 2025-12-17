job "radarr" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "radarr" {
    count = 1

    task "radarr" {
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
          docker rm -f radarr-vpn 2>/dev/null || true

          exec docker run --rm \
            --name radarr-vpn \
            --network "container:$GLUETUN_CONTAINER" \
            -v /opt/nomad/config-volumes/radarr:/config \
            -v /opt/nomad/downloads:/downloads \
            -v /media/t7/media:/media \
            -e PUID=1000 \
            -e PGID=1000 \
            -e TZ=Europe/Copenhagen \
            -e RADARR__SERVER__PORT=7878 \
            -e RADARR__SERVER__BINDADDRESS="*" \
            -e RADARR__AUTH__METHOD=External \
            -e RADARR__AUTH__REQUIRED=DisabledForLocalAddresses \
            -e RADARR__LOG__LEVEL=info \
            linuxserver/radarr:latest
        EOF
        destination = "local/start.sh"
        perms       = "755"
      }

      config {
        command = "local/start.sh"
      }

      resources {
        cpu    = 500
        memory = 512
      }

      service {
        name = "radarr"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.radarr.rule=Host(`radarr.kni.dk`)",
          "traefik.http.routers.radarr.entrypoints=web",
          "traefik.http.services.radarr.loadbalancer.server.port=7878",
        ]
      }
    }
  }
}
