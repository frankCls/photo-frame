#!/bin/bash
#
# Raspberry Pi Photo Frame - Setup Verification
# Tests all components to ensure everything is configured correctly
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/photoframe_config.ini"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
PASS=0
FAIL=0
WARN=0

echo "=============================================="
echo "  Photo Frame Setup Verification"
echo "=============================================="
echo ""

# Function to print test result
test_result() {
    local status=$1
    local message=$2
    local detail=$3

    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} $message"
        ((PASS++))
    elif [ "$status" = "FAIL" ]; then
        echo -e "${RED}✗${NC} $message"
        if [ -n "$detail" ]; then
            echo "  → $detail"
        fi
        ((FAIL++))
    elif [ "$status" = "WARN" ]; then
        echo -e "${YELLOW}⚠${NC} $message"
        if [ -n "$detail" ]; then
            echo "  → $detail"
        fi
        ((WARN++))
    fi
}

# Test 1: Python 3
echo "Testing Python environment..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    test_result "PASS" "Python 3 installed: $PYTHON_VERSION"
else
    test_result "FAIL" "Python 3 not found"
fi

# Test 2: Pillow
if python3 -c "import PIL" &> /dev/null; then
    PILLOW_VERSION=$(python3 -c "import PIL; print(PIL.__version__)")
    test_result "PASS" "Pillow library installed: v$PILLOW_VERSION"
else
    test_result "FAIL" "Pillow library not installed" "Run: pip3 install -r requirements.txt"
fi

# Test 3: rclone
if command -v rclone &> /dev/null; then
    RCLONE_VERSION=$(rclone version | head -n 1)
    test_result "PASS" "rclone installed: $RCLONE_VERSION"

    # Test 3a: rclone configuration
    if [ -f "$CONFIG_FILE" ]; then
        DROPBOX_REMOTE=$(python3 -c "import configparser; c=configparser.ConfigParser(); c.read('$CONFIG_FILE'); print(c.get('Sync','gdrive_remote'))" 2>/dev/null)
        REMOTE_NAME=$(echo "$DROPBOX_REMOTE" | cut -d: -f1)

        if rclone listremotes | grep -q "^${REMOTE_NAME}:$"; then
            test_result "PASS" "rclone remote '$REMOTE_NAME' configured"

            # Test connection
            if rclone lsd "$DROPBOX_REMOTE" > /dev/null 2>&1; then
                test_result "PASS" "Google Drive connection working"
            else
                test_result "WARN" "Cannot connect to Google Drive" "Check internet connection or run: ./scripts/setup_rclone.sh"
            fi
        else
            test_result "FAIL" "rclone remote not configured" "Run: ./scripts/setup_rclone.sh"
        fi
    fi
else
    test_result "FAIL" "rclone not installed"
fi

# Test 4: Configuration file
if [ -f "$CONFIG_FILE" ]; then
    test_result "PASS" "Configuration file exists"

    # Validate config can be read
    if python3 -c "import configparser; c=configparser.ConfigParser(); c.read('$CONFIG_FILE')" &> /dev/null; then
        test_result "PASS" "Configuration file is valid"
    else
        test_result "FAIL" "Configuration file has errors"
    fi
else
    test_result "FAIL" "Configuration file not found" "Expected: $CONFIG_FILE"
fi

# Test 5: Directories
if [ -f "$CONFIG_FILE" ]; then
    BASE_DIR=$(python3 -c "import configparser; c=configparser.ConfigParser(); c.read('$CONFIG_FILE'); print(c.get('Paths','base_dir'))" 2>/dev/null)

    if [ -d "$BASE_DIR" ]; then
        test_result "PASS" "Base directory exists: $BASE_DIR"
    else
        test_result "WARN" "Base directory doesn't exist yet" "Will be created on first sync"
    fi

    RAW_DIR=$(python3 -c "import configparser; c=configparser.ConfigParser(); c.read('$CONFIG_FILE'); print(c.get('Paths','raw_photos_dir'))" 2>/dev/null)
    if [ -d "$RAW_DIR" ]; then
        test_result "PASS" "Raw photos directory exists"
    else
        test_result "WARN" "Raw photos directory doesn't exist yet" "Will be created on first sync"
    fi

    PROC_DIR=$(python3 -c "import configparser; c=configparser.ConfigParser(); c.read('$CONFIG_FILE'); print(c.get('Paths','processed_photos_dir'))" 2>/dev/null)
    if [ -d "$PROC_DIR" ]; then
        test_result "PASS" "Processed photos directory exists"
    else
        test_result "WARN" "Processed photos directory doesn't exist yet" "Will be created on first run"
    fi
fi

# Test 6: Image processor
if [ -f "$PROJECT_DIR/src/process_images.py" ]; then
    test_result "PASS" "Image processor script exists"

    # Test if it's executable with Python
    if python3 "$PROJECT_DIR/src/process_images.py" --help &> /dev/null || true; then
        test_result "PASS" "Image processor can be executed"
    fi
else
    test_result "FAIL" "Image processor script not found"
fi

# Test 7: Sync script
if [ -f "$SCRIPT_DIR/sync.sh" ]; then
    test_result "PASS" "Sync script exists"

    if [ -x "$SCRIPT_DIR/sync.sh" ]; then
        test_result "PASS" "Sync script is executable"
    else
        test_result "WARN" "Sync script not executable" "Run: chmod +x $SCRIPT_DIR/sync.sh"
    fi
else
    test_result "FAIL" "Sync script not found"
fi

# Test 8: Cron job
if crontab -l 2>/dev/null | grep -q "photoframe.*sync.sh"; then
    test_result "PASS" "Cron job configured"
else
    test_result "WARN" "Cron job not configured" "Sync won't run automatically"
fi

# Test 9: Systemd service (if on Pi)
if [ -f "/etc/systemd/system/photoframe.service" ]; then
    test_result "PASS" "Systemd service installed"

    if systemctl is-enabled photoframe.service &> /dev/null; then
        test_result "PASS" "Systemd service enabled (auto-start on boot)"
    else
        test_result "WARN" "Systemd service not enabled"
    fi

    if systemctl is-active photoframe.service &> /dev/null; then
        test_result "PASS" "Systemd service is running"
    else
        test_result "WARN" "Systemd service not running" "Pi3D slideshow not active"
    fi
else
    test_result "WARN" "Systemd service not installed" "Pi3D won't auto-start on boot"
fi

# Test 10: Pi3D (if on Pi)
if command -v pi3d &> /dev/null || python3 -c "import pi3d" &> /dev/null; then
    test_result "PASS" "Pi3D installed"
else
    test_result "WARN" "Pi3D not detected" "Required for slideshow display"
fi

# Test 11: WiFi power management (if on Pi with wlan0)
if [ -e "/sys/class/net/wlan0" ]; then
    POWER_SAVE=$(iw dev wlan0 get power_save 2>/dev/null || echo "unknown")
    if [[ $POWER_SAVE == *"off"* ]]; then
        test_result "PASS" "WiFi power management disabled"
    else
        test_result "WARN" "WiFi power management may be enabled" "Can cause sync issues on Pi Zero 2 W"
    fi
fi

# Test 12: GPU memory (if on Pi)
if [ -f "/boot/config.txt" ] || [ -f "/boot/firmware/config.txt" ]; then
    CONFIG_TXT="/boot/config.txt"
    [ -f "/boot/firmware/config.txt" ] && CONFIG_TXT="/boot/firmware/config.txt"

    GPU_MEM=$(grep "^gpu_mem" "$CONFIG_TXT" 2>/dev/null | cut -d= -f2)
    if [ -n "$GPU_MEM" ] && [ "$GPU_MEM" -ge 128 ]; then
        test_result "PASS" "GPU memory configured: ${GPU_MEM}MB"
    else
        test_result "WARN" "GPU memory not optimally configured" "Recommended: 128MB for smooth display"
    fi
fi

# Summary
echo ""
echo "=============================================="
echo "  Test Summary"
echo "=============================================="
echo -e "${GREEN}Passed:${NC} $PASS"
echo -e "${YELLOW}Warnings:${NC} $WARN"
echo -e "${RED}Failed:${NC} $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
    echo "✓ All critical tests passed!"
    if [ $WARN -gt 0 ]; then
        echo "⚠ Some optional components have warnings (see above)"
    fi
    echo ""
    echo "Next steps:"
    echo "1. Test sync: ./scripts/sync.sh"
    echo "2. Check logs: tail -f ~/photo-frame/logs/sync.log"
    echo "3. Reboot to start the slideshow: sudo reboot"
    exit 0
else
    echo "✗ Some critical tests failed. Please fix the issues above."
    exit 1
fi
