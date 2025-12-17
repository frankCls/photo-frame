# Raspberry Pi Photo Frame

A smart, remote-managed digital photo frame powered by Raspberry Pi Zero 2 W with automatic Google Drive sync, intelligent image processing, and stunning Ken Burns cinematic zoom effects.

## Features

- **Automatic Cloud Sync**: Photos uploaded to Google Drive automatically appear on your frame
- **Smart Image Processing**:
  - Landscape photos: Intelligently cropped to fill the screen
  - Portrait photos: Displayed with artistic blurred backgrounds (no black bars!)
- **Cinematic Display**: GPU-accelerated Ken Burns zoom effects powered by Pi3D
- **Fully Configurable**: Adjust screen resolution, blur intensity, sync frequency, and more via simple config file
- **One-Command Installation**: Automated setup script handles everything
- **Auto-Start on Boot**: Systemd service ensures slideshow starts automatically
- **Optimized for Pi Zero 2 W**: Low-memory footprint with WiFi stability optimizations
- **Family-Friendly**: Easy for family members to share photos - just upload to Google Drive!

## Hardware Requirements

- Raspberry Pi Zero 2 W (or any Pi with WiFi)
- MicroSD card (16GB+)
- Display with HDMI (tested on 1366x768)
- Power supply (5V, 2.5A)
- Mini HDMI cable

## Quick Start

### 1. Prepare Your Raspberry Pi

If your Pi isn't set up yet, see the [detailed setup guide](SETUP_PI.md).

Quick checklist:
- ✓ Raspberry Pi OS installed (Full with desktop, OR Lite with X11 + OpenGL ES)
- ✓ WiFi configured
- ✓ SSH enabled
- ✓ Basic system updates completed
- ✓ **X11 server & OpenGL ES** (automatic on Full, run install command on Lite - see setup guide)

### 2. Clone This Repository

```bash
cd ~
git clone <YOUR_REPOSITORY_URL> photoframe
cd photoframe
```

### 3. Configure Your Display

Edit the config file to match your screen resolution:

```bash
nano photoframe_config.ini
```

Update these values:
```ini
[Display]
screen_width = 1366    # Your display width
screen_height = 768    # Your display height
```

### 4. Run the Installer

```bash
chmod +x scripts/*.sh
sudo ./scripts/install.sh
```

The installer will:
- Install system dependencies (rclone, Python packages)
- Create directory structure
- Set up automatic syncing
- Optionally help configure Google Drive access
- Generate and install systemd service for auto-start
- Optimize Pi settings

**Note on Google Drive Setup:** For headless Pi setups (no browser), it's easiest to configure rclone on your Mac/PC first, then copy the config file to the Pi. See the [detailed setup guide](SETUP_PI.md#4-configure-google-drive) for complete instructions. The installer will prompt you to configure rclone, or you can skip and do it separately.

### 5. Reboot

```bash
sudo reboot
```

After reboot, your photo frame will:
- Start the slideshow automatically
- Sync photos every 15 minutes
- Display new photos with beautiful transitions

## Architecture

### Directory Structure

```
/home/pi/
├── photoframe/                    # This repository
│   ├── src/
│   │   └── process_images.py     # Image processor
│   ├── scripts/
│   │   ├── install.sh            # Main installer
│   │   ├── sync.sh               # Sync script (runs via cron)
│   │   ├── setup_rclone.sh       # Google Drive setup helper
│   │   ├── test_setup.sh         # Verification script
│   │   └── uninstall.sh          # Clean removal
│   ├── systemd/
│   │   └── photoframe.service    # Systemd service template (auto-generated during install)
│   ├── photoframe_config.ini     # Main configuration
│   └── requirements.txt
│
└── photoframe_data/               # Created during install
    ├── raw_photos/                # Synced from Google Drive
    ├── processed_photos/          # Resized for display (Pi3D source)
    └── logs/
        └── sync.log
```

### Data Flow

```
Google Drive Folder
       ↓
   [rclone sync]
       ↓
  raw_photos/
       ↓
[Python processor]
       ↓
processed_photos/
       ↓
   [Pi3D viewer]
       ↓
    Display
```

### Systemd Service Generation

The systemd service file (`systemd/photoframe.service`) is a **template** that uses `pi` as a placeholder. During installation, `install.sh`:

1. Detects your actual username (e.g., `pi`, `john`, `photoframe`)
2. Detects your home directory path
3. Generates a customized service file via sed substitution
4. Installs it to `/etc/systemd/system/photoframe.service`

**Key substitutions:**
- `User=pi` → `User=<your-username>`
- `Group=pi` → `Group=<your-username>`
- `/home/pi` → `/home/<your-username>`

This ensures the service works with any username, not just `pi`.

### Image Processing

The Python processor (`src/process_images.py`) handles two strategies:

#### Landscape Photos (Width ≥ Height)
- Uses strict crop-to-fill strategy
- Scales and crops to exact screen dimensions
- Ideal for Ken Burns panning effects
- Ensures no black bars

#### Portrait Photos (Height > Width)
- Creates blurred background from the original image
- Scales original to fit within screen bounds
- Composites scaled photo on top of blurred background
- Prevents subject cropping while avoiding black bars

## Configuration

All settings are in `photoframe_config.ini`:

### Display Settings
```ini
[Display]
screen_width = 1366
screen_height = 768
```

### Image Processing
```ini
[ImageProcessing]
blur_radius = 40          # Blur strength for portrait backgrounds (20-60)
jpeg_quality = 90         # Output quality (1-100)
resampling = LANCZOS      # LANCZOS, BILINEAR, or BICUBIC
```

### Sync Settings
```ini
[Sync]
sync_interval = 15                        # Minutes between syncs
gdrive_remote = gdrive:PhotoFrame_Uploads # Format: remote_name:folder_path
```

**Understanding `gdrive_remote` format:**
- Format: `remote_name:folder_path`
- `remote_name` = the name you gave your rclone remote during configuration
- `folder_path` = the folder within Google Drive to sync from

**Examples:**
```ini
gdrive_remote = gdrive:PhotoFrame_Uploads    # Remote "gdrive", folder "PhotoFrame_Uploads"
gdrive_remote = mygdrive:Family/Photos       # Remote "mygdrive", folder "Family/Photos"
gdrive_remote = gdrive:                      # Remote "gdrive", root of Google Drive
```

**To find your remote name:** Run `rclone listremotes` on your Pi after configuration.

### Paths
```ini
[Paths]
base_dir = /home/pi/photoframe_data
raw_photos_dir = %(base_dir)s/raw_photos
processed_photos_dir = %(base_dir)s/processed_photos
log_file = %(base_dir)s/logs/sync.log
```

### Rclone Optimization
```ini
[RcloneOptions]
transfers = 2              # Concurrent transfers (2-4 for Pi Zero 2 W)
checkers = 2               # Concurrent checkers
low_level_retries = 10     # WiFi stability
```

## Usage

### Adding Photos

1. **Share the Google Drive folder** with family members
2. **Upload photos** to the shared folder
3. **Wait for sync** (default: every 15 minutes)
4. **Photos appear automatically** on the frame

### Manual Operations

#### Trigger Sync Manually
```bash
./scripts/sync.sh
```

#### View Sync Logs
```bash
tail -f ~/photoframe_data/logs/sync.log
```

#### Test Setup
```bash
./scripts/test_setup.sh
```

#### Reprocess All Images
```bash
cd ~/photoframe
rm -rf ~/photoframe_data/processed_photos/*
python3 src/process_images.py
```

#### Control Pi3D Service
```bash
# Start slideshow
sudo systemctl start photoframe.service

# Stop slideshow
sudo systemctl stop photoframe.service

# Check status
sudo systemctl status photoframe.service

# View logs
journalctl -u photoframe.service -f
```

### Updating Configuration

1. Edit the config file:
```bash
nano ~/photoframe/photoframe_config.ini
```

2. Changes to image processing settings require reprocessing:
```bash
python3 ~/photoframe/src/process_images.py
```

3. Changes to sync interval require updating cron:
```bash
sudo ~/photoframe/scripts/install.sh  # Re-run installer
```

## Troubleshooting

### Common Issues

#### Sync Not Working
- Check internet: `ping google.com`
- Test rclone: `rclone lsd gdrive:`
- View logs: `tail -50 ~/photoframe_data/logs/sync.log`
- Verify cron: `crontab -l`

#### Display Issues
- Check GPU memory: `vcgencmd get_mem gpu` (should be 128M)
- Verify resolution in `/boot/firmware/config.txt`
- Verify Pi3D is installed: `pip show pi3d` (activate venv first if using Method 1/2)
- Test Pi3D manually (requires display attached, won't work over SSH): `cd ~/pi3d_demos && python3 PictureFrame2020.py ~/photoframe_data/processed_photos`

#### WiFi Disconnections
- Check power save: `iw dev wlan0 get power_save` (should be "off")
- View WiFi logs: `journalctl -u wpa_supplicant -f`

#### Images Not Processing
- Check Python: `python3 --version`
- Test Pillow: `python3 -c "import PIL; print(PIL.__version__)"`
- Run manually: `python3 ~/photoframe/src/process_images.py`
- Check logs: `~/photoframe_data/logs/sync.log`

### Getting Help

1. **Run verification script**: `./scripts/test_setup.sh`
2. **Check all logs**: See [Usage](#usage) section
3. **Review documentation**: See [SETUP_PI.md](SETUP_PI.md) for detailed Pi setup
4. **Open an issue**: Include logs and system info

## Advanced Usage

### Custom Display Resolution

For screens other than 1366x768:

1. Edit `photoframe_config.ini`:
```ini
[Display]
screen_width = 1920
screen_height = 1080
```

2. Update display settings in `/boot/config.txt`:
```bash
sudo nano /boot/config.txt
```

3. Reprocess images:
```bash
rm -rf ~/photoframe_data/processed_photos/*
python3 ~/photoframe/src/process_images.py
```

### Multiple Photo Frames

You can run multiple photo frames with different configurations:

1. Clone multiple configs:
```bash
cp photoframe_config.ini photoframe_config_bedroom.ini
```

2. Modify the copy for different settings

3. Run with specific config:
```bash
python3 src/process_images.py photoframe_config_bedroom.ini
```

### Selective Syncing

Use rclone filters to sync only specific folders or file types:

Edit `scripts/sync.sh` and add rclone filters:
```bash
rclone sync "$GDRIVE_REMOTE" "$RAW_DIR" \
  --include "*.jpg" \
  --include "*.jpeg" \
  --include "*.png" \
  --exclude "thumbnails/**" \
  ...
```

## Performance Optimization

The system is optimized for Raspberry Pi Zero 2 W's limited resources:

### Memory Management
- Concurrent transfers limited to 2
- Concurrent checkers limited to 2
- Pillow processes images one at a time
- Pi3D uses GPU acceleration (minimal RAM)

### Network Stability
- WiFi power management disabled
- Low-level retries set to 10
- Sync errors logged but don't stop processing

### Display Performance
- GPU memory allocated: 128MB
- Images pre-sized to exact display dimensions
- JPEG optimization enabled

## Uninstalling

To remove the photo frame:

```bash
sudo ./scripts/uninstall.sh
```

This will:
- Remove cron job
- Stop and remove systemd service
- Clean up lock files
- Optionally remove photos and rclone config

To completely remove everything:
```bash
cd ~
rm -rf photoframe photoframe_data
```

## Technical Details

### Dependencies

**System packages:**
- python3 (≥3.7)
- python3-pip
- rclone
- pi3d

**Python packages:**
- Pillow (≥10.0.0)

### System Modifications

The installer makes these changes to your Pi:

1. **Cron job**: Adds sync script to user's crontab
2. **Systemd service**: Dynamically generates and installs `/etc/systemd/system/photoframe.service` with your actual username and paths
3. **WiFi config**: Disables power management via systemd service
4. **GPU memory**: Sets `gpu_mem=128` in `/boot/config.txt`
5. **Directories**: Creates `~/photoframe_data/` structure

All changes can be reverted with the uninstall script.

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test on actual Raspberry Pi hardware
4. Submit a pull request

## License

[Your License Here]

## Acknowledgments

- **Pi3D**: GPU-accelerated OpenGL rendering for Raspberry Pi
- **rclone**: Robust cloud storage sync
- **Pillow**: Python imaging library

## Support

- Documentation: See [SETUP_PI.md](SETUP_PI.md)
- Issues: GitHub Issues
- Discussions: GitHub Discussions

---

**Enjoy your smart photo frame!**
