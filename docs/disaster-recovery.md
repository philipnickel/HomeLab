# Disaster Recovery Guide

How to recover from various failure scenarios.

## Failure Scenarios

### 1. Single Container Crash

**Automatic Recovery**: Nomad handles this automatically via `restart` stanzas.

**Manual Recovery**:
```bash
ssh root@192.168.0.200 "nomad job restart <job-name>"
```

### 2. VM Crash / Unresponsive

**Recovery**:
```bash
# From Proxmox
ssh root@192.168.0.245 "qm reset <vmid>"

# Or via web UI
# https://192.168.0.245:8006 → VM → Reset
```

VMs auto-start on boot (`onboot: 1`).

### 3. Proxmox Host Crash

**Recovery**:
1. Power cycle the ACEMAGIC mini PC
2. Wait for Proxmox to boot
3. VMs should start automatically
4. Services should recover via Nomad

**If VMs don't start**:
```bash
ssh root@192.168.0.245
qm start 200  # nomad-server
qm start 201  # nomad-client
qm start 202  # openmediavault
```

### 4. Data Corruption

**Service Configs**:
```bash
# Restore from backup
rsync -avP ~/homelab-backup/latest/configs/ root@192.168.0.201:/opt/nomad/config-volumes/
```

**Media**:
Media is stored on the 2TB SSD. If corrupted, re-download is the only option (no backup by design).

### 5. Complete Hardware Failure

**Recovery Steps**:

1. **Get new hardware** (or repair existing)

2. **Install Proxmox VE**

3. **Restore from Git**:
   ```bash
   git clone https://github.com/yourusername/HomeLab.git
   cd HomeLab
   ```

4. **Configure and Deploy**:
   ```bash
   # Configure Terraform
   cp terraform/proxmox/terraform.tfvars.example terraform/proxmox/terraform.tfvars
   # Edit with new Proxmox credentials

   # Configure Ansible
   cp ansible/inventory.yml.example ansible/inventory.yml

   # Deploy
   make deploy
   ```

5. **Restore Configs** (from backup):
   ```bash
   rsync -avP ~/homelab-backup/latest/configs/ root@192.168.0.201:/opt/nomad/config-volumes/
   ```

6. **Restore Secrets**:
   ```bash
   # VPN secrets
   cat ~/homelab-backup/latest/vpn-secrets.json | jq -r 'to_entries | map("\(.key)=\(.value)") | .[]' | \
     xargs ssh root@192.168.0.200 nomad var put nomad/jobs/vpn

   # Monitoring secrets
   cat ~/homelab-backup/latest/monitoring-secrets.json | jq -r 'to_entries | map("\(.key)=\(.value)") | .[]' | \
     xargs ssh root@192.168.0.200 nomad var put nomad/jobs/monitoring
   ```

7. **Configure OpenMediaVault** (manual via web UI)

8. **Verify**:
   ```bash
   make status
   ```

## What's NOT Recoverable

| Data | Location | Recovery |
|------|----------|----------|
| Media | 2TB SSD | Re-download |
| Downloads in progress | /downloads | Re-start |
| Grafana dashboards | Built into job | Automatic |

## What IS Recoverable

| Data | Location | Backup |
|------|----------|--------|
| Service configs | nomad-client | `~/homelab-backup/configs/` |
| Nomad secrets | Nomad server | `~/homelab-backup/*-secrets.json` |
| Job definitions | Git repo | `nomad_jobs/` |
| Infrastructure | Git repo | `terraform/` + `ansible/` |

## Recovery Time Estimates

| Scenario | RTO |
|----------|-----|
| Container crash | < 1 min (automatic) |
| VM crash | 2-5 min |
| Proxmox reboot | 5-10 min |
| Complete rebuild | 2-4 hours |

## Backup Schedule

Run backups before any major changes:

```bash
make backup
```

Recommended schedule:
- **Weekly**: Full backup via `make backup`
- **Before changes**: Always backup first
- **Git commits**: Commit IaC changes regularly

## Testing Recovery

Periodically test your recovery process:

```bash
# 1. Backup
make backup

# 2. Stop a service
ssh root@192.168.0.200 "nomad job stop jellyfin"

# 3. Verify it's down
curl -s http://stream.kni.dk  # Should fail

# 4. Restore
ssh root@192.168.0.200 "nomad job run /path/to/jellyfin.nomad.hcl"

# 5. Verify recovery
curl -s http://stream.kni.dk  # Should work
```

## Emergency Contacts

Keep these handy:
- Proxmox IP: 192.168.0.245
- Router IP: 192.168.0.1
- Backup location: `~/homelab-backup/`
- Git repo: https://github.com/yourusername/HomeLab
