# VM Resources
# Creates VMs from the vms variable map

resource "proxmox_vm_qemu" "vm" {
  for_each = var.vms

  name        = each.key
  target_node = var.proxmox_node
  vmid        = each.value.vmid
  desc        = each.value.description
  tags        = join(",", each.value.tags)

  # Clone from cloud-init template
  clone      = var.cloudinit_template
  full_clone = true

  # VM Resources
  cores   = each.value.cores
  sockets = 1
  memory  = each.value.memory
  cpu     = "host"

  # Boot configuration
  onboot   = each.value.onboot
  boot     = "order=scsi0"
  bootdisk = "scsi0"

  # SCSI controller for better performance
  scsihw = "virtio-scsi-pci"

  # OS disk
  disks {
    scsi {
      scsi0 {
        disk {
          size    = each.value.disk_size
          storage = var.cloudinit_storage
          format  = "raw"
        }
      }
    }
    ide {
      ide2 {
        cloudinit {
          storage = var.cloudinit_storage
        }
      }
    }
  }

  # Network
  network {
    model  = "virtio"
    bridge = var.network_bridge
  }

  # Cloud-init configuration
  os_type    = "cloud-init"
  ciuser     = var.ssh_user
  sshkeys    = var.ssh_public_key
  ipconfig0  = "ip=${each.value.ip_address}/24,gw=${var.gateway}"
  nameserver = var.nameserver

  # Agent
  agent = 1

  lifecycle {
    ignore_changes = [
      network,
      desc,
    ]
  }
}

# Output the VM IPs for Ansible inventory
output "vm_ips" {
  description = "Map of VM names to their IP addresses"
  value = {
    for name, vm in proxmox_vm_qemu.vm : name => var.vms[name].ip_address
  }
}
