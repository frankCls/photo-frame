#!/bin/bash
#
# Raspberry Pi Photo Frame - Sync Script
# Syncs photos from Google Drive and processes them for display
#
# This script:
# 1. Prevents concurrent executions (PID lock)
# 2. Syncs photos from Google Drive using rclone (optimized for Pi Zero 2 W)
# 3. Processes new images with Python script
# 4. Logs all operations
#

set -e  # Exit on error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/photoframe_config.ini"

# Function to read config values
read_config() {
    local section=$1
    local key=$2
    local default=$3

    # Use python to parse INI file (more reliable than bash parsing)
    value=$(python3 -c "
import configparser
import sys
config = configparser.ConfigParser()
config.read('$CONFIG_FILE')
try:
    print(config.get('$section', '$key'))
except:
    print('$default')
" 2>/dev/null)

    echo "$value"
}

# Prevent concurrent runs (PID file locking)
LOCKFILE="/tmp/photoframe_sync.lock"
if [ -f "$LOCKFILE" ]; then
    PID=$(cat "$LOCKFILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Sync already running (PID: $PID). Exiting."
        exit 0
    else
        echo "Removing stale lock file"
        rm -f "$LOCKFILE"
    fi
fi

# Create lock file
echo $$ > "$LOCKFILE"

# Ensure lock file is removed on exit
trap "rm -f $LOCKFILE" EXIT

# Load configuration
GDRIVE_REMOTE=$(read_config "Sync" "gdrive_remote" "gdrive:PhotoFrame_Uploads")
RAW_DIR=$(read_config "Paths" "raw_photos_dir" "$HOME/photoframe_data/raw_photos")
LOG_FILE=$(read_config "Paths" "log_file" "$HOME/photoframe_data/logs/sync.log")
TRANSFERS=$(read_config "RcloneOptions" "transfers" "2")
CHECKERS=$(read_config "RcloneOptions" "checkers" "2")
RETRIES=$(read_config "RcloneOptions" "low_level_retries" "10")

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Ensure raw directory exists
mkdir -p "$RAW_DIR"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=========================================="
log "Starting photo sync and processing"
log "Remote: $GDRIVE_REMOTE"
log "Local: $RAW_DIR"

# Check if rclone is configured
if ! rclone listremotes | grep -q "^$(echo $GDRIVE_REMOTE | cut -d: -f1):$"; then
    log "ERROR: rclone remote not configured. Run: ./scripts/setup_rclone.sh"
    exit 1
fi

# Sync from Google Drive
# Optimized for Raspberry Pi Zero 2 W (512MB RAM):
# --transfers: Limit concurrent downloads to reduce memory usage
# --checkers: Limit file comparisons to reduce CPU load
# --low-level-retries: Handle WiFi instability
# --ignore-errors: Continue on individual file errors
# --delete-excluded: Remove files from local that were deleted from remote

log "Starting rclone sync..."

if rclone sync "$GDRIVE_REMOTE" "$RAW_DIR" \
    --transfers "$TRANSFERS" \
    --checkers "$CHECKERS" \
    --low-level-retries "$RETRIES" \
    --ignore-errors \
    --delete-excluded \
    --verbose \
    2>&1 | tee -a "$LOG_FILE"; then

    log "Rclone sync completed successfully"

    # Process images with Python
    log "Starting image processing..."

    if python3 "$PROJECT_DIR/src/process_images.py" "$CONFIG_FILE" 2>&1 | tee -a "$LOG_FILE"; then
        log "Image processing completed successfully"
    else
        log "ERROR: Image processing failed"
        exit 1
    fi

else
    log "ERROR: Rclone sync failed. Check network connection and rclone configuration"
    exit 1
fi

log "Sync and processing complete"
log "=========================================="
