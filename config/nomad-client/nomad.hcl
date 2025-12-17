# Nomad client config for Mac (deployment only)
datacenter = "homelab"
region     = "home"
data_dir   = "/tmp/nomad-client"

# Client mode only
client {
  enabled = true

  # Join the ThinkPad server via Tailscale
  servers = ["100.75.14.19:4647"]

  # Metadata to identify this machine
  meta {
    role = "deploy"
  }
}

# Disable server mode
server {
  enabled = false
}
