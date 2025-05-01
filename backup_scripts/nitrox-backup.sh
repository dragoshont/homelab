#!/bin/bash

# Define paths
world_folder="/mnt/internal_drive/games/subnautica/world"
backup_folder="/media/nas/games/nitrox-saves"
backup_timestamp=$(date +"%Y%m%d_%H%M%S")
backup_path="$backup_folder/backup_${backup_timestamp}"

# Define the hash file to track the last backup hash (stored on the NAS)
hash_file="$backup_folder/last_backup_hash.txt"

# Check if world folder has changed since last backup
last_hash=$(cat "$hash_file" 2>/dev/null)

# Generate a new hash for the world folder (using md5sum for simplicity)
new_hash=$(find "$world_folder" -type f -exec md5sum {} + | md5sum | awk '{ print $1 }')

if [ "$last_hash" != "$new_hash" ]; then
    echo "Changes detected, performing backup..."

    # Create the backup folder
    mkdir -p "$backup_path"

    # Perform the backup (you can modify the rsync command or use another method)
    rsync -av --exclude='*.tmp' --exclude='*.log' "$world_folder" "$backup_path"

    # Update the last backup hash on the NAS
    echo "$new_hash" > "$hash_file"

    echo "Backup completed at $backup_path"
else
    echo "No changes detected, skipping backup."
fi
