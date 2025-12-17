job "prowlarr" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  group "prowlarr" {
    count = 1

    task "prowlarr" {
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

          # Remove existing container if present
          docker rm -f prowlarr-vpn 2>/dev/null || true

          # Run prowlarr connected to gluetun's network
          exec docker run --rm \
            --name prowlarr-vpn \
            --network "container:$GLUETUN_CONTAINER" \
            -v /opt/nomad/config-volumes/prowlarr:/config \
            -e PUID=1000 \
            -e PGID=1000 \
            -e TZ=Europe/Copenhagen \
            -e PROWLARR__SERVER__PORT=9696 \
            -e PROWLARR__SERVER__BINDADDRESS="*" \
            -e PROWLARR__AUTH__METHOD=External \
            -e PROWLARR__AUTH__REQUIRED=DisabledForLocalAddresses \
            -e PROWLARR__LOG__LEVEL=info \
            linuxserver/prowlarr:latest
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
        name = "prowlarr"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.prowlarr.rule=Host(`prowlarr.kni.dk`)",
          "traefik.http.routers.prowlarr.entrypoints=web",
          "traefik.http.services.prowlarr.loadbalancer.server.port=9696",
        ]
      }
    }
  }
}
