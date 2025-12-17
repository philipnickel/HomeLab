#!/bin/bash
set -e

SERVER="homelab"
REMOTE_DIR="/tmp/nomad-jobs"

# Copy job files to server
echo "Copying job files..."
ssh $SERVER "mkdir -p $REMOTE_DIR"
scp -r nomad_jobs/* $SERVER:$REMOTE_DIR/

# Deploy jobs
echo "Deploying traefik..."
ssh $SERVER "nomad job run $REMOTE_DIR/core/traefik.nomad.hcl"

echo "Deploying vpn stack..."
ssh $SERVER "nomad job run $REMOTE_DIR/core/vpn.nomad.hcl"

echo "Deploying jellyfin..."
ssh $SERVER "nomad job run $REMOTE_DIR/media/jellyfin.nomad.hcl"

echo "Done! Checking status..."
ssh $SERVER "nomad job status"
