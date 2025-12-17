job "sonarr" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "sonarr" {
    count = 1

    task "sonarr" {
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
          docker rm -f sonarr-vpn 2>/dev/null || true

          exec docker run --rm \
            --name sonarr-vpn \
            --network "container:$GLUETUN_CONTAINER" \
            -v /opt/nomad/config-volumes/sonarr:/config \
            -v /opt/nomad/downloads:/downloads \
            -v /media/t7/media:/media \
            -e PUID=1000 \
            -e PGID=1000 \
            -e TZ=Europe/Copenhagen \
            -e SONARR__SERVER__PORT=8989 \
            -e SONARR__SERVER__BINDADDRESS="*" \
            -e SONARR__AUTH__METHOD=External \
            -e SONARR__AUTH__REQUIRED=DisabledForLocalAddresses \
            -e SONARR__LOG__LEVEL=info \
            linuxserver/sonarr:latest
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
        name = "sonarr"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.sonarr.rule=Host(`sonarr.kni.dk`)",
          "traefik.http.routers.sonarr.entrypoints=web",
          "traefik.http.services.sonarr.loadbalancer.server.port=8989",
        ]
      }
    }
  }
}
