job "fileflows-node" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "compute"

  group "fileflows-node" {
    count = 1

    task "fileflows-node" {
      driver = "docker"

      config {
        image = "revenz/fileflows:latest"

        volumes = [
          "/tmp/fileflows-node/data:/app/Data",
          "/tmp/fileflows-node/logs:/app/Logs",
          "/tmp/fileflows-node/temp:/temp",
          "/tmp/homelab-media/media:/media",
        ]
      }

      env {
        TZ              = "Europe/Copenhagen"
        PUID            = "501"
        PGID            = "20"
        FFNODE          = "1"
        ServerUrl       = "http://100.75.14.19:5000"
        NodeName        = "MacBookNode"
        TempPath        = "/temp"
        NodeRunnerCount = "4"
      }

      resources {
        cpu    = 10000
        memory = 8192
      }
    }
  }
}
