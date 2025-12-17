# MacBook Client Configuration
# Run with: sudo nomad agent -config=config/nomad/macbook.hcl

datacenter = "homelab"
region     = "home"
data_dir   = "/tmp/nomad-client"

# Client only (no server)
server {
  enabled = false
}

client {
  enabled = true

  # Join ThinkPad server via Tailscale
  servers = ["100.75.14.19:4647"]

  # Metadata to identify this machine
  meta {
    role = "deploy"
  }
}
