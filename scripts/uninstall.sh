#!/bin/bash
#
# Raspberry Pi Photo Frame - Uninstaller
# Removes photo frame components and optionally cleans up data
#

set -e

# Check if running as root for systemd operations
if [ "$EUID" -ne 0 ]; then
    echo "This script requires sudo privileges for some operations."
    read -p "Continue anyway? (y/n): " CONTINUE
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        echo "Please run with sudo: sudo $0"
        exit 1
    fi
fi

echo "=============================================="
echo "  Photo Frame Uninstaller"
echo "=============================================="
echo ""
echo "This will remove:"
echo "  - Cron job for automatic syncing"
echo "  - Systemd service for Pi3D auto-start"
echo "  - PID lock files"
echo ""
echo "This will NOT remove:"
echo "  - Python packages (Pillow)"
echo "  - System packages (rclone, pi3d)"
echo "  - Photo files (unless you choose to)"
echo "  - This project directory"
echo ""
read -p "Do you want to continue? (y/n): " CONFIRM

if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/photoframe_config.ini"

# Remove cron job
echo ""
echo "Removing cron job..."
if crontab -l 2>/dev/null | grep -q "photoframe.*sync.sh"; then
    crontab -l | grep -v "photoframe.*sync.sh" | crontab -
    echo "✓ Cron job removed"
else
    echo "ℹ No cron job found"
fi

# Stop and disable systemd service
echo ""
echo "Removing systemd service..."
if [ -f "/etc/systemd/system/photoframe.service" ]; then
    if systemctl is-active photoframe.service &> /dev/null; then
        echo "Stopping service..."
        systemctl stop photoframe.service
        echo "✓ Service stopped"
    fi

    if systemctl is-enabled photoframe.service &> /dev/null; then
        echo "Disabling service..."
        systemctl disable photoframe.service
        echo "✓ Service disabled"
    fi

    echo "Removing service file..."
    rm -f /etc/systemd/system/photoframe.service
    systemctl daemon-reload
    echo "✓ Service removed"
else
    echo "ℹ No systemd service found"
fi

# Remove PID lock file
echo ""
echo "Cleaning up lock files..."
if [ -f "/tmp/photoframe_sync.lock" ]; then
    rm -f /tmp/photoframe_sync.lock
    echo "✓ Lock file removed"
fi

# Ask about photo data
echo ""
echo "Photo data management:"
if [ -f "$CONFIG_FILE" ]; then
    BASE_DIR=$(python3 -c "import configparser; c=configparser.ConfigParser(); c.read('$CONFIG_FILE'); print(c.get('Paths','base_dir'))" 2>/dev/null || echo "")

    if [ -n "$BASE_DIR" ] && [ -d "$BASE_DIR" ]; then
        echo "Found photo data directory: $BASE_DIR"
        du -sh "$BASE_DIR" 2>/dev/null || true
        echo ""
        read -p "Do you want to DELETE all photo data? (y/n): " DELETE_PHOTOS

        if [[ $DELETE_PHOTOS =~ ^[Yy]$ ]]; then
            read -p "Are you SURE? This cannot be undone! (y/n): " CONFIRM_DELETE
            if [[ $CONFIRM_DELETE =~ ^[Yy]$ ]]; then
                echo "Deleting photo data..."
                rm -rf "$BASE_DIR"
                echo "✓ Photo data deleted"
            else
                echo "ℹ Photo data preserved"
            fi
        else
            echo "ℹ Photo data preserved at: $BASE_DIR"
        fi
    fi
fi

# Ask about rclone configuration
echo ""
echo "Rclone configuration:"
if command -v rclone &> /dev/null; then
    if [ -f "$CONFIG_FILE" ]; then
        GDRIVE_REMOTE=$(python3 -c "import configparser; c=configparser.ConfigParser(); c.read('$CONFIG_FILE'); print(c.get('Sync','gdrive_remote'))" 2>/dev/null | cut -d: -f1)

        if [ -n "$GDRIVE_REMOTE" ] && rclone listremotes | grep -q "^${GDRIVE_REMOTE}:$"; then
            echo "Found rclone remote: $GDRIVE_REMOTE"
            read -p "Do you want to remove this rclone remote? (y/n): " DELETE_RCLONE

            if [[ $DELETE_RCLONE =~ ^[Yy]$ ]]; then
                rclone config delete "$GDRIVE_REMOTE"
                echo "✓ Rclone remote removed"
            else
                echo "ℹ Rclone remote preserved"
            fi
        fi
    fi
fi

echo ""
echo "=============================================="
echo "  Uninstall Complete"
echo "=============================================="
echo ""
echo "Removed components:"
echo "  ✓ Cron job"
echo "  ✓ Systemd service"
echo "  ✓ Lock files"
echo ""
echo "To completely remove the project:"
echo "  cd ~ && rm -rf $PROJECT_DIR"
echo ""
echo "To remove system packages (optional):"
echo "  sudo apt remove --purge rclone"
echo "  pip3 uninstall Pillow"
echo ""
