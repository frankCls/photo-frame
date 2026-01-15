#!/bin/bash
#
# Raspberry Pi Photo Frame - Automated Installer
# Complete setup script for the digital photo frame
#
# This script:
# - Installs system dependencies
# - Creates directory structure
# - Installs Python packages
# - Configures rclone (optional)
# - Sets up cron job for syncing
# - Installs systemd service for auto-start
# - Optimizes Pi Zero 2 W settings
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/photoframe_config.ini"

echo -e "${BLUE}=============================================="
echo "  Raspberry Pi Photo Frame Installer"
echo -e "==============================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

# Get the actual user (not root)
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

echo "Installing for user: $REAL_USER"
echo "Home directory: $REAL_HOME"
echo ""

# Pre-flight checks
echo -e "${BLUE}Running pre-flight checks...${NC}"

# Check internet connection
if ! ping -c 1 google.com &> /dev/null; then
    echo -e "${YELLOW}Warning: No internet connection detected${NC}"
    read -p "Continue anyway? (y/n): " CONTINUE
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Configuration file not found: $CONFIG_FILE${NC}"
    echo "Please ensure photoframe_config.ini exists"
    exit 1
fi
echo -e "   ${GREEN}✓${NC} Configuration file found"

# Check if running on Raspberry Pi
if [ ! -f /proc/device-tree/model ]; then
    echo -e "${YELLOW}Warning: This doesn't appear to be a Raspberry Pi${NC}"
    read -p "Continue anyway? (y/n): " CONTINUE
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    PI_MODEL=$(cat /proc/device-tree/model)
    echo -e "   ${GREEN}✓${NC} Detected: $PI_MODEL"
fi

echo ""

# Step 1: Update system
echo -e "${BLUE}Step 1: Updating system package lists...${NC}"
apt-get update
echo -e "   ${GREEN}✓${NC} System updated"
echo ""

# Step 2: Install system dependencies
echo -e "${BLUE}Step 2: Installing system dependencies...${NC}"

PACKAGES=(
    python3
    python3-pip
    python3-pil
    rclone
    curl
    git
    libsdl2-2.0-0
    libsdl2-dev
)

for package in "${PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $package "; then
        echo "  ℹ $package already installed"
    else
        echo "  Installing $package..."
        apt-get install -y "$package"
        echo -e "  ${GREEN}✓${NC} $package installed"
    fi
done

echo -e "   ${GREEN}✓${NC} System dependencies installed"
echo ""

# Step 2.1: Configure user permissions for GPU/TTY access
echo -e "${BLUE}Step 2.1: Configuring user permissions...${NC}"

# Add user to required groups for X11/GPU access
REQUIRED_GROUPS="video tty input render"
for group in $REQUIRED_GROUPS; do
    if groups "$REAL_USER" | grep -q "\b$group\b"; then
        echo "  ℹ User already in group: $group"
    else
        echo "  Adding $REAL_USER to group: $group"
        usermod -a -G "$group" "$REAL_USER"
    fi
done

echo -e "${GREEN}✓${NC} User permissions configured"
echo ""

# Step 2.2: Create /home/pi symlink for Pi3D demos compatibility
echo -e "${BLUE}Step 2.2: Configuring path compatibility...${NC}"

if [ "$REAL_USER" = "pi" ]; then
    echo "  ℹ Running as user 'pi', no symlink needed"
elif [ -L "/home/pi" ]; then
    # Symlink already exists - verify target
    CURRENT_TARGET=$(readlink /home/pi)
    if [ "$CURRENT_TARGET" = "$REAL_HOME" ]; then
        echo "  ℹ /home/pi symlink already configured correctly"
    else
        echo -e "  ${YELLOW}⚠${NC} /home/pi symlink points to wrong location, recreating..."
        rm -f /home/pi
        ln -s "$REAL_HOME" /home/pi
        echo -e "  ${GREEN}✓${NC} /home/pi → $REAL_HOME (fixed)"
    fi
else
    # Directory exists or doesn't exist - remove and create symlink
    if [ -d "/home/pi" ] || [ -e "/home/pi" ]; then
        echo "  Removing existing /home/pi..."
        rm -rf /home/pi
    fi

    echo "  Creating /home/pi symlink for Pi3D demos compatibility..."
    ln -s "$REAL_HOME" /home/pi
    echo -e "  ${GREEN}✓${NC} /home/pi → $REAL_HOME"
    echo "  Pi3D hardcoded paths will now work correctly"
fi

echo ""

# Step 2.5: Create virtual environment for Pi3D
echo -e "${BLUE}Step 2.5: Setting up Python virtual environment...${NC}"

VENV_DIR="$REAL_HOME/photoframe_env"

# Check for uv and offer to install it
USE_UV=false
if sudo -u "$REAL_USER" bash -c "command -v uv" &> /dev/null || [ -f "$REAL_HOME/.local/bin/uv" ] || [ -f "$REAL_HOME/.cargo/bin/uv" ]; then
    USE_UV=true
    echo "  ℹ uv detected - will use uv for faster package installation"
else
    echo "  💡 uv not found - uv is a fast Python package installer (10-100x faster than pip)"
    read -p "  Install uv now? (recommended, y/n): " INSTALL_UV
    if [[ "$INSTALL_UV" =~ ^[Yy]$ ]]; then
        echo "  Installing uv..."
        sudo -u "$REAL_USER" bash -c "curl -LsSf https://astral.sh/uv/install.sh | sh"

        # Check if uv was installed successfully
        if [ -f "$REAL_HOME/.local/bin/uv" ] || [ -f "$REAL_HOME/.cargo/bin/uv" ]; then
            USE_UV=true
            echo -e "  ${GREEN}✓${NC} uv installed"
        else
            echo -e "  ${YELLOW}⚠${NC} uv installation may have failed, falling back to pip"
        fi
    else
        echo "  Continuing with pip (slower)"
    fi
fi

# Check if venv exists and is healthy
VENV_NEEDS_RECREATION=false
if [ -d "$VENV_DIR" ]; then
    echo "  ℹ Virtual environment already exists at $VENV_DIR"

    # Check if venv is healthy (has python and pip or can install packages)
    if [ ! -f "$VENV_DIR/bin/python3" ]; then
        echo -e "  ${YELLOW}⚠${NC} Virtual environment is broken (no python3), recreating..."
        VENV_NEEDS_RECREATION=true
    fi
fi

if [ ! -d "$VENV_DIR" ] || [ "$VENV_NEEDS_RECREATION" = true ]; then
    if [ "$VENV_NEEDS_RECREATION" = true ]; then
        rm -rf "$VENV_DIR"
    fi

    echo "  Creating virtual environment at $VENV_DIR..."
    if [ "$USE_UV" = true ]; then
        # Use uv to create venv (faster)
        echo "  Using uv venv..."
        sudo -u "$REAL_USER" bash -c "export PATH=\"$REAL_HOME/.local/bin:$REAL_HOME/.cargo/bin:\$PATH\"; uv venv '$VENV_DIR'"
    else
        # Fall back to standard venv
        echo "  Using python3 -m venv..."
        sudo -u "$REAL_USER" python3 -m venv "$VENV_DIR"
    fi
    chown -R "$REAL_USER:$REAL_USER" "$VENV_DIR"
    echo -e "  ${GREEN}✓${NC} Virtual environment created"
fi

# Set Python path for later steps
VENV_PYTHON="$VENV_DIR/bin/python3"

echo -e "   ${GREEN}✓${NC} Python environment ready"
echo ""

# Step 3: Install Python packages
echo -e "${BLUE}Step 3: Installing Python packages...${NC}"

if [ "$USE_UV" = true ]; then
    echo "  Using uv for faster installation..."
    sudo -u "$REAL_USER" bash -c "export PATH=\"$REAL_HOME/.local/bin:$REAL_HOME/.cargo/bin:\$PATH\"; uv pip install --python '$VENV_PYTHON' -r '$PROJECT_DIR/requirements.txt'"
else
    echo "  Using pip..."
    sudo -u "$REAL_USER" "$VENV_PYTHON" -m pip install -r "$PROJECT_DIR/requirements.txt"
fi

echo -e "   ${GREEN}✓${NC} Python packages installed"
echo ""

# Step 3.5: Install Pi3D
echo -e "${BLUE}Step 3.5: Installing Pi3D...${NC}"

# Check if Pi3D is already installed in venv
if sudo -u "$REAL_USER" "$VENV_PYTHON" -c "import pi3d" &> /dev/null; then
    PI3D_VERSION=$(sudo -u "$REAL_USER" "$VENV_PYTHON" -c "import pi3d; print(pi3d.__version__)" 2>/dev/null || echo "unknown")
    echo "  ℹ Pi3D already installed (version: $PI3D_VERSION)"
else
    echo "  Installing Pi3D in virtual environment..."

    if [ "$USE_UV" = true ]; then
        echo "  Using uv for faster installation..."
        sudo -u "$REAL_USER" bash -c "export PATH=\"$REAL_HOME/.local/bin:$REAL_HOME/.cargo/bin:\$PATH\"; uv pip install --python '$VENV_PYTHON' pi3d"
    else
        echo "  Using pip to install Pi3D..."
        sudo -u "$REAL_USER" "$VENV_PYTHON" -m pip install pi3d
    fi

    echo -e "  ${GREEN}✓${NC} Pi3D installed"
fi

echo -e "   ${GREEN}✓${NC} Pi3D ready"
echo ""

# Step 3.75: Clone pi3d_demos repository
echo -e "${BLUE}Step 3.75: Setting up Pi3D demos...${NC}"

PI3D_DEMOS_DIR="$REAL_HOME/pi3d_demos"

if [ -d "$PI3D_DEMOS_DIR" ]; then
    echo "  ℹ pi3d_demos already exists at $PI3D_DEMOS_DIR"

    # Check if PictureFrame2020.py exists
    if [ ! -f "$PI3D_DEMOS_DIR/PictureFrame2020.py" ]; then
        echo -e "  ${YELLOW}⚠${NC} PictureFrame2020.py not found, re-cloning..."
        rm -rf "$PI3D_DEMOS_DIR"
        sudo -u "$REAL_USER" git clone https://github.com/pi3d/pi3d_demos.git "$PI3D_DEMOS_DIR"
        chown -R "$REAL_USER:$REAL_USER" "$PI3D_DEMOS_DIR"
        echo -e "  ${GREEN}✓${NC} pi3d_demos cloned"
    fi
else
    echo "  Cloning pi3d_demos repository..."
    sudo -u "$REAL_USER" git clone https://github.com/pi3d/pi3d_demos.git "$PI3D_DEMOS_DIR"
    chown -R "$REAL_USER:$REAL_USER" "$PI3D_DEMOS_DIR"
    echo -e "  ${GREEN}✓${NC} pi3d_demos cloned"
fi

# Verify critical file exists
if [ -f "$PI3D_DEMOS_DIR/PictureFrame2020.py" ]; then
    echo -e "  ${GREEN}✓${NC} PictureFrame2020.py found"
else
    echo -e "  ${RED}✗${NC} PictureFrame2020.py not found in $PI3D_DEMOS_DIR"
    echo "  This may cause issues with the photo frame service"
fi

echo -e "   ${GREEN}✓${NC} Pi3D demos ready"
echo ""

# Step 3.8: Configure PictureFrame2020 for Pi Zero 2W
echo -e "${BLUE}Step 3.8: Configuring Ken Burns effects...${NC}"

PI3D_CONFIG="$REAL_HOME/pi3d_demos/PictureFrame2020config.py"

if [ -f "$PI3D_CONFIG" ]; then
    echo "  Optimizing for Pi Zero 2W (512MB RAM)..."

    # Backup original
    cp "$PI3D_CONFIG" "$PI3D_CONFIG.backup" 2>/dev/null || true

    # Enable Ken Burns with optimized settings
    sed -i "s/^KENBURNS = .*/KENBURNS = True/" "$PI3D_CONFIG"
    sed -i "s/^FPS = .*/FPS = 25.0/" "$PI3D_CONFIG"

    # Disable blur edges and fit (conflicts with Ken Burns)
    sed -i "s/^BLUR_EDGES = .*/BLUR_EDGES = False/" "$PI3D_CONFIG"
    sed -i "s/^FIT = .*/FIT = False/" "$PI3D_CONFIG"

    # Set Ken Burns zoom depth for noticeable effect
    if ! grep -q "^kb_depth = " "$PI3D_CONFIG"; then
        echo "kb_depth = 0.15  # 15% zoom for noticeable Ken Burns effect" >> "$PI3D_CONFIG"
    fi

    # Disable all text overlays (info, names, dates, metadata)
    sed -i "s/^SHOW_INFO = .*/SHOW_INFO = False/" "$PI3D_CONFIG"
    sed -i "s/^SHOW_NAMES = .*/SHOW_NAMES = False/" "$PI3D_CONFIG"
    sed -i "s/^SHOW_DATE = .*/SHOW_DATE = False/" "$PI3D_CONFIG"
    sed -i "s/^SHOW_TEXT = .*/SHOW_TEXT = 0/" "$PI3D_CONFIG"

    chown "$REAL_USER:$REAL_USER" "$PI3D_CONFIG"

    echo -e "  ${GREEN}✓${NC} Ken Burns enabled (FPS=25, 15% zoom, no blur/fit, no overlays)"
else
    echo -e "  ${YELLOW}⚠${NC} Config file not found at $PI3D_CONFIG"
    echo "  You can configure manually after installation"
fi

# Configure SDL2 backend for headless operation
echo "  Configuring SDL2 backend for headless DRM/KMS..."

PICTURE_FRAME_SCRIPT="$REAL_HOME/pi3d_demos/PictureFrame2020.py"

if [ -f "$PICTURE_FRAME_SCRIPT" ]; then
    # Check if use_sdl2 is already set
    if ! grep -q "use_sdl2=True" "$PICTURE_FRAME_SCRIPT"; then
        # Backup original
        cp "$PICTURE_FRAME_SCRIPT" "$PICTURE_FRAME_SCRIPT.backup" 2>/dev/null || true

        # Find the Display.create line and add use_sdl2=True
        # This handles multiline Display.create() calls
        sed -i '/DISPLAY = pi3d.Display.create(/,/)/ {
            /)/s/)/, use_sdl2=True)/
        }' "$PICTURE_FRAME_SCRIPT"

        echo -e "  ${GREEN}✓${NC} SDL2 backend enabled in PictureFrame2020.py"
    else
        echo "  ℹ SDL2 backend already enabled"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} PictureFrame2020.py not found"
fi

echo ""
# Step 4: Create directory structure
echo -e "${BLUE}Step 4: Creating directory structure...${NC}"

# Update config file if it uses /home/pi to use actual user's home
if grep -q "base_dir = /home/pi" "$CONFIG_FILE"; then
    echo "  Updating config file to use $REAL_USER's home directory..."
    sed -i "s|/home/pi|$REAL_HOME|g" "$CONFIG_FILE"
    echo -e "  ${GREEN}✓${NC} Config file updated"
fi

BASE_DIR=$(sudo -u "$REAL_USER" python3 -c "import configparser; c=configparser.ConfigParser(); c.read('$CONFIG_FILE'); print(c.get('Paths','base_dir'))")
RAW_DIR=$(sudo -u "$REAL_USER" python3 -c "import configparser; c=configparser.ConfigParser(); c.read('$CONFIG_FILE'); print(c.get('Paths','raw_photos_dir'))")
PROC_DIR=$(sudo -u "$REAL_USER" python3 -c "import configparser; c=configparser.ConfigParser(); c.read('$CONFIG_FILE'); print(c.get('Paths','processed_photos_dir'))")
LOG_DIR=$(dirname "$(sudo -u "$REAL_USER" python3 -c "import configparser; c=configparser.ConfigParser(); c.read('$CONFIG_FILE'); print(c.get('Paths','log_file'))")")

mkdir -p "$BASE_DIR" "$RAW_DIR" "$PROC_DIR" "$LOG_DIR"
chown -R "$REAL_USER:$REAL_USER" "$BASE_DIR"

echo "  ✓ $BASE_DIR"
echo "  ✓ $RAW_DIR"
echo "  ✓ $PROC_DIR"
echo "  ✓ $LOG_DIR"
echo -e "   ${GREEN}✓${NC} Directory structure created"
echo ""

# Step 5: Make scripts executable
echo -e "${BLUE}Step 5: Setting script permissions...${NC}"
chmod +x "$SCRIPT_DIR"/*.sh
chmod +x "$PROJECT_DIR/src/process_images.py"
echo -e "   ${GREEN}✓${NC} Scripts are now executable"
echo ""

# Step 6: Configure rclone
echo -e "${BLUE}Step 6: Rclone configuration...${NC}"
if rclone listremotes &> /dev/null && [ $(rclone listremotes | wc -l) -gt 0 ]; then
    echo "  ℹ Rclone already configured"
    echo "  Current remotes:"
    rclone listremotes | sed 's/^/    /'
    echo ""
    read -p "  Do you want to reconfigure rclone? (y/n): " RECONFIG
    if [[ $RECONFIG =~ ^[Yy]$ ]]; then
        sudo -u "$REAL_USER" "$SCRIPT_DIR/setup_rclone.sh"
    fi
else
    echo "  Rclone not configured yet"
    read -p "  Do you want to configure it now? (y/n): " CONFIG_NOW
    if [[ $CONFIG_NOW =~ ^[Yy]$ ]]; then
        sudo -u "$REAL_USER" "$SCRIPT_DIR/setup_rclone.sh"
    else
        echo -e "  ${YELLOW}⚠${NC} Rclone not configured. Run later: ./scripts/setup_rclone.sh"
    fi
fi
echo ""

# Step 7: Setup cron job
echo -e "${BLUE}Step 7: Setting up cron job for automatic syncing...${NC}"

SYNC_INTERVAL=$(sudo -u "$REAL_USER" python3 -c "import configparser; c=configparser.ConfigParser(); c.read('$CONFIG_FILE'); print(c.get('Sync','sync_interval'))")

CRON_JOB="*/$SYNC_INTERVAL * * * * $SCRIPT_DIR/sync.sh"

# Check if cron job already exists
if sudo -u "$REAL_USER" crontab -l 2>/dev/null | grep -qF "$SCRIPT_DIR/sync.sh"; then
    echo "  ℹ Cron job already exists"
    read -p "  Do you want to update it? (y/n): " UPDATE_CRON
    if [[ $UPDATE_CRON =~ ^[Yy]$ ]]; then
        # Remove old and add new
        sudo -u "$REAL_USER" crontab -l 2>/dev/null | grep -vF "$SCRIPT_DIR/sync.sh" | sudo -u "$REAL_USER" crontab -
        (sudo -u "$REAL_USER" crontab -l 2>/dev/null || true; echo "$CRON_JOB") | sudo -u "$REAL_USER" crontab -
        echo -e "  ${GREEN}✓${NC} Cron job updated"
    else
        echo "  ℹ Keeping existing cron job"
    fi
else
    # Add new cron job
    (sudo -u "$REAL_USER" crontab -l 2>/dev/null || true; echo "$CRON_JOB") | sudo -u "$REAL_USER" crontab -
    echo -e "  ${GREEN}✓${NC} Cron job created: Sync every $SYNC_INTERVAL minutes"
fi
echo ""

# Step 7.5: Setup log rotation
echo -e "${BLUE}Step 7.5: Setting up log rotation...${NC}"

# Check if logrotate is installed (should be by default on Raspberry Pi OS)
if ! command -v logrotate &> /dev/null; then
    echo "  Installing logrotate..."
    apt-get install -y logrotate
    echo -e "  ${GREEN}✓${NC} logrotate installed"
fi

# Get log file path from config (expand ~ to actual home)
LOG_FILE=$(sudo -u "$REAL_USER" python3 -c "
import configparser
import os
c = configparser.ConfigParser()
c.read('$CONFIG_FILE')
log_path = c.get('Paths', 'log_file')
# Expand variables
expanded = os.path.expandvars(log_path.replace('%(base_dir)s', c.get('Paths', 'base_dir')))
print(os.path.expanduser(expanded))
")

# Create logrotate configuration
cat > /etc/logrotate.d/photoframe << EOF
# Log rotation for Raspberry Pi Photo Frame
# Rotates sync logs to prevent disk space exhaustion

$LOG_FILE {
    # Rotation schedule
    daily
    rotate 3
    size 10M
    maxage 3

    # Compression
    compress
    delaycompress

    # File handling
    copytruncate
    notifempty
    missingok

    # Permissions
    create 0644 $REAL_USER $REAL_USER
    su $REAL_USER $REAL_USER

    # Post-rotation notification
    sharedscripts
    postrotate
        /usr/bin/logger -t photoframe "Log rotation completed"
    endscript
}
EOF

# Verify configuration syntax
if logrotate -d /etc/logrotate.d/photoframe &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Log rotation configured (3 days, 10MB max)"
    echo "  Rotated logs: ${LOG_FILE}.1 (current), ${LOG_FILE}.2.gz, ${LOG_FILE}.3.gz"
else
    echo -e "  ${YELLOW}⚠${NC} Log rotation configuration may have errors"
    echo "  Test with: sudo logrotate -d /etc/logrotate.d/photoframe"
fi

echo ""

# Step 8: Install OpenGL ES libraries
echo -e "${BLUE}Step 8: Installing OpenGL ES libraries...${NC}"

if ! dpkg -l | grep -q "libgles2"; then
    echo "  Installing OpenGL ES libraries..."
    apt-get install -y libgles2
    echo -e "  ${GREEN}✓${NC} OpenGL ES installed"
else
    echo "  ℹ OpenGL ES already installed"
fi

echo -e "${GREEN}✓${NC} Graphics libraries ready"
echo ""

# Step 9: Install systemd service
echo -e "${BLUE}Step 9: Installing systemd service for auto-start...${NC}"

# Detect Python path (venv created in Step 2.5)
if [ -f "$REAL_HOME/photoframe_env/bin/python3" ]; then
    PYTHON_PATH="$REAL_HOME/photoframe_env/bin/python3"
elif [ -f "$REAL_HOME/venv_photoframe/bin/python3" ]; then
    PYTHON_PATH="$REAL_HOME/venv_photoframe/bin/python3"
else
    PYTHON_PATH="/usr/bin/python3"
fi

PHOTOFRAME_SCRIPT="$REAL_HOME/pi3d_demos/PictureFrame2020.py"
PROCESSED_DIR="$PROC_DIR"

# Check if Pi3D is installed AND PictureFrame2020.py exists
if "$PYTHON_PATH" -c "import pi3d" &> /dev/null 2>&1 && [ -f "$PHOTOFRAME_SCRIPT" ]; then
    echo "  ℹ Pi3D detected in $PYTHON_PATH"
    echo "  ℹ PictureFrame script found at $PHOTOFRAME_SCRIPT"

    # Generate ExecStart with command-line flag overrides
    EXEC_START="$PYTHON_PATH $PHOTOFRAME_SCRIPT -p $PROCESSED_DIR --show_text \"\" --blur_edges False --fit False --kenburns True --fit_portrait False"
    echo "  ℹ Using direct DRM/KMS execution (headless mode)"

    # Generate service file with actual user, paths, and ExecStart
    sed -e "s|User=pi.*|User=$REAL_USER|g" \
        -e "s|Group=pi.*|Group=$REAL_USER|g" \
        -e "s|WorkingDirectory=/home/pi.*|WorkingDirectory=$PROCESSED_DIR|g" \
        -e "s|Environment=\"HOME=/home/pi\".*|Environment=\"HOME=$REAL_HOME\"|g" \
        -e "s|Environment=\"PYTHONPATH=/home/pi/pi3d_demos\".*|Environment=\"PYTHONPATH=$REAL_HOME/pi3d_demos\"|g" \
        -e "s|/home/pi|$REAL_HOME|g" \
        -e "s|ExecStart=.*|ExecStart=$EXEC_START|g" \
        "$PROJECT_DIR/systemd/photoframe.service" > /etc/systemd/system/photoframe.service

    # Reload systemd
    systemctl daemon-reload

    # Enable service
    systemctl enable photoframe.service
    echo -e "  ${GREEN}✓${NC} Systemd service installed and enabled"
    echo "  Note: Pi3D will start on next boot"
    echo "  To start now: sudo systemctl start photoframe.service"
else
    echo -e "  ${YELLOW}⚠${NC} Cannot install systemd service"

    # Provide specific error messages
    if ! "$PYTHON_PATH" -c "import pi3d" &> /dev/null 2>&1; then
        echo "  Reason: Pi3D not found in $PYTHON_PATH"
        echo "  This should not happen - Step 3.5 should have installed it"
    fi

    if [ ! -f "$PHOTOFRAME_SCRIPT" ]; then
        echo "  Reason: PictureFrame2020.py not found at $PHOTOFRAME_SCRIPT"
        echo "  This should not happen - Step 3.75 should have cloned it"
    fi

    echo ""
    echo "  Manual fix:"
    echo "    1. Check venv: source $REAL_HOME/photoframe_env/bin/activate"
    echo "    2. Verify Pi3D: python3 -c 'import pi3d'"
    echo "    3. Verify script: ls -l $PHOTOFRAME_SCRIPT"
    echo "    4. Re-run installer: sudo ./scripts/install.sh"
fi
echo ""

# Step 10: Optimize Pi Zero 2 W settings
echo -e "${BLUE}Step 10: Optimizing Raspberry Pi settings...${NC}"

# Disable WiFi power management
if [ -e "/sys/class/net/wlan0" ]; then
    echo "  Disabling WiFi power management..."

    # Add to rc.local if it exists
    if [ -f /etc/rc.local ]; then
        if ! grep -q "iw dev wlan0 set power_save off" /etc/rc.local; then
            sed -i '/^exit 0/i iw dev wlan0 set power_save off' /etc/rc.local
        fi
    fi

    # Create systemd service for WiFi power management
    cat > /etc/systemd/system/wifi-powersave-off.service << 'EOF'
[Unit]
Description=Disable WiFi Power Save
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/iw dev wlan0 set power_save off

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable wifi-powersave-off.service
    systemctl start wifi-powersave-off.service &>/dev/null || true

    echo -e "  ${GREEN}✓${NC} WiFi power management disabled"
else
    echo "  ℹ No WiFi interface found, skipping WiFi optimization"
fi

# Configure GPU memory
echo "  Configuring GPU memory allocation..."
CONFIG_TXT="/boot/config.txt"
[ -f "/boot/firmware/config.txt" ] && CONFIG_TXT="/boot/firmware/config.txt"

if [ -f "$CONFIG_TXT" ]; then
    # Check if gpu_mem is already set
    if grep -q "^gpu_mem=" "$CONFIG_TXT"; then
        # Update existing value
        sed -i 's/^gpu_mem=.*/gpu_mem=128/' "$CONFIG_TXT"
    else
        # Add new value
        echo "" >> "$CONFIG_TXT"
        echo "# GPU memory for Pi3D photo frame" >> "$CONFIG_TXT"
        echo "gpu_mem=128" >> "$CONFIG_TXT"
    fi
    echo -e "  ${GREEN}✓${NC} GPU memory set to 128MB (requires reboot)"
else
    echo -e "  ${YELLOW}⚠${NC} Could not find config.txt"
fi


# Force HDMI output for headless operation
echo "  Configuring headless HDMI output..."

CMDLINE_FILE="/boot/firmware/cmdline.txt"

if [ -f "$CMDLINE_FILE" ]; then
    # Check if video parameter already exists
    if ! grep -q "video=HDMI-A-1:" "$CMDLINE_FILE"; then
        # Backup original
        cp "$CMDLINE_FILE" "$CMDLINE_FILE.backup"

        # Add video parameter to end of line (must stay on same line)
        sed -i "s/$/ video=HDMI-A-1:1920x1080@60D/" "$CMDLINE_FILE"
        echo -e "  ${GREEN}✓${NC} HDMI output forced in cmdline.txt"
        echo "  Note: Reboot required for this change to take effect"
    else
        echo "  ℹ HDMI output already configured"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} cmdline.txt not found at $CMDLINE_FILE"
fi
echo -e "   ${GREEN}✓${NC} Pi optimization complete"
echo ""

# Step 11: Run verification
echo -e "${BLUE}Step 11: Running setup verification...${NC}"
echo ""

sudo -u "$REAL_USER" "$SCRIPT_DIR/test_setup.sh" || true

echo ""

# Step 12: Headless configuration guidance
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📺 Headless Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}IMPORTANT: Reboot required for HDMI force to take effect${NC}"
echo ""
echo "After reboot:"
echo "  sudo systemctl start photoframe.service"
echo ""
echo "Monitor logs:"
echo "  journalctl -u photoframe.service -f"
echo ""
echo "The photo frame will run in true headless mode using DRM/KMS."
echo "No screen needed - GPU renders directly to framebuffer."
echo ""

echo -e "${GREEN}=============================================="
echo "  Installation Complete!"
echo -e "==============================================${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. Edit configuration (if needed):"
echo "   nano $CONFIG_FILE"
echo ""
echo "2. Configure Dropbox (if not done):"
echo "   ./scripts/setup_rclone.sh"
echo ""
echo "3. Test the sync:"
echo "   ./scripts/sync.sh"
echo ""
echo "4. Check logs:"
echo "   tail -f $BASE_DIR/logs/sync.log"
echo ""
echo "5. Reboot to apply all changes and start slideshow:"
echo "   sudo reboot"
echo ""
echo "For help and documentation:"
echo "  - README: $PROJECT_DIR/README.md"
echo "  - Setup guide: $PROJECT_DIR/SETUP_PI.md"
echo "  - Verify setup: ./scripts/test_setup.sh"
echo ""
