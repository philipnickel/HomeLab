job "fileflows-node" {
  datacenters = ["homelab"]
  type        = "service"
  node_pool   = "compute"

  group "fileflows-node" {
    count = 1

    task "fileflows-node" {
      driver = "raw_exec"

      # raw_exec runs natively - direct access to host filesystem
      # Paths configured in FileFlows node config file

      config {
        command = "/bin/bash"
        args = [
          "-c",
          <<-EOF
          # Ensure FileFlows node config exists
          mkdir -p "$HOME/Library/Application Support/FileFlowsNode/Data"

          cat > "$HOME/Library/Application Support/FileFlowsNode/Data/node.config" << 'CONFIG'
          {
            "ServerUrl": "http://100.75.14.19:5000",
            "TempPath": "/tmp/fileflows-node/temp",
            "HostName": "MacBookNode-Nomad"
          }
          CONFIG

          # Run FileFlows Node with VideoToolbox support
          exec /opt/homebrew/opt/dotnet@8/bin/dotnet \
            /opt/homebrew/Cellar/fileflows-node/latest/libexec/Node/FileFlows.Node.dll \
            --no-gui \
            --base-dir "$HOME/Library/Application Support/FileFlowsNode"
          EOF
        ]
      }

      env {
        DOTNET_ROOT = "/opt/homebrew/opt/dotnet@8/libexec"
        TZ          = "Europe/Copenhagen"
        HOME        = "/Users/philipnickel"
        PATH        = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
      }

      resources {
        cpu    = 10000
        memory = 8192
      }
    }
  }
}
