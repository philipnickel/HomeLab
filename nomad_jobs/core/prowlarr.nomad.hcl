job "prowlarr" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "services"

  # Ensure prowlarr runs on same node as gluetun
  constraint {
    attribute = "${node.unique.id}"
    operator  = "set_contains_any"
    value     = "${attr.unique.hostname}"
  }

  group "prowlarr" {
    count = 1

    # Discover gluetun container and start prowlarr connected to it
    task "prowlarr" {
      driver = "raw_exec"

      # First, discover the gluetun container name
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

          # Check if our container already exists and remove it
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
        command = "/bin/bash"
        args    = ["local/start.sh"]
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
