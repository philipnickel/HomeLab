job "radarr" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "radarr" {
    count = 1

    task "radarr" {
      driver = "raw_exec"

      template {
        data = <<-EOF
          #!/bin/bash
          set -e

          # Find gluetun container
          GLUETUN_CONTAINER=$(docker ps --filter "name=gluetun-" --format "{{.Names}}" | head -1)

          if [ -z "$GLUETUN_CONTAINER" ]; then
            echo "ERROR: Gluetun container not found!"
            exit 1
          fi

          echo "Connecting to gluetun container: $GLUETUN_CONTAINER"

          # Remove existing container if present
          docker rm -f radarr-vpn 2>/dev/null || true

          # Run radarr connected to gluetun's network
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
        command = "/bin/bash"
        args    = ["local/start.sh"]
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
