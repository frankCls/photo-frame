#!/bin/bash
#
# Add WiFi Network to Photo Frame
# Configures WiFi for networks not currently in range
# Useful for pre-configuring before moving Pi to different location
#

set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo $0"
    exit 1
fi

echo "=============================================="
echo "  Photo Frame - Add WiFi Network"
echo "=============================================="
echo ""
echo "This will add a WiFi network that is NOT currently in range."
echo "The Pi will automatically connect when moved to that location."
echo ""

# Get WiFi credentials
read -p "WiFi Network Name (SSID): " SSID
read -sp "WiFi Password: " PASSWORD
echo ""

# Validate inputs
if [ -z "$SSID" ] || [ -z "$PASSWORD" ]; then
    echo "Error: SSID and password cannot be empty"
    exit 1
fi

# Add network using nmcli (creates profile without trying to connect)
echo ""
echo "Adding WiFi network '$SSID'..."

if nmcli con add type wifi \
    ifname wlan0 \
    con-name "$SSID" \
    ssid "$SSID" \
    wifi-sec.key-mgmt wpa-psk \
    wifi-sec.psk "$PASSWORD"; then

    # Ensure auto-connect is enabled
    nmcli con modify "$SSID" connection.autoconnect yes

    echo "✓ WiFi network added successfully"
    echo ""
    echo "The photo frame will now automatically connect to:"
    nmcli con show | grep wifi | awk '{print "  - " $1}'
    echo ""
    echo "Note: Connection will activate when the Pi is moved to that location."
else
    echo "✗ Failed to add network"
    exit 1
fi

echo ""
echo "Verification:"
nmcli con show "$SSID" | grep -E "connection.id|connection.autoconnect|802-11-wireless.ssid"
echo ""
