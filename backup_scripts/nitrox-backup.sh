#!/bin/bash

# Variables
BACKUP_DIR="/media/nas/games/nitrox-saves/backup_$(date +'%Y%m%d_%H%M%S')"
WORLD_FOLDER="/mnt/internal_drive/games/nitrox/Nitrox_1.7.1.0/world"
LOG_FILE="/home/dragos/homelab/backup_scripts/backup_log.txt"

# Create the backup directory
mkdir -p "$BACKUP_DIR"

# Start the log
echo "Backup started at $(date)" >> "$LOG_FILE"

# Stop the Nitrox pod
echo "Stopping Nitrox pod..." >> "$LOG_FILE"
kubectl -n default scale deployment/nitrox-subnautica --replicas=0

# Check if the world folder has changed (by comparing the timestamp of the last modification)
if find "$WORLD_FOLDER" -type f -newermt "$(date +'%Y%m%d')"; then
    echo "Changes detected in world folder, proceeding with backup..." >> "$LOG_FILE"

    # Perform the backup
    rsync -avh --no-group --progress "$WORLD_FOLDER" "$BACKUP_DIR" >> "$LOG_FILE" 2>&1

    echo "Backup completed at $(date)" >> "$LOG_FILE"
else
    echo "No changes detected in the world folder, skipping backup..." >> "$LOG_FILE"
fi

# Start the Nitrox pod again
echo "Starting Nitrox pod..." >> "$LOG_FILE"
kubectl -n default scale deployment/nitrox-subnautica --replicas=1

# End of backup process
echo "Backup process finished at $(date)" >> "$LOG_FILE"
