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
- **D1 Resolution**: Set to your display's native resolution (e.g., 1366x768)
- **D2 Underscan**: Disable if you see black borders
- **D5 VNC Resolution**: (optional, if you want remote desktop)

#### Localisation Options (Option 5)
- **L1 Locale**: Set your language (e.g., en_US.UTF-8)
- **L2 Timezone**: Set your timezone
- **L3 Keyboard**: Set keyboard layout
- **L4 WLAN Country**: Set WiFi country code

#### Performance Options (Option 4)
- **P2 GPU Memory**: Set to **128MB** (important for Pi3D performance)

#### Interface Options (Option 3)
- **P2 SSH**: Enable (if not already enabled)

**Select "Finish"** and **Reboot** when prompted.

### 3. Install Git

```bash
sudo apt install -y git
```

### 4. Set Up Time Synchronization (Recommended)

```bash
sudo apt install -y ntp
sudo systemctl enable ntp
sudo systemctl start ntp
```

---

## Display Configuration

### For 1366x768 Display

If your display is not automatically detected:

1. **Edit config.txt**:
```bash
sudo nano /boot/config.txt
# or on newer Pi OS:
sudo nano /boot/firmware/config.txt
```

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

### Option 1: Install from Package (Recommended)

```bash
sudo apt install -y python3-pi3d
```

### Option 2: Install from Source

```bash
pip3 install pi3d
```

### Install Pi3D PictureFrame

```bash
cd ~
git clone https://github.com/pi3d/pi3d_demos.git
cd pi3d_demos
python3 PictureFrame2020.py --help
```

### Test Pi3D

Create a test script to verify Pi3D works:

```bash
mkdir -p ~/test_photos
# Add some test images to ~/test_photos
```

Run the viewer:
```bash
cd ~/pi3d_demos
python3 PictureFrame2020.py ~/test_photos
```

Press **Escape** to exit.

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

If not done during installation:

```bash
./scripts/setup_rclone.sh
```

This will guide you through:
1. Google Drive authentication
2. Selecting/creating the upload folder
3. Testing the connection

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
