# **🖼️ Raspberry Pi Photo Frame: Technical Project Brief**

This document outlines the complete architecture and required Python logic for the remote-managed digital photo frame project.

## **1\. ⚙️ Project Constraints and Architecture**

The solution prioritizes performance and aesthetics, balancing the limited resources of the Raspberry Pi Zero 2 W with the desire for smooth visual effects.

| Component | Tool / Language | Rationale / Specification |
| :---- | :---- | :---- |
| **Hardware** | Raspberry Pi Zero 2 W | Resource constraint (512MB RAM) requires lightweight solutions. |
| **Screen Resolution** | **1366 x 768** (16:9 Aspect Ratio) | All final images must be processed to this exact size. |
| **Upload Source** | Google Drive Shared Folder | Remote contribution mechanism (simple for family). |
| **Synchronization** | **rclone** (via Cron job) | Automated, reliable, low-resource cloud syncing utility. |
| **Preprocessing** | **Python (Pillow Library)** | Handles image resizing, cropping, and the advanced aesthetic composition. |
| **Display Viewer** | **Pi3D PictureFrame** | GPU-accelerated application for smooth **Ken Burns (Cinematic Zoom)** transitions. |

## **2\. 🗂️ Required Directory Structure and Files**

All custom scripts and storage folders should reside in the user's home directory (e.g., /home/pi/ or any user's home) for simplicity and user permissions. The installation is flexible and adapts to any username.

/home/pi/  
├── photoframe\_scripts/  
│   ├── sync.sh            \# Automation script (rclone & python runner)  
│   └── process\_images.py  \# Python Image Preprocessing Logic  
├── raw\_photos/            \# rclone sync target (source for process\_images.py)  
└── processed\_photos/      \# Pi3D source folder (contains perfect 1366x768 images)

## **3\. 🐍 Python Preprocessing Script (process\_images.py)**

This Python script uses the **Pillow** library to perform the necessary aesthetic transformations. Its primary goal is to produce perfectly sized $1366 \\times 768$ images for Pi3D.

### **Constants**

\# Target screen resolution  
SCREEN\_W, SCREEN\_H \= 1366, 768  
OUTPUT\_SIZE \= (SCREEN\_W, SCREEN\_H)

\# Directories  
RAW\_DIR \= Path("/home/pi/raw\_photos")  
PROCESSED\_DIR \= Path("/home/pi/processed\_photos")

### **Core Logic: process\_image(raw\_path: Path)**

The function must implement two distinct handling paths:

#### **A. Landscape Photos (Width $\\geq$ Height)**

Strategy: **Strict Cover/Crop**. The image must fill the entire screen area without black bars, which is ideal for the Ken Burns effect.

* **Pillow Tool:** Use ImageOps.fit(img, OUTPUT\_SIZE, Image.Resampling.LANCZOS) to scale and crop the source image to the exact $1366 \\times 768$ dimensions.

#### **B. Portrait Photos (Height $\>$ Width)**

Strategy: **Combined Blur Background**. This avoids cropping the main subject and eliminates black bars aesthetically.

1. **Create Blurred Background:**
   * Duplicate the original portrait image.
   * Apply ImageFilter.GaussianBlur(radius=40) to the copy.
   * Use ImageOps.fit to crop this blurred image to $1366 \\times 768$. This becomes the background.
2. **Scale Original Photo:**
   * Scale the original, un-blurred image down using img.thumbnail to fit the screen's **height** ($768$px) while maintaining aspect ratio.
3. **Composite:**
   * Create a blank $1366 \\times 768$ canvas.
   * Paste the blurred background onto the canvas.
   * Paste the scaled, un-blurred original photo perfectly centered on top of the blurred background.

## **4\. 🗄️ Automation Script (sync.sh) with Zero 2 W Optimization**

This script incorporates performance tweaks for the Pi Zero 2 W's limited 512MB of RAM and reliance on Wi-Fi.

**File Contents (to be saved as /home/pi/photoframe\_scripts/sync.sh)**

\#\!/bin/bash

\# Prevents the script from running multiple times concurrently  
if pidof \-o %PPID \-x "$0"; then  
exit 1  
fi

LOG\_FILE="/var/log/photoframe\_sync.log"  
\# NOTE: Replace 'gdrive:PhotoFrame\_Uploads' with your actual Rclone remote name and folder path.  
GDRIVE\_REMOTE="gdrive:PhotoFrame\_Uploads"   
LOCAL\_RAW\_DIR="/home/pi/raw\_photos"

echo "--- $(date) \---" \>\> "$LOG\_FILE"

\# 1\. Synchronize: Optimized for low-memory RPi Zero 2 W  
\# \--transfers 2: Limits concurrent downloads to reduce RAM/CPU spikes.  
\# \--checkers 2: Limits file comparison processes to reduce memory overhead.  
\# \--low-level-retries 10: Handles Wi-Fi stability issues.  
rclone sync "$GDRIVE\_REMOTE" "$LOCAL\_RAW\_DIR" \\  
\--ignore-errors \\  
\--transfers 2 \\  
\--checkers 2 \\  
\--low-level-retries 10 \\  
\--delete-excluded \\  
\--log-file="$LOG\_FILE"

if \[ $? \-eq 0 \]; then  
echo "Rclone Sync successful. Starting preprocessing." \>\> "$LOG\_FILE"  
\# 2\. Preprocess: Trigger the Python script  
python3 /home/pi/photoframe\_scripts/process\_images.py \>\> "$LOG\_FILE" 2\>&1  
else  
echo "Rclone Sync FAILED. Check network connection." \>\> "$LOG\_FILE"  
fi

### **CRON Job (Scheduling)**

The crontab \-e entry to run the script every **15 minutes**:

\# Run the sync script every 15 minutes (adapts to actual username)
\*/15 \* \* \* \* /home/pi/photoframe\_scripts/sync.sh

## **5\. 🖼️ Pi3D Configuration**

After installing Pi3D PictureFrame, edit its configuration file (often configuration.yaml or a .py file) to match the following settings:

| Pi3D Setting | Value | Purpose |
| :---- | :---- | :---- |
| pictures\_dir | /home/pi/processed\_photos | Source folder for the slideshow. |
| kenburns | True | **Enables the desired Cinematic Zoom effect.** |
| fit | False | Assumes input images are already screen-sized (1366x768). |
| display\_w | 1366 | Sets the display width. |
| display\_h | 768 | Sets the display height. |

## **💡 Critical OS Optimization for Raspberry Pi Zero 2 W**

To ensure stability and performance, especially regarding Wi-Fi reliability during large file transfers, perform these steps on the Raspberry Pi command line:

1. **Disable Wi-Fi Power Management:** This prevents the Wi-Fi chip from aggressively saving power and dropping connections during intensive syncs.  
   \# Command to check current status:  
   \# iw dev wlan0 get power\_save

   \# Command to permanently disable power saving:  
   sudo nano /etc/network/interfaces  
   \# Add the line "wireless-power off" under the wlan0 section if it exists, or create a file:  
   \# /etc/default/crda and add "IWREGQ=0"

   \# Alternatively, ensure the following command runs on every boot:  
   sudo iw dev wlan0 set power\_save off

2. **Increase GPU Memory Split:** Pi3D uses the GPU for OpenGL acceleration. Ensure the GPU has sufficient memory (at least **128MB**) to handle the $1366 \\times 768$ textures smoothly.  
   sudo raspi-config  
   \# Navigate to: Performance Options \-\> GPU Memory \-\> Set to 128  