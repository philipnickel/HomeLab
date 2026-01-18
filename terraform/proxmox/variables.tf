# Proxmox Connection
variable "proxmox_api_url" {
  description = "Proxmox API URL (e.g., https://192.168.0.245:8006/api2/json)"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID (e.g., root@pam!terraform)"
  type        = string
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification for self-signed certs"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

# Network Configuration
variable "gateway" {
  description = "Network gateway IP"
  type        = string
  default     = "192.168.0.1"
}

variable "nameserver" {
  description = "DNS nameserver"
  type        = string
  default     = "192.168.0.1"
}

variable "network_bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

# Cloud-init template
variable "cloudinit_template" {
  description = "Name of the cloud-init template to clone"
  type        = string
  default     = "debian-12-cloudinit"
}

variable "cloudinit_storage" {
  description = "Storage for cloud-init drives"
  type        = string
  default     = "local-lvm"
}

# SSH Configuration
variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "ssh_user" {
  description = "Default SSH user"
  type        = string
  default     = "debian"
}

# VM Definitions
variable "vms" {
  description = "Map of VMs to create"
  type = map(object({
    vmid        = number
    cores       = number
    memory      = number
    disk_size   = string
    ip_address  = string
    description = string
    onboot      = bool
    tags        = list(string)
  }))
  default = {
    nomad-server = {
      vmid        = 200
      cores       = 2
      memory      = 1536  # 1.5GB
      disk_size   = "20G"
      ip_address  = "192.168.0.200"
      description = "Nomad Server + Consul + Traefik"
      onboot      = true
      tags        = ["nomad", "consul", "traefik"]
    }
    nomad-client = {
      vmid        = 201
      cores       = 4
      memory      = 10240  # 10GB
      disk_size   = "40G"
      ip_address  = "192.168.0.201"
      description = "Nomad Client - Container Workloads"
      onboot      = true
      tags        = ["nomad", "docker"]
    }
    openmediavault = {
      vmid        = 202
      cores       = 2
      memory      = 2048  # 2GB
      disk_size   = "10G"
      ip_address  = "192.168.0.202"
      description = "OpenMediaVault NAS"
      onboot      = true
      tags        = ["nas", "storage"]
    }
  }
}

# Storage passthrough for OMV
variable "omv_passthrough_disk" {
  description = "Disk to passthrough to OMV (e.g., /dev/disk/by-id/...)"
  type        = string
  default     = ""
}
