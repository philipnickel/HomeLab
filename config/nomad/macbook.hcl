# MacBook Client Configuration
# Run with: sudo nomad agent -config=config/nomad/macbook.hcl

datacenter = "homelab"
region     = "home"
data_dir   = "/opt/nomad/data"

# Client only (no server)
server {
  enabled = false
}

client {
  enabled = true

  # Join ThinkPad server via Tailscale
  servers = ["100.75.14.19:4647"]

  # Docker driver options
  options = {
    "docker.privileged.enabled" = "true"
    "driver.raw_exec.enable"    = "1"
    "docker.volumes.enabled"    = "true"
  }

  # Node metadata for job constraints
  meta {
    node = "macbook"
  }
}

# Docker plugin configuration
plugin "docker" {
  config {
    allow_caps = [
      "CHOWN", "DAC_OVERRIDE", "FSETID", "FOWNER", "MKNOD",
      "NET_RAW", "SETGID", "SETUID", "SETFCAP", "SETPCAP",
      "NET_BIND_SERVICE", "SYS_CHROOT", "KILL", "AUDIT_WRITE",
      "NET_ADMIN"
    ]
    allow_privileged = true
    volumes {
      enabled = true
    }
  }
}
