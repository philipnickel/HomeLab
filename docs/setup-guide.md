# HomeLab Setup Guide

Complete guide to deploying the HomeLab from scratch.

## Prerequisites

### Local Machine

Install these tools on your Mac/Linux workstation:

```bash
# macOS
brew install terraform ansible

# Linux (Debian/Ubuntu)
sudo apt install terraform ansible
```

### Proxmox

1. Proxmox VE installed on your hardware
2. API token created for Terraform:
   - Go to Datacenter → Permissions → API Tokens
   - Add: User=root@pam, Token ID=terraform
   - Copy the token secret (shown only once!)

3. Cloud-init template prepared:
   ```bash
   # On Proxmox
   wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2
   qm create 9000 --name debian-12-cloudinit --memory 2048 --net0 virtio,bridge=vmbr0
   qm importdisk 9000 debian-12-generic-amd64.qcow2 local-lvm
   qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
   qm set 9000 --ide2 local-lvm:cloudinit
   qm set 9000 --boot c --bootdisk scsi0
   qm set 9000 --serial0 socket --vga serial0
   qm template 9000
   ```

## Step 1: Clone Repository

```bash
git clone https://github.com/yourusername/HomeLab.git
cd HomeLab
```

## Step 2: Configure Terraform

```bash
cd terraform/proxmox
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
proxmox_api_url          = "https://192.168.0.245:8006/api2/json"
proxmox_api_token_id     = "root@pam!terraform"
proxmox_api_token_secret = "your-secret-here"
ssh_public_key           = "ssh-rsa AAAA... your-key"
```

## Step 3: Configure Ansible

```bash
cd ../../ansible
cp inventory.yml.example inventory.yml
```

The default inventory should work if you keep the default IPs.

## Step 4: Deploy Infrastructure

### Option A: Full Deployment (Recommended)

```bash
# From repository root
make deploy
```

### Option B: Step by Step

```bash
# 1. Provision VMs
make terraform-apply

# 2. Configure infrastructure
make ansible-infra

# 3. Deploy jobs
make ansible-jobs
```

## Step 5: Configure OpenMediaVault

After Ansible runs, access OMV at `http://192.168.0.202`:

1. **Login**: admin / openmediavault (change immediately!)

2. **Mount Disks**:
   - Storage → Disks (should see 2TB SSD and NVMe partition)
   - Storage → File Systems → Create (ext4 on each disk)
   - Mount both

3. **Install mergerfs** (optional but recommended):
   - System → Plugins → openmediavault-mergerfs
   - Storage → mergerfs → Create pool

4. **Create Shared Folders**:
   - Storage → Shared Folders:
     - `media` → /srv/storage/media
     - `downloads` → /srv/storage/downloads
     - `personal` → /srv/storage/personal

5. **Enable NFS**:
   - Services → NFS → Settings → Enable
   - Shares → Add:
     - media: `192.168.0.0/24` (rw, no_subtree_check)
     - downloads: `192.168.0.0/24` (rw, no_subtree_check)

6. **Enable SMB** (for Mac access):
   - Services → SMB → Settings → Enable
   - Shares → Add:
     - personal: Guest=no, Public=no

7. **Configure Tailscale**:
   - Should already be installed by Ansible
   - SSH in: `ssh debian@192.168.0.202`
   - Run: `sudo tailscale up`

## Step 6: Configure Disk Passthrough

If the 2TB SSD wasn't passed through by Terraform:

```bash
# SSH to Proxmox
ssh root@192.168.0.245

# Find your disk
ls -la /dev/disk/by-id/ | grep -v part

# Passthrough to OMV (VM 202)
qm set 202 -scsi1 /dev/disk/by-id/ata-YOUR_DISK_ID
```

## Step 7: Verify Deployment

```bash
# Check status
make status

# Or manually
ssh root@192.168.0.200 "nomad status"
ssh root@192.168.0.200 "consul catalog services"
```

## Step 8: Access Services

| Service | URL |
|---------|-----|
| Homepage | http://home.kni.dk |
| Jellyfin | http://stream.kni.dk |
| Nomad | http://nomad.kni.dk |
| Consul | http://consul.kni.dk |
| Grafana | http://grafana.kni.dk |

## Troubleshooting

### VMs won't start
```bash
# Check Proxmox logs
ssh root@192.168.0.245 "journalctl -u pve* -f"
```

### Consul DNS not working
```bash
# Test DNS resolution
ssh root@192.168.0.201 "dig @127.0.0.1 -p 8600 sonarr.service.consul"
```

### NFS mounts failing
```bash
# Check NFS exports on OMV
ssh debian@192.168.0.202 "showmount -e localhost"

# Test mount from client
ssh root@192.168.0.201 "mount -t nfs 192.168.0.202:/srv/storage/media /mnt/test"
```

### Jobs not starting
```bash
# Check job status
ssh root@192.168.0.200 "nomad job status arr-stack"

# View allocation logs
ssh root@192.168.0.200 "nomad alloc logs <alloc-id>"
```

## Backup & Recovery

### Create Backup
```bash
make backup
# or
./scripts/backup.sh
```

### Restore from Backup
```bash
# Restore configs
rsync -avP ~/homelab-backup/YYYYMMDD-HHMMSS/configs/ root@192.168.0.201:/opt/nomad/config-volumes/

# Restore Nomad secrets
cat ~/homelab-backup/YYYYMMDD-HHMMSS/vpn-secrets.json | ssh root@192.168.0.200 "nomad var put nomad/jobs/vpn -"
```

## Quick Reference

```bash
# Full deployment
make deploy

# Just infrastructure
make deploy-infra

# Just jobs
make deploy-jobs

# Backup
make backup

# Status
make status
```
