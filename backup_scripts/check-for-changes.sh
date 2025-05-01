#!/bin/bash

WORLD_FOLDER="/mnt/internal_drive/games/nitrox/Nitrox_1.7.1.0/world"
CHECKSUM_FILE="/tmp/nitrox_world_checksum.md5"
NEW_SUM=$(find "$WORLD_FOLDER" -type f -exec md5sum {} + | md5sum)

if [ -f "$CHECKSUM_FILE" ] && grep -q "$NEW_SUM" "$CHECKSUM_FILE"; then
    echo "🛑 No world changes detected — skipping backup"
    exit 0
else
    echo "$NEW_SUM" > "$CHECKSUM_FILE"
    echo "✅ World changes detected — proceeding with backup"
fi
