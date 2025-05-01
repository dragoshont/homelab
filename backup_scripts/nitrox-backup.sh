#!/bin/bash
set -e
DEPLOYMENT="nitrox-subnautica"
NAMESPACE="default"
BACKUP_BASE="/media/nas/games/nitrox-saves"
CONFIG_SRC="/mnt/internal_drive/games/nitrox/Nitrox_1.7.1.0"
SUBNAUTICA_SRC="/mnt/internal_drive/games/subnautica"
WORLD_FOLDER="$CONFIG_SRC/world"
CHECKSUM_FILE="/tmp/nitrox_world_checksum.md5"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DEST="$BACKUP_BASE/backup_$TIMESTAMP"

# Check for changes in the world save files
NEW_SUM=$(find "$WORLD_FOLDER" -type f -exec md5sum {} + | md5sum)

if [ -f "$CHECKSUM_FILE" ] && grep -q "$NEW_SUM" "$CHECKSUM_FILE"; then
    echo "🛑 No world changes detected — skipping backup"
    exit 0
else
    echo "$NEW_SUM" > "$CHECKSUM_FILE"
    echo "✅ World changes detected — proceeding with backup"
fi

# Suspending Flux reconciliation (if applicable)
echo ">>> [1/6] Suspending Flux reconciliation (if applicable)"
flux suspend kustomization nitrox || echo "⚠️ Flux not installed or Kustomization 'nitrox' not found. Skipping."

# Scaling down the deployment to stop the game server
echo ">>> [2/6] Scaling down deployment to stop the game server"
kubectl -n $NAMESPACE scale deployment $DEPLOYMENT --replicas=0
echo "⏳ Waiting 10s for pods to terminate..."
sleep 10

# Creating backup directory
echo ">>> [3/6] Creating backup directory: $DEST"
mkdir -p "$DEST/config" "$DEST/subnautica"

# Backing up Nitrox config volume
echo ">>> [4/6] Backing up Nitrox config volume..."
rsync -avh --delete "$CONFIG_SRC/" "$DEST/config/"

# Backing up Subnautica install/save data
echo ">>> [5/6] Backing up Subnautica install/save data..."
rsync -avh --delete "$SUBNAUTICA_SRC/" "$DEST/subnautica/"

# Scaling deployment back up
echo ">>> [6/6] Scaling deployment back up"
kubectl -n $NAMESPACE scale deployment $DEPLOYMENT --replicas=1

# Resuming Flux reconciliation (if suspended)
echo ">>> ✅ Resuming Flux reconciliation (if suspended)"
flux resume kustomization nitrox || echo "⚠️ Flux not installed or Kustomization 'nitrox' not found. Skipping."

echo "✅ Backup completed successfully to $DEST"
