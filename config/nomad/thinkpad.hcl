# ThinkPad Server Configuration
# Copy to /etc/nomad.d/nomad.hcl

datacenter = "homelab"
data_dir   = "/opt/nomad/data"
bind_addr  = "0.0.0.0"
region     = "home"

advertise {
  http = "{{ GetPrivateIP }}"
  rpc  = "{{ GetPrivateIP }}"
  serf = "{{ GetPrivateIP }}"
}

# Server configuration (single node)
server {
  enabled          = true
  bootstrap_expect = 1
}

# Client configuration
client {
  enabled = true

  # Docker driver options
  options = {
    "docker.privileged.enabled" = "true"
    "driver.raw_exec.enable"    = "1"
    "docker.volumes.enabled"    = "true"
  }

  # Host Volumes - abstract storage locations
  # Jobs reference these by name, paths defined here only
  host_volume "config" {
    path      = "/opt/nomad/config-volumes"
    read_only = false
  }

  host_volume "downloads" {
    path      = "/opt/nomad/downloads"
    read_only = false
  }

  host_volume "media" {
    path      = "/media/t7/media"
    read_only = false
  }

  # Node metadata for job constraints
  meta {
    node         = "thinkpad"
    shared_mount = "true"
  }

  # Host Networks - for binding services to specific interfaces
  host_network "tailscale" {
    cidr = "100.0.0.0/8"
  }

  host_network "lan" {
    cidr = "192.168.0.0/16"
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

# Consul integration
consul {
  address = "127.0.0.1:8500"
}

# Telemetry for monitoring (enable later with Prometheus)
# telemetry {
#   publish_allocation_metrics = true
#   publish_node_metrics       = true
#   prometheus_metrics         = true
# }
