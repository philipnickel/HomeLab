#!/bin/bash
# HomeLab Backup Script
# Run this BEFORE any major changes

set -e

BACKUP_DIR="$HOME/homelab-backup/$(date +%Y%m%d-%H%M%S)"
NOMAD_SERVER="root@192.168.0.200"
NOMAD_CLIENT="root@192.168.0.201"
PROXMOX="root@192.168.0.245"

echo "=== HomeLab Backup ==="
echo "Backing up to: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# 1. Backup service configs
echo ""
echo ">>> Backing up service configs..."
rsync -avP "$NOMAD_CLIENT:/opt/nomad/config-volumes/" "$BACKUP_DIR/configs/"

# 2. Export Nomad variables (secrets)
echo ""
echo ">>> Exporting Nomad secrets..."
ssh "$NOMAD_SERVER" "nomad var get nomad/jobs/vpn 2>/dev/null || echo '{}'" > "$BACKUP_DIR/vpn-secrets.json"
ssh "$NOMAD_SERVER" "nomad var get nomad/jobs/monitoring 2>/dev/null || echo '{}'" > "$BACKUP_DIR/monitoring-secrets.json"

# 3. Save current job definitions
echo ""
echo ">>> Saving job definitions..."
mkdir -p "$BACKUP_DIR/jobs"
for job in traefik homepage jellyfin jellyseerr arr-stack downloaders monitoring; do
  ssh "$NOMAD_SERVER" "nomad job inspect $job 2>/dev/null || echo '{}'" > "$BACKUP_DIR/jobs/$job.json"
done

# 4. Save disk layouts
echo ""
echo ">>> Saving disk layouts..."
ssh "$PROXMOX" "lsblk -f" > "$BACKUP_DIR/proxmox-disks.txt"
ssh "$NOMAD_CLIENT" "lsblk -f" > "$BACKUP_DIR/nomad-client-disks.txt"

# 5. Save current Nomad/Consul state
echo ""
echo ">>> Saving cluster state..."
ssh "$NOMAD_SERVER" "nomad status" > "$BACKUP_DIR/nomad-status.txt"
ssh "$NOMAD_SERVER" "consul catalog services" > "$BACKUP_DIR/consul-services.txt"

# 6. Create a quick restore script
cat > "$BACKUP_DIR/restore.sh" << 'RESTORE'
#!/bin/bash
# Quick restore script
BACKUP_DIR="$(dirname "$0")"
NOMAD_CLIENT="root@192.168.0.201"

echo "Restoring configs from $BACKUP_DIR..."
rsync -avP "$BACKUP_DIR/configs/" "$NOMAD_CLIENT:/opt/nomad/config-volumes/"
echo "Done! You may need to restart services."
RESTORE
chmod +x "$BACKUP_DIR/restore.sh"

echo ""
echo "=== Backup Complete ==="
echo "Location: $BACKUP_DIR"
echo ""
echo "Contents:"
ls -la "$BACKUP_DIR"
echo ""
echo "Config sizes:"
du -sh "$BACKUP_DIR/configs/"*
echo ""
echo "To restore: $BACKUP_DIR/restore.sh"
