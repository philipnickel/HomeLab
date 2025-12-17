job "bazarr" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "bazarr" {
    count = 1

    task "bazarr" {
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
          docker rm -f bazarr-vpn 2>/dev/null || true

          # Run bazarr connected to gluetun's network
          exec docker run --rm \
            --name bazarr-vpn \
            --network "container:$GLUETUN_CONTAINER" \
            -v /opt/nomad/config-volumes/bazarr:/config \
            -v /media/t7/media:/media \
            -e PUID=1000 \
            -e PGID=1000 \
            -e TZ=Europe/Copenhagen \
            linuxserver/bazarr:latest
        EOF
        destination = "local/start.sh"
        perms       = "755"
      }

      config {
        command = "/bin/bash"
        args    = ["local/start.sh"]
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "bazarr"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.bazarr.rule=Host(`bazarr.kni.dk`)",
          "traefik.http.routers.bazarr.entrypoints=web",
          "traefik.http.services.bazarr.loadbalancer.server.port=6767",
        ]
      }
    }
  }
}
