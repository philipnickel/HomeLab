# Storage Configuration
# Handles disk passthrough for OpenMediaVault

# Note: Proxmox disk passthrough requires the disk to be identified by its
# /dev/disk/by-id/ path for stability across reboots.
#
# To find your disk ID:
#   ls -la /dev/disk/by-id/ | grep -v "part"
#
# Example: /dev/disk/by-id/ata-Samsung_SSD_870_EVO_2TB_XXXXXXXXXXXX

# The 2TB SSD passthrough is configured via Proxmox CLI after VM creation
# because the Terraform provider has limited support for raw disk passthrough.
#
# Run this after terraform apply:
#   ssh root@proxmox "qm set 202 -scsi1 /dev/disk/by-id/YOUR_DISK_ID"

# For the NVMe partition passthrough (from Proxmox storage pool):
# This requires creating an LVM logical volume first:
#   ssh root@proxmox "lvcreate -L 300G -n nas-data pve"
#   ssh root@proxmox "qm set 202 -scsi2 /dev/pve/nas-data"

resource "null_resource" "omv_disk_passthrough" {
  count = var.omv_passthrough_disk != "" ? 1 : 0

  depends_on = [proxmox_vm_qemu.vm]

  # This is a placeholder - actual passthrough requires SSH to Proxmox
  # See docs/setup-guide.md for manual steps

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Manual Step Required ==="
      echo "Run the following on Proxmox to passthrough the 2TB SSD:"
      echo "  qm set 202 -scsi1 ${var.omv_passthrough_disk}"
      echo ""
      echo "To passthrough NVMe partition:"
      echo "  lvcreate -L 300G -n nas-data pve  # if not already created"
      echo "  qm set 202 -scsi2 /dev/pve/nas-data"
    EOT
  }
}

# Storage notes for reference
locals {
  storage_layout = {
    proxmox_nvme = {
      device      = "/dev/nvme0n1"
      total_size  = "500GB"
      allocations = {
        proxmox_os   = "30GB"
        nomad_server = "20GB"
        nomad_client = "40GB"
        omv_os       = "10GB"
        nas_pool     = "~300GB"
        buffer       = "~100GB"
      }
    }
    ssd_2tb = {
      device      = "Passthrough to OMV"
      total_size  = "2TB"
      allocations = {
        media     = "~1.5TB"
        downloads = "~300GB"
        personal  = "~200GB"
      }
    }
  }
}

output "storage_notes" {
  description = "Storage layout reference"
  value       = <<-EOT

    Storage Layout:
    ===============

    NVMe 500GB (Proxmox managed):
    - Proxmox OS: 30GB
    - nomad-server disk: 20GB
    - nomad-client disk: 40GB
    - OMV OS disk: 10GB
    - NAS pool (passthrough to OMV): ~300GB

    SSD 2TB (Passthrough to OMV):
    - /media: Movies, TV, Photos
    - /downloads: Temporary download location
    - /personal: Documents, courses, notes

    After terraform apply, configure disk passthrough manually.
    See docs/setup-guide.md for instructions.
  EOT
}
