job "bazarr" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "bazarr" {
    count = 1

    task "bazarr" {
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
          docker rm -f bazarr-vpn 2>/dev/null || true

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
        command = "local/start.sh"
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
