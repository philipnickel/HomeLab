# HomeLab Migration Plan

## Overview

Migrate from current setup (direct Docker volumes) to full Infrastructure-as-Code with:
- Terraform for VM provisioning
- Ansible for VM configuration
- OpenMediaVault for shared NAS storage
- Consul DNS for service discovery
- Host volumes for service configs (local, not NFS)

---

## DATA PROTECTION - READ FIRST

### Current Data Inventory

| Data | Location | Size | Critical? |
|------|----------|------|-----------|
| Media (Films, Shows, Photos) | `nomad-client:/media` (2TB SSD) | ~850GB | Yes - keep intact |
| Service configs | `nomad-client:/opt/nomad/config-volumes/` | ~1GB | Yes - backup first |
| Downloads (temp) | `nomad-client:/media/downloads` | Variable | No - can be lost |

### Data Protection Strategy

```
BEFORE MIGRATION:
┌─────────────────────────────────────────────────────────────────┐
│  nomad-client (192.168.0.201)                                   │
│                                                                 │
│  /opt/nomad/config-volumes/  ──────backup────►  Local machine   │
│  ├── jellyfin/                                  (rsync/tar)     │
│  ├── sonarr/                                                    │
│  ├── radarr/                                                    │
│  └── ...                                                        │
│                                                                 │
│  /media/ (2TB SSD)  ──────── DO NOT TOUCH ─────────             │
│  ├── Film/                   (passthrough to OMV)               │
│  ├── Shows/                                                     │
│  └── Photos/                                                    │
└─────────────────────────────────────────────────────────────────┘

AFTER MIGRATION:
┌─────────────────────────────────────────────────────────────────┐
│  nomad-client                     │  openmediavault             │
│                                   │                             │
│  /opt/nomad/config-volumes/       │  /srv/dev-disk-by-id.../    │
│  (same location, host volumes)    │  ├── media/     ◄── 2TB SSD │
│                                   │  ├── downloads/             │
│                                   │  └── personal/              │
└───────────────────────────────────┴─────────────────────────────┘
```

### Key Principle: 2TB SSD Stays Intact

The 2TB SSD currently mounted at `/media` on nomad-client will be:
1. **Detached** from nomad-client VM
2. **Passed through** to OpenMediaVault VM
3. **Data remains untouched** - just changing which VM can access it

No data copy needed for media!

---

## Phase 0: Backup (BEFORE ANYTHING ELSE)

### 0A: Backup Service Configs

```bash
# On your local machine
mkdir -p ~/homelab-backup/configs
rsync -avP root@192.168.0.201:/opt/nomad/config-volumes/ ~/homelab-backup/configs/

# Verify backup
ls -la ~/homelab-backup/configs/
```

### 0B: Export Nomad Variables (Secrets)

```bash
# On nomad-server
nomad var get nomad/jobs/vpn > ~/vpn-secrets.json
nomad var get nomad/jobs/monitoring > ~/monitoring-secrets.json

# Copy to local
scp root@192.168.0.200:~/*-secrets.json ~/homelab-backup/
```

### 0C: Document Current State

```bash
# Save current job definitions
ssh root@192.168.0.200 "nomad job inspect arr-stack" > ~/homelab-backup/arr-stack.json
ssh root@192.168.0.200 "nomad job inspect downloaders" > ~/homelab-backup/downloaders.json
# ... etc for all jobs

# Save disk layout
ssh root@192.168.0.245 "lsblk -f" > ~/homelab-backup/proxmox-disks.txt
ssh root@192.168.0.201 "lsblk -f" > ~/homelab-backup/nomad-client-disks.txt
```

### 0D: Verify Backups

- [ ] All config directories backed up
- [ ] Nomad secrets exported
- [ ] Current job definitions saved
- [ ] Disk layouts documented
- [ ] Backup tested (can read files)

**DO NOT PROCEED UNTIL BACKUPS ARE VERIFIED**

---

## Storage Strategy

### What Goes Where (Updated)

| Data | Location | Why |
|------|----------|-----|
| Service configs | **nomad-client local** (`/opt/nomad/config-volumes/`) | Fast, no NFS overhead, single-service access |
| Media | **OMV NFS** (`/media`) | Shared between Jellyfin + *arrs |
| Downloads | **OMV NFS** (`/downloads`) | Shared between SABnzbd + *arrs |
| Personal files | **OMV SMB** (`/personal`) | Mac access, not for Nomad |

### Download Workflow

```
SABnzbd                         Sonarr/Radarr                    Media
┌─────────────┐                ┌─────────────┐                ┌─────────────┐
│ /downloads/ │                │             │                │ /media/     │
│ ├── incomplete/ ──download──►│  Import &   │───hardlink────►│ ├── Film/   │
│ └── complete/   ◄──move──────│  Organize   │   or copy      │ └── Shows/  │
└─────────────┘                └─────────────┘                └─────────────┘
     (temp)                                                      (permanent)
```

---

## Phase 1: Foundation (Parallel Tasks)

### 1A: Terraform Setup
**Can run in parallel with 1B**

- [ ] Create `terraform/proxmox/` directory structure
- [ ] Set up Proxmox provider configuration
- [ ] Define variables (IPs, RAM, disk sizes)
- [ ] Create VM resource definitions:
  - [ ] nomad-server (1.5GB RAM, 20GB disk)
  - [ ] nomad-client (10GB RAM, 40GB disk)
  - [ ] openmediavault (2GB RAM, 10GB OS disk)
- [ ] Configure 2TB SSD passthrough to OMV
- [ ] Create cloud-init templates
- [ ] Add `.tfvars.example`
- [ ] Test with `terraform plan`

**Files to create:**
```
terraform/proxmox/
├── main.tf
├── variables.tf
├── vms.tf
├── storage.tf          # Disk passthrough config
├── cloud-init.tf
├── outputs.tf
├── terraform.tfvars.example
└── .gitignore
```

### 1B: Ansible Refactoring
**Can run in parallel with 1A**

- [ ] Restructure `ansible/` directory
- [ ] Create/update roles:
  - [ ] `common` - base packages, users, timezone
  - [ ] `docker` - Docker CE installation
  - [ ] `consul` - Consul server/agent + DNS forwarding
  - [ ] `nomad-server` - Nomad server config
  - [ ] `nomad-client` - Nomad client + host volumes + NFS client
  - [ ] `tailscale` - Tailscale installation
  - [ ] `nomad-jobs` - Deploy all Nomad jobs
- [ ] Configure Consul DNS in containers
- [ ] Create inventory template
- [ ] Create main playbook with tags
- [ ] Test with `--check` mode

**Files to create:**
```
ansible/
├── ansible.cfg
├── inventory.yml.example
├── site.yml
├── group_vars/
│   ├── all.yml
│   ├── nomad_servers.yml
│   └── nomad_clients.yml
└── roles/
    ├── common/
    ├── docker/
    ├── consul/
    ├── nomad-server/
    ├── nomad-client/
    ├── tailscale/
    └── nomad-jobs/
```

---

## Phase 2: Provision Infrastructure (Sequential)

**Depends on: Phase 1 completion + Phase 0 backups verified**

### 2A: Stop Current Services (Graceful)

```bash
# Stop jobs that use the 2TB SSD
ssh root@192.168.0.200 "nomad job stop jellyfin"
ssh root@192.168.0.200 "nomad job stop arr-stack"
ssh root@192.168.0.200 "nomad job stop downloaders"

# Verify stopped
ssh root@192.168.0.200 "nomad status"
```

### 2B: Detach 2TB SSD from nomad-client

```bash
# On nomad-client - unmount the SSD
ssh root@192.168.0.201 "umount /media"

# On Proxmox - remove disk from VM 201
ssh root@192.168.0.245 "qm set 201 --delete sata1"  # or whatever the disk ID is
```

### 2C: Prepare Proxmox Storage

```bash
# On Proxmox - shrink data pool, create NAS partition
ssh root@192.168.0.245 << 'EOF'
  # Check current state
  lvs

  # Reduce VM storage pool (careful!)
  lvreduce -L 100G pve/data

  # Create partition for NAS
  lvcreate -L 300G -n nas-data pve

  # Verify
  lvs
EOF
```

### 2D: Provision VMs with Terraform

```bash
cd terraform/proxmox
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars

terraform init
terraform plan    # Review carefully!
terraform apply
```

### 2E: Configure VMs with Ansible

```bash
cd ansible
cp inventory.yml.example inventory.yml
# Edit inventory with new VM IPs

# Configure infrastructure (not jobs yet)
ansible-playbook site.yml --tags infrastructure
```

---

## Phase 3: Storage Setup (Sequential)

**Depends on: Phase 2 completion**

### 3A: Configure OpenMediaVault

Access OMV web UI at `http://192.168.0.202`

- [ ] Set admin password
- [ ] Configure network (static IP)
- [ ] Mount 2TB SSD (should appear as /dev/sdb or similar)
- [ ] Mount 300GB NVMe partition (passed from Proxmox)
- [ ] Install mergerfs plugin
- [ ] Create mergerfs pool combining both disks
- [ ] Create shared folders:
  - [ ] `/srv/storage/media` (existing data!)
  - [ ] `/srv/storage/downloads`
  - [ ] `/srv/storage/personal`
- [ ] Configure NFS exports:
  - [ ] media: `192.168.0.0/24(rw,no_subtree_check)`
  - [ ] downloads: `192.168.0.0/24(rw,no_subtree_check)`
- [ ] Configure SMB shares:
  - [ ] personal (for Mac)
  - [ ] media (optional, for browsing)
- [ ] Install Tailscale plugin
- [ ] Verify media files are accessible!

### 3B: Verify Data Integrity

```bash
# From nomad-client, mount NFS and check
ssh root@192.168.0.201 << 'EOF'
  mkdir -p /mnt/test-media
  mount -t nfs 192.168.0.202:/srv/storage/media /mnt/test-media

  # Check files exist
  ls /mnt/test-media/Film/ | head
  ls /mnt/test-media/Shows/ | head

  # Unmount test
  umount /mnt/test-media
EOF
```

### 3C: Configure NFS Mounts on nomad-client

```bash
# Add to /etc/fstab on nomad-client
192.168.0.202:/srv/storage/media     /media      nfs  defaults,_netdev  0  0
192.168.0.202:/srv/storage/downloads /downloads  nfs  defaults,_netdev  0  0
```

---

## Phase 4: Update Nomad Jobs (Parallel where possible)

**Depends on: Phase 3 completion**

### 4A: Update Host Volumes on nomad-client

Update `/etc/nomad.d/nomad.hcl`:

```hcl
client {
  enabled = true

  # Local config volumes (per-service)
  host_volume "jellyfin-config" {
    path = "/opt/nomad/config-volumes/jellyfin"
    read_only = false
  }
  host_volume "sonarr-config" {
    path = "/opt/nomad/config-volumes/sonarr"
    read_only = false
  }
  # ... etc for each service

  # NFS-mounted shared volumes
  host_volume "media" {
    path = "/media"
    read_only = false
  }
  host_volume "downloads" {
    path = "/downloads"
    read_only = false
  }
}
```

### 4B: Update Nomad Job Files

Convert jobs to use Nomad host volumes + Consul DNS:

```hcl
# Example: jellyfin.nomad.hcl
group "jellyfin" {
  volume "config" {
    type   = "host"
    source = "jellyfin-config"
  }
  volume "media" {
    type      = "host"
    source    = "media"
    read_only = true
  }

  task "jellyfin" {
    driver = "docker"

    config {
      image = "linuxserver/jellyfin:latest"

      # Consul DNS for service discovery
      dns_servers = ["${attr.unique.network.ip-address}"]
      dns_search_domains = ["service.consul"]
    }

    volume_mount {
      volume      = "config"
      destination = "/config"
    }
    volume_mount {
      volume      = "media"
      destination = "/media"
      read_only   = true
    }
  }
}
```

### 4C: Update arr-stack

- [ ] Add Bazarr back
- [ ] Update all services to use host volumes
- [ ] Configure Consul DNS for inter-service communication
- [ ] Update download paths

### 4D: Update downloaders

- [ ] Remove qBittorrent
- [ ] Update SABnzbd to use host volumes
- [ ] Configure download paths:
  - Incomplete: `/downloads/incomplete`
  - Complete: `/downloads/complete`

### 4E: Restore Service Configs (if needed)

If configs were lost or need restoration:

```bash
# From local backup
rsync -avP ~/homelab-backup/configs/ root@192.168.0.201:/opt/nomad/config-volumes/
```

---

## Phase 5: Deploy & Verify (Sequential)

### 5A: Deploy Jobs via Ansible

```bash
cd ansible
ansible-playbook site.yml --tags nomad-jobs
```

### 5B: Verify All Services

- [ ] Traefik dashboard accessible
- [ ] Homepage loads
- [ ] Jellyfin sees media library
- [ ] Jellyseerr connects to Jellyfin (via Consul DNS)
- [ ] Sonarr/Radarr can see media + downloads
- [ ] Prowlarr connects to Sonarr/Radarr (via Consul DNS)
- [ ] SABnzbd accessible, downloads to correct path
- [ ] Bazarr connects to Sonarr/Radarr
- [ ] Grafana/Prometheus working

### 5C: Test Download Workflow

1. Request something via Jellyseerr
2. Verify Sonarr/Radarr picks it up
3. Verify SABnzbd downloads
4. Verify import to media folder
5. Verify appears in Jellyfin

### 5D: Test Remote Access

- [ ] Mount SMB share on Mac via Tailscale
- [ ] Access Jellyfin remotely
- [ ] Verify all services via Tailscale

---

## Phase 6: Cleanup

### 6A: Remove Old Resources

```bash
# Remove old nomad-client VM if recreated
# (only after verifying new setup works!)
```

### 6B: Update Documentation

- [ ] Update README if needed
- [ ] Create docs/setup-guide.md
- [ ] Create docs/disaster-recovery.md

### 6C: Commit Everything

```bash
git add -A
git commit -m "Migrate to IaC with Terraform/Ansible, add OMV NAS, Consul DNS"
git tag v2.0.0
git push origin main --tags
```

---

## Rollback Plan

### If Migration Fails

1. **VMs still exist**: Old configs in `/opt/nomad/config-volumes/` on original nomad-client
2. **2TB SSD**: Reattach to nomad-client VM, mount at `/media`
3. **Restore from backup**: `rsync ~/homelab-backup/configs/ root@192.168.0.201:/opt/nomad/config-volumes/`
4. **Restore secrets**: Import Nomad variables from JSON backups
5. **Git revert**: `git checkout <previous-commit>` and redeploy old jobs

### Point of No Return

The only destructive action is **resizing the Proxmox LVM**. Before that:
- All changes are reversible
- VMs can be deleted and recreated
- 2TB SSD data is untouched

---

## Quick Reference

```bash
# Backup configs
rsync -avP root@192.168.0.201:/opt/nomad/config-volumes/ ~/homelab-backup/configs/

# Terraform
cd terraform/proxmox && terraform init && terraform apply

# Ansible - full deploy
cd ansible && ansible-playbook site.yml

# Ansible - just infrastructure
ansible-playbook site.yml --tags infrastructure

# Ansible - just jobs
ansible-playbook site.yml --tags nomad-jobs

# Check services
ssh root@192.168.0.200 "nomad status"
ssh root@192.168.0.200 "consul catalog services"

# Test Consul DNS
ssh root@192.168.0.201 "dig @127.0.0.1 -p 8600 sonarr.service.consul"
```

---

## Estimated Timeline

| Phase | Time | Parallelizable |
|-------|------|----------------|
| Phase 0: Backup | 30 min | No |
| Phase 1A: Terraform | 2-3 hrs | Yes |
| Phase 1B: Ansible | 2-3 hrs | Yes |
| Phase 2: Provision | 1-2 hrs | No |
| Phase 3: Storage | 1-2 hrs | No |
| Phase 4: Jobs | 2-3 hrs | Partially |
| Phase 5: Verify | 1 hr | No |
| Phase 6: Cleanup | 30 min | No |

**Total: ~10-14 hours** (less with parallelization)
