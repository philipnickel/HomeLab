# Terraform Outputs
# Useful information after terraform apply

output "vm_info" {
  description = "VM information for reference"
  value = {
    for name, vm in proxmox_vm_qemu.vm : name => {
      vmid       = vm.vmid
      ip_address = var.vms[name].ip_address
      cores      = vm.cores
      memory_mb  = vm.memory
      disk_size  = var.vms[name].disk_size
    }
  }
}

output "ansible_inventory" {
  description = "Ansible inventory snippet"
  value       = <<-EOT

    # Add this to ansible/inventory.yml:

    all:
      children:
        nomad_servers:
          hosts:
            nomad-server:
              ansible_host: ${var.vms["nomad-server"].ip_address}
        nomad_clients:
          hosts:
            nomad-client:
              ansible_host: ${var.vms["nomad-client"].ip_address}
        nas:
          hosts:
            openmediavault:
              ansible_host: ${var.vms["openmediavault"].ip_address}
      vars:
        ansible_user: ${var.ssh_user}
        ansible_ssh_private_key_file: ~/.ssh/id_rsa
  EOT
}

output "ssh_commands" {
  description = "SSH commands for quick access"
  value       = <<-EOT

    # Quick SSH access:
    ssh ${var.ssh_user}@${var.vms["nomad-server"].ip_address}  # nomad-server
    ssh ${var.ssh_user}@${var.vms["nomad-client"].ip_address}  # nomad-client
    ssh ${var.ssh_user}@${var.vms["openmediavault"].ip_address}  # openmediavault

    # Or add to ~/.ssh/config:
    Host nomad-server
        HostName ${var.vms["nomad-server"].ip_address}
        User ${var.ssh_user}

    Host nomad-client
        HostName ${var.vms["nomad-client"].ip_address}
        User ${var.ssh_user}

    Host omv
        HostName ${var.vms["openmediavault"].ip_address}
        User ${var.ssh_user}
  EOT
}

output "next_steps" {
  description = "What to do after terraform apply"
  value       = <<-EOT

    Next Steps:
    ===========

    1. Configure disk passthrough for OMV (see storage_notes output)

    2. Update Ansible inventory:
       cd ../ansible
       cp inventory.yml.example inventory.yml
       # Edit with correct IPs (or use the ansible_inventory output above)

    3. Run Ansible to configure VMs:
       ansible-playbook site.yml

    4. Configure OpenMediaVault via web UI:
       http://${var.vms["openmediavault"].ip_address}
       - Default login: admin / openmediavault
       - Mount disks, create shares, enable NFS/SMB

    5. Deploy Nomad jobs:
       ansible-playbook site.yml --tags nomad-jobs
  EOT
}
