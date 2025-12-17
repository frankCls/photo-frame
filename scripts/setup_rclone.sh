#!/bin/bash
#
# Raspberry Pi Photo Frame - Rclone Setup Helper
# Interactive wizard to configure Google Drive access
#

set -e

echo "=============================================="
echo "  Photo Frame - Google Drive Setup"
echo "=============================================="
echo ""

# Check if rclone is installed
if ! command -v rclone &> /dev/null; then
    echo "ERROR: rclone is not installed"
    echo "Please run the main installer first: sudo ./scripts/install.sh"
    exit 1
fi

echo "This wizard will help you configure Google Drive access for your photo frame."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  HEADLESS CONFIGURATION NOTICE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Since you're on a headless Pi (no browser), you have two options:"
echo ""
echo "Option 1: Configure on your computer, then copy config (EASIEST)"
echo "  1. On your Mac/PC: brew install rclone (or download from rclone.org)"
echo "  2. Run: rclone config"
echo "  3. Set up Google Drive following the prompts"
echo "  4. Find config: rclone config file"
echo "  5. Copy to Pi: scp ~/.config/rclone/rclone.conf pi@<pi-ip>:~/.config/rclone/"
echo "  6. Then run this script again"
echo ""
echo "Option 2: Configure here in headless mode"
echo "  1. Run rclone config on this Pi"
echo "  2. When you see a URL (http://127.0.0.1:53682/...), COPY IT"
echo "  3. Paste URL into browser on your Mac/PC"
echo "  4. Authorize Google Drive"
echo "  5. Copy the authorization code shown"
echo "  6. Paste it back into the Pi terminal"
echo ""
read -p "Press Enter to continue with Option 2, or Ctrl+C to use Option 1..."

# Get desired remote name
echo ""
echo "First, choose a name for your Google Drive connection."
echo "Default: gdrive"
read -p "Remote name [gdrive]: " REMOTE_NAME
REMOTE_NAME=${REMOTE_NAME:-gdrive}

# Check if remote already exists
if rclone listremotes | grep -q "^${REMOTE_NAME}:$"; then
    echo ""
    echo "WARNING: Remote '$REMOTE_NAME' already exists"
    read -p "Do you want to reconfigure it? (y/n): " RECONFIGURE
    if [[ ! $RECONFIGURE =~ ^[Yy]$ ]]; then
        echo "Setup cancelled"
        exit 0
    fi
    rclone config delete "$REMOTE_NAME"
fi

# Start rclone config
echo ""
echo "Starting rclone configuration..."
echo "Please follow these steps:"
echo ""
echo "1. Type: n (for new remote)"
echo "2. Name: $REMOTE_NAME"
echo "3. Storage: Type the number for 'drive' (Google Drive)"
echo "4. Client ID: Press Enter (leave blank)"
echo "5. Client Secret: Press Enter (leave blank)"
echo "6. Scope: Type 1 (full access)"
echo "7. Root folder ID: Press Enter (leave blank)"
echo "8. Service Account: Press Enter (leave blank)"
echo "9. Edit advanced config: n"
echo "10. Use auto config: n (IMPORTANT: type 'n' for headless)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  IMPORTANT: After step 10, you'll see a URL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1. COPY the URL that starts with http://127.0.0.1:53682/"
echo "  2. Open it in a browser ON YOUR MAC/PC (not the Pi)"
echo "  3. Log into Google and authorize rclone"
echo "  4. Google will show you a code - COPY IT"
echo "  5. PASTE the code back here in the Pi terminal"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "11. After pasting code: Configure as team drive: n"
echo "12. Confirm: y"
echo "13. Quit: q"
echo ""
read -p "Press Enter to start rclone config..."

rclone config

# Verify setup
echo ""
echo "Verifying Google Drive connection..."

if rclone listremotes | grep -q "^${REMOTE_NAME}:$"; then
    echo "✓ Remote '$REMOTE_NAME' configured successfully"

    # Test connection
    if rclone lsd "${REMOTE_NAME}:" > /dev/null 2>&1; then
        echo "✓ Connection test successful"

        # List top-level folders
        echo ""
        echo "Available folders in your Google Drive:"
        rclone lsd "${REMOTE_NAME}:"
        echo ""

        # Get folder path
        echo "Enter the folder path for photo uploads."
        echo "This is where family members will upload photos."
        echo "Example: PhotoFrame_Uploads"
        read -p "Folder name: " FOLDER_NAME

        if [ -z "$FOLDER_NAME" ]; then
            echo "ERROR: Folder name cannot be empty"
            exit 1
        fi

        # Create folder if it doesn't exist
        FULL_REMOTE="${REMOTE_NAME}:${FOLDER_NAME}"
        if ! rclone lsd "$FULL_REMOTE" > /dev/null 2>&1; then
            echo "Folder doesn't exist. Creating it..."
            rclone mkdir "$FULL_REMOTE"
            echo "✓ Folder created"
        fi

        # Update config file
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
        CONFIG_FILE="$PROJECT_DIR/photoframe_config.ini"

        if [ -f "$CONFIG_FILE" ]; then
            # Update gdrive_remote in config
            python3 -c "
import configparser
config = configparser.ConfigParser()
config.read('$CONFIG_FILE')
config.set('Sync', 'gdrive_remote', '$FULL_REMOTE')
with open('$CONFIG_FILE', 'w') as f:
    config.write(f)
"
            echo "✓ Updated configuration file"
        fi

        echo ""
        echo "=============================================="
        echo "  Setup Complete!"
        echo "=============================================="
        echo ""
        echo "Google Drive remote: $FULL_REMOTE"
        echo ""
        echo "Next steps:"
        echo "1. Share the '$FOLDER_NAME' folder with family members"
        echo "2. Test the sync: ./scripts/sync.sh"
        echo "3. Check logs: tail -f ~/photoframe_data/logs/sync.log"
        echo ""
        echo "Family members can now upload photos to this folder,"
        echo "and they will automatically sync to your photo frame!"

    else
        echo "✗ Connection test failed"
        echo "Please check your configuration and try again"
        exit 1
    fi
else
    echo "✗ Remote configuration failed"
    exit 1
fi
