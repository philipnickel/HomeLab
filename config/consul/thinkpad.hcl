# ThinkPad Consul Server Configuration
# Copy to /etc/consul.d/consul.hcl

datacenter = "homelab"
data_dir   = "/opt/consul/data"
bind_addr  = "0.0.0.0"
advertise_addr = "{{ GetPrivateIP }}"
client_addr = "0.0.0.0"

server           = true
bootstrap_expect = 1

ui_config {
  enabled = true
}

log_level = "INFO"
