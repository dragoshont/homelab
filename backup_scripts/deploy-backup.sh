#!/bin/bash

# Variables
BACKUP_DIR="/media/nas/games/nitrox-saves/backup_$(date +'%Y%m%d_%H%M%S')"
WORLD_FOLDER="/mnt/internal_drive/games/nitrox/Nitrox_1.7.1.0/world"
LOG_FILE="/home/dragos/homelab/backup_scripts/backup_log.txt"

# Start the log
echo "Deployment backup started at $(date)" >> "$LOG_FILE"

# Stop the Nitrox pod
echo "Scaling down Nitrox pod..." >> "$LOG_FILE"
kubectl -n default scale deployment/nitrox-subnautica --replicas=0

# Check if the world folder has changed (by comparing the timestamp of the last modification)
if find "$WORLD_FOLDER" -type f -newermt "$(date +'%Y%m%d')"; then
    echo "Changes detected in world folder, proceeding with backup..." >> "$LOG_FILE"

    # Create the backup directory
    mkdir -p "$BACKUP_DIR"

    # Perform the backup using rsync
    rsync -avh --no-group --progress "$WORLD_FOLDER" "$BACKUP_DIR" >> "$LOG_FILE" 2>&1

    echo "Backup completed at $(date)" >> "$LOG_FILE"
else
    echo "No changes detected in the world folder, skipping backup..." >> "$LOG_FILE"
fi

# Scale the Nitrox pod back up
echo "Scaling Nitrox pod back to 1 replica..." >> "$LOG_FILE"
kubectl -n default scale deployment/nitrox-subnautica --replicas=1

# End of backup process
echo "Deployment backup finished at $(date)" >> "$LOG_FILE"
