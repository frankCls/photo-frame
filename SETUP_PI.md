# Raspberry Pi Initial Setup Guide

This guide covers setting up your Raspberry Pi from scratch for the photo frame project. If your Pi is already set up and running, you can skip to the [Photo Frame Installation](#photo-frame-installation) section.

## Table of Contents

1. [Hardware Requirements](#hardware-requirements)
2. [Installing Raspberry Pi OS](#installing-raspberry-pi-os)
3. [First Boot & Initial Configuration](#first-boot--initial-configuration)
4. [Connecting to Your Pi](#connecting-to-your-pi)
5. [System Configuration](#system-configuration)
6. [Display Configuration](#display-configuration)
7. [Installing Pi3D](#installing-pi3d)
8. [Photo Frame Installation](#photo-frame-installation)

---

## Hardware Requirements

- **Raspberry Pi Zero 2 W** (or any Raspberry Pi with WiFi)
- **MicroSD card** (16GB or larger, Class 10 recommended)
- **Display** with HDMI input (1366x768 or any 16:9 aspect ratio)
- **Power supply** (5V, 2.5A recommended)
- **Mini HDMI to HDMI cable** (for Pi Zero 2 W)
- **Computer** with SD card reader (for initial setup)

---

## Installing Raspberry Pi OS

### Method 1: Using Raspberry Pi Imager (Recommended)

This is the easiest method and allows you to pre-configure WiFi and SSH.

1. **Download Raspberry Pi Imager**
   - Visit: https://www.raspberrypi.com/software/
   - Download for Windows, macOS, or Linux

2. **Launch Raspberry Pi Imager**

3. **Choose OS**
   - Click "Choose OS"
   - Select: **Raspberry Pi OS (64-bit)** or **Raspberry Pi OS Lite (64-bit)**
   - The latest version is based on Debian 13 "Trixie" (October 2025)
   - **Lite** is recommended for photo frames (no desktop GUI, less resource usage)
   - **Full** is easier if you want to use a keyboard/mouse/monitor directly

4. **Choose Storage**
   - Insert your microSD card
   - Click "Choose Storage"
   - Select your SD card

5. **Configure Settings** (Click the gear icon ⚙️)
   - **Set hostname**: `photoframe` (or your preference)
   - **Enable SSH**: ✓ Use password authentication
   - **Set username and password**:
     - Username: `pi` (or your preference)
     - Password: (choose a secure password)
   - **Configure wireless LAN**:
     - SSID: (your WiFi network name)
     - Password: (your WiFi password)
     - Country: (your country code, e.g., US, GB, NL)
   - **Set locale settings**:
     - Timezone: (your timezone)
     - Keyboard layout: (your keyboard layout)

6. **Write to SD Card**
   - Click "Write"
   - Confirm (this will erase everything on the SD card)
   - Wait for the process to complete (5-10 minutes)

7. **Eject SD card and insert into Raspberry Pi**

### Method 2: Manual Setup (Headless)

If you can't use Raspberry Pi Imager, you can manually enable SSH and WiFi:

1. **Flash Raspberry Pi OS** using any SD card writing tool
2. **Enable SSH**: Create an empty file named `ssh` (no extension) in the boot partition
3. **Configure WiFi**: Create a file named `wpa_supplicant.conf` in the boot partition:

```
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="YOUR_WIFI_NAME"
    psk="YOUR_WIFI_PASSWORD"
    key_mgmt=WPA-PSK
}
```

---

## First Boot & Initial Configuration

1. **Insert SD card** into Raspberry Pi
2. **Connect display** via HDMI
3. **Power on** the Pi
4. **Wait for boot** (first boot takes 2-3 minutes)

If using **Raspberry Pi OS Full** with desktop:
- You'll see the desktop interface
- Follow on-screen setup wizard

If using **Raspberry Pi OS Lite**:
- You'll see a login prompt
- Login with username/password you set earlier

---

## Connecting to Your Pi

### Finding Your Pi's IP Address

**Method 1: From your router**
- Access your router's admin page
- Look for connected devices
- Find device named "photoframe" (or whatever hostname you set)

**Method 2: Using network scanner**
- Windows: Use Advanced IP Scanner
- macOS/Linux: Use `nmap` or `arp-scan`
```bash
# macOS/Linux
arp -a | grep -i "b8:27:eb\|dc:a6:32\|e4:5f:01"
```

**Method 3: Connect monitor and keyboard**
- Login to the Pi
- Run: `hostname -I`

### Connecting via SSH

**From macOS/Linux:**
```bash
ssh pi@photoframe.local
# or
ssh pi@<IP_ADDRESS>
```

**From Windows:**
- Use PuTTY or Windows Terminal
- Host: `photoframe.local` or the IP address
- Port: 22
- Username: `pi`
- Password: (your password)

**First connection:**
- You'll see a security warning about host authenticity
- Type `yes` to continue
- Enter your password

---

## System Configuration

> **Note:** This guide is updated for Raspberry Pi OS "Trixie" (Debian 13), released October 2025. If you're using an older version (Bookworm or earlier), some menu options and file locations may differ.

Once connected via SSH (or using the Pi directly), run these essential setup steps:

### 1. Update System

```bash
sudo apt update
sudo apt upgrade -y
```

This may take 10-30 minutes depending on your Pi and internet speed.

### 2. Run Raspberry Pi Configuration Tool

```bash
sudo raspi-config
```

Navigate through these options:

#### System Options (Option 1)
- **S1 Wireless LAN**: Configure WiFi (if not done in Imager)
- **S3 Password**: Change password if needed
- **S4 Hostname**: Set to `photoframe`

#### Display Options (Option 2)
- **D2 Underscan**: Adjust if you see black borders on the screen edges
- **D3 Screen Blanking**: Enable or disable screen blanking (disable for photo frame)
- **D5 VNC Resolution**: (optional, if you want remote desktop access)

#### Localisation Options (Option 5)
- **L1 Locale**: Set your language (e.g., en_US.UTF-8)
- **L2 Timezone**: Set your timezone
- **L3 Keyboard**: Set keyboard layout
- **L4 WLAN Country**: Set WiFi country code

#### Performance Options (Option 4)
- **GPU Memory**: Set to **128MB** (important for Pi3D performance)
  - Note: On Pi 4 and Pi 5, GPU memory is managed automatically

#### Interface Options (Option 3)
- **I2 SSH**: Enable (if not already enabled)

#### Advanced Options (Option 6)
- **A9 Wayland**: If you experience graphics issues with the photo frame, you can switch from Wayland (default) to X11 here
  - Wayland is the default on Pi 4 and Pi 5
  - X11 may provide better compatibility with older software

**Select "Finish"** and **Reboot** when prompted.

### 3. Install Git

```bash
sudo apt install -y git
```

### 4. Verify Time Synchronization (Built-in)

Raspberry Pi OS Trixie uses `systemd-timesyncd` for automatic time synchronization, which is already enabled by default. You can verify it's working:

```bash
timedatectl status
```

You should see `System clock synchronized: yes` and `NTP service: active`.

**Optional: Configure Custom NTP Servers**

If you need to use specific NTP servers (e.g., local time servers), edit the configuration:

```bash
sudo nano /etc/systemd/timesyncd.conf
```

Add or uncomment these lines:
```ini
[Time]
NTP=pool.ntp.org
FallbackNTP=time.nist.gov
```

Apply changes:
```bash
sudo systemctl restart systemd-timesyncd
timedatectl show-timesync --all
```

**Note:** Installing separate NTP packages like `ntp` or `chrony` is unnecessary unless you need advanced NTP features. They will automatically remove `systemd-timesyncd`.

---

## Display Configuration

### For 1366x768 Display

If your display is not automatically detected:

1. **Edit config.txt**:
```bash
sudo nano /boot/firmware/config.txt
```

**Note:** Since Raspberry Pi OS Bookworm (2023), the configuration file has moved to `/boot/firmware/config.txt`. The old `/boot/config.txt` location contains a warning message directing you to the new location.

2. **Add/uncomment these lines**:
```ini
# Force specific resolution
hdmi_group=2
hdmi_mode=39
hdmi_drive=2

# Disable overscan if you see black borders
disable_overscan=1

# GPU memory for Pi3D
gpu_mem=128
```

**Common HDMI modes for 16:9 displays:**
- Mode 39: 1366x768 @ 60Hz
- Mode 16: 1024x768 @ 60Hz
- Mode 82: 1920x1080 @ 60Hz

3. **Save and reboot**:
```bash
sudo reboot
```

**Note on Auto-Detection:**
Raspberry Pi OS Trixie has improved HDMI auto-detection. Manual HDMI configuration is usually only needed if:
- Your display doesn't report its capabilities correctly
- You're using a non-standard display
- You need to force a specific resolution

For most modern displays, auto-detection works correctly and no manual configuration is needed.

### For Other Display Resolutions

If you have a different display resolution, you'll need to:

1. Find your HDMI mode:
```bash
tvservice -m CEA
tvservice -m DMT
```

2. Update `/boot/config.txt` with the appropriate `hdmi_group` and `hdmi_mode`

3. Update `photoframe_config.ini` later to match your resolution

---

## Installing Pi3D

Pi3D is the GPU-accelerated slideshow application that displays your photos.

> **Note for Raspberry Pi OS Trixie (2025):** Pi3D is not available as a system package (apt). Since Trixie uses Python 3.13 with PEP 668 protection, you must use either `uv` (recommended - fast and modern), a virtual environment, or the `--break-system-packages` flag when installing via pip.

### Prerequisites

First, install system dependencies:

```bash
sudo apt install -y python3-dev python3-setuptools python3-numpy \
                     libjpeg-dev zlib1g-dev libfreetype6-dev
```

### Installation Methods

Pi3D must be installed via pip (it's not available as an apt package). Choose one method:

#### Method 1: Using uv (Recommended - Fast & Modern)

`uv` is a fast Python package manager that's ideal for Raspberry Pi. It handles virtual environments automatically and is much faster than pip.

**Install uv:**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
# Restart your shell or run: source $HOME/.local/bin/env
```

**Install Pi3D with uv:**
```bash
# Create project with virtual environment and install pi3d
cd ~
uv venv photoframe_env
source photoframe_env/bin/activate
uv pip install pi3d

# Download pi3d demos/PictureFrame
git clone https://github.com/pi3d/pi3d_demos.git
```

**Note:** Activate the environment before running Pi3D: `source ~/photoframe_env/bin/activate`

#### Method 2: Traditional Virtual Environment

Best practice with standard Python tools:

```bash
# Create virtual environment
python3 -m venv ~/venv_photoframe
source ~/venv_photoframe/bin/activate

# Install pi3d
pip install pi3d

# Download pi3d demos/PictureFrame
cd ~
git clone https://github.com/pi3d/pi3d_demos.git
```

**Note:** Activate the environment before running Pi3D: `source ~/venv_photoframe/bin/activate`

#### Method 3: System-wide Installation (Not Recommended)

For simpler setup without virtual environments (bypasses Python protection):

```bash
pip3 install --break-system-packages pi3d
```

**Warning:** This bypasses Python's package protection. Only use this if you understand the implications.

### Download Pi3D PictureFrame

Regardless of installation method, you need the PictureFrame demo:

```bash
cd ~
git clone https://github.com/pi3d/pi3d_demos.git
```

### Verify Pi3D Installation

Pi3D automatically initializes GPU access when imported, which requires a fully configured display system. During initial setup, use `pip show` to verify installation without requiring GPU access.

**If you used Method 1 (uv) or Method 2 (venv):**
First activate your virtual environment, then verify:

```bash
# For Method 1 (uv):
source ~/photoframe_env/bin/activate

# For Method 2 (venv):
# source ~/venv_photoframe/bin/activate

# Verify installation:
pip show pi3d
```

**If you used Method 3 (system-wide):**
```bash
pip3 show pi3d
```

You should see output like:
```
Name: pi3d
Version: 2.55 (or similar)
Location: .../site-packages
```

If you see this information, Pi3D is installed correctly.

**Note:** You cannot import or run Pi3D during setup without X11 - it requires both GPU access AND a display server (X11/Wayland). On Raspberry Pi OS Lite, install X11 with `sudo apt install xinit xserver-xorg` before testing Pi3D (see "Configuring Graphics for Pi3D" section below). This is normal and expected behavior.

**On the Pi Console/Display:** To actually test the slideshow, you need to:

1. Connect a monitor and keyboard to your Pi, OR
2. Wait until the photoframe service auto-starts on boot

### Test Pi3D (Console/Display Only)

If you're logged in directly on the Pi with a display attached:

```bash
# Create test directory with photos
mkdir -p ~/test_photos
# Add some test images to ~/test_photos

# Run the slideshow
cd ~/pi3d_demos
python3 PictureFrame2020.py ~/test_photos
```

Press **Escape** to exit.

**Troubleshooting:**
- **AttributeError: 'NoneType' object has no attribute 'glActiveTexture'**: This means Pi3D is trying to access the GPU but the display/graphics system isn't fully initialized. This is expected during setup (both over SSH and on console) - use `pip show pi3d` to verify installation instead of importing. Pi3D will work automatically when the systemd service starts
- If you used a virtual environment, make sure it's activated first: `source ~/photoframe_env/bin/activate` or `source ~/venv_photoframe/bin/activate`
- On Wayland (default for Pi 4/5), you may need to switch to X11 via raspi-config Advanced Options
- Ensure GPU memory is set to 128MB in Performance Options

---

## Configuring Graphics for Pi3D (Raspberry Pi OS Lite Only)

> **Note:** If you're using Raspberry Pi OS Full (with desktop), skip this section - X11/Wayland and OpenGL ES are already installed.

Pi3D requires both an X11 server AND OpenGL ES libraries to access the GPU. On Raspberry Pi OS Lite, you need to install:

### Install X11 Server and OpenGL ES Libraries

```bash
sudo apt install -y xinit xserver-xorg libgles2
```

This installs (~500MB total):
- **xinit**: X11 initialization tool
- **xserver-xorg**: X11 display server
- **libgles2**: OpenGL ES 2.0 libraries (EGL packages are included as dependencies)

### Test X11 Installation

Verify X11 works:

```bash
# Test Pi3D with X11 (using venv Python)
sudo xinit ~/photoframe_env/bin/python3 -c "import pi3d; print('Pi3D loaded successfully')" -- :0

# If you used Method 2 (venv), replace ~/photoframe_env with ~/venv_photoframe
# If you used Method 3 (system-wide), use /usr/bin/python3 instead
```

If this prints "Pi3D loaded successfully" and exits cleanly, X11 is working correctly with Pi3D.

### Why X11 AND OpenGL ES are Needed

Pi3D version 4+ (including 2.55) requires:
1. **X11/Wayland**: Display server to create window/drawing surfaces
2. **OpenGL ES libraries**: GPU rendering capabilities (libgles2)

The modern Mesa graphics driver needs both components to create OpenGL contexts. This is true even with KMS (`vc4-kms-v3d`) enabled.

**Historical note:** Older Pi3D versions (v1-3) could run on console with the legacy Broadcom driver, but this no longer works on Pi 4/5 with the modern KMS driver.

---

## Photo Frame Installation

Now that your Pi is fully set up, you can install the photo frame software!

> **Note:** The installer automatically adapts to your system by detecting your username and home directory. All paths and service configurations will be customized for your user account, whether you're using the default `pi` user or a custom username.

### 1. Clone the Photo Frame Repository

```bash
cd ~
git clone <YOUR_REPOSITORY_URL> photoframe
cd photoframe
```

If you don't have git hosting yet, you can copy files manually via SCP or USB.

### 2. Configure Display Settings

Edit the configuration file to match your display:

```bash
nano photoframe_config.ini
```

Update these values:
```ini
[Display]
screen_width = 1366    # Your display width
screen_height = 768    # Your display height
```

**Save**: Press `Ctrl+X`, then `Y`, then `Enter`

### 3. Run the Installer

```bash
sudo ./scripts/install.sh
```

The installer will:
- Install all dependencies (rclone, Python packages)
- Create directory structure
- Set up automatic syncing (cron job)
- Generate and configure Pi3D auto-start service (systemd)
- Optimize Pi settings for performance
- Run verification tests

Follow the on-screen prompts.

### 4. Configure Google Drive

**Recommended Method: Configure on Your Computer First**

Since the Pi is headless (no browser), the easiest way is to configure rclone on your local computer, then copy the config to the Pi:

**On Your Mac/PC:**

```bash
# Install rclone (Mac)
brew install rclone

# Or download from https://rclone.org/downloads/ for Windows/Linux

# Configure Google Drive
rclone config
```

Follow the prompts:
- Choose **n** (new remote)
- Name: **gdrive**
- Storage: Type number for **drive** (Google Drive)
- Client ID: Press **Enter** (leave blank)
- Client Secret: Press **Enter** (leave blank)
- Scope: Type **1** (full access)
- Root folder ID: Press **Enter**
- Service Account: Press **Enter**
- Edit advanced config: **n**
- Use auto config: **y** (browser will open)
- Authorize rclone in browser
- Configure as team drive: **n**
- Confirm: **y**
- Quit: **q**

```bash
# Verify it works
rclone lsd gdrive:

# Find config location
rclone config file
# Shows path like: /Users/yourname/.config/rclone/rclone.conf

# Copy to Pi (replace <pi-ip> with your Pi's IP address)
scp ~/.config/rclone/rclone.conf pi@<pi-ip>:~/.config/rclone/
```

**On Your Pi:**

```bash
# Verify connection works
rclone lsd gdrive:

# Run setup script to configure the folder
./scripts/setup_rclone.sh
```

The script will detect the existing remote and help you set up the upload folder.

**Understanding the Configuration:**

After setup, `photoframe_config.ini` will contain:
```ini
gdrive_remote = gdrive:PhotoFrame_Uploads
```

**Format:** `remote_name:folder_path`
- `remote_name` = the name you chose during `rclone config` (e.g., "gdrive")
- `folder_path` = the Google Drive folder to sync from (e.g., "PhotoFrame_Uploads")

**Examples:**
```ini
gdrive_remote = gdrive:PhotoFrame_Uploads    # Remote "gdrive", folder "PhotoFrame_Uploads"
gdrive_remote = mygdrive:Family/Photos       # Remote "mygdrive", nested folder
gdrive_remote = gdrive:                      # Remote "gdrive", root of Drive
```

**To check your remote name:** `rclone listremotes`

**Alternative: Configure Directly on Pi (Advanced)**

If you prefer to configure on the Pi itself, run `./scripts/setup_rclone.sh` and follow the headless authentication instructions provided by the script.

### 5. Test Everything

Run the verification script:

```bash
./scripts/test_setup.sh
```

This checks that all components are properly configured.

### 6. Test Manual Sync

```bash
./scripts/sync.sh
```

Check the logs:
```bash
tail -f ~/photoframe_data/logs/sync.log
```

### 7. Reboot

```bash
sudo reboot
```

After reboot:
- Photos will sync every 15 minutes (configurable)
- The slideshow will start automatically
- Everything runs in the background

---

## Troubleshooting

### WiFi Disconnection Issues

If WiFi disconnects frequently:

```bash
# Check power management
iw dev wlan0 get power_save

# Should show "Power save: off"
# If not, the installer should have fixed this
# You can manually disable it:
sudo iw dev wlan0 set power_save off
```

### Display Not Working

1. Check HDMI connections
2. Verify `hdmi_group` and `hdmi_mode` in `/boot/config.txt`
3. Try safe mode:
```bash
sudo nano /boot/config.txt
# Add: hdmi_safe=1
```

### SSH Connection Refused

1. Verify SSH is enabled: `sudo systemctl status ssh`
2. Enable SSH: `sudo systemctl enable ssh && sudo systemctl start ssh`
3. Check firewall (usually not an issue on default Pi OS)

### Pi3D Not Starting

1. Check logs: `journalctl -u photoframe.service -f`
2. Verify GPU memory: `vcgencmd get_mem gpu` (should show 128M)
3. Test manually:
```bash
cd ~/pi3d_demos
python3 PictureFrame2020.py ~/photoframe_data/processed_photos
```

### Sync Not Working

1. Check rclone config: `rclone listremotes`
2. Test connection: `rclone lsd gdrive:`
3. Check cron: `crontab -l`
4. View logs: `tail -50 ~/photoframe_data/logs/sync.log`

---

## Maintenance

### Updating Photo Frame Software

```bash
cd ~/photoframe
git pull
sudo ./scripts/install.sh  # Re-run installer if needed
```

### Viewing Logs

```bash
# Sync logs
tail -f ~/photoframe_data/logs/sync.log

# Pi3D logs
journalctl -u photoframe.service -f

# System logs
journalctl -xe
```

### Changing Configuration

```bash
nano ~/photoframe/photoframe_config.ini
# Make changes
# No need to restart, changes apply on next sync
```

### Manual Photo Processing

```bash
cd ~/photoframe
python3 src/process_images.py
```

---

## Advanced Configuration

### Custom Sync Interval

Edit `photoframe_config.ini`:
```ini
[Sync]
sync_interval = 30  # Sync every 30 minutes instead of 15
```

Then update cron:
```bash
sudo ./scripts/install.sh  # Re-run to update cron
```

### Custom Display Resolution

For non-standard displays:

1. Edit `photoframe_config.ini`:
```ini
[Display]
screen_width = 1920
screen_height = 1080
```

2. Re-process existing images:
```bash
cd ~/photoframe
rm -rf ~/photoframe_data/processed_photos/*
python3 src/process_images.py
```

### Disable Auto-Start

```bash
sudo systemctl disable photoframe.service
sudo systemctl stop photoframe.service
```

### Re-enable Auto-Start

```bash
sudo systemctl enable photoframe.service
sudo systemctl start photoframe.service
```

---

## Getting Help

- **Check logs**: Always start by checking the logs
- **Run verification**: `./scripts/test_setup.sh`
- **GitHub Issues**: Report bugs or ask questions on the repository
- **Raspberry Pi Forums**: https://forums.raspberrypi.com/

---

## Next Steps

Your photo frame is now ready!

1. **Share the Google Drive folder** with family members
2. **Upload some photos** to test
3. **Enjoy your smart photo frame!**

Photos will automatically sync and display with beautiful Ken Burns effects!
