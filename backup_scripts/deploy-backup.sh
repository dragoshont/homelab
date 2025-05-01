#!/bin/bash

# Get mandatory input from the user
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <backup_YYYYMMDD_HHMMSS>"
    exit 1
fi

backup_name="$1"
backup_path="/media/nas/games/nitrox-saves/$backup_name"

# Check if the specified backup folder exists
if [ ! -d "$backup_path" ]; then
    echo "Error: Backup folder $backup_path does not exist."
    exit 1
fi

# Run the nitrox-backup script before proceeding
nitrox-backup.sh

# Suspend the deployment
kubectl scale deployment nitrox-subnautica --replicas=0

# Copy the world folder from the backup to the target location
rsync -av --no-group "$backup_path/world/" "/mnt/internal_drive/games/nitrox/Nitrox_1.7.1.0/world" --chmod=ugo=rwX

# Rescale the deployment to 1
kubectl scale deployment nitrox-subnautica --replicas=1

echo "Restore completed from $backup_path and deployment rescaled to 1."
