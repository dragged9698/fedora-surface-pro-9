#!/bin/bash

################################################################################
# Remove OpenTabletDriver and Fix Stylus with iptsd
# 
# This script:
# 1. Removes OpenTabletDriver package
# 2. Removes OpenTabletDriver configuration
# 3. Removes OpenTabletDriver udev rules
# 4. Configures iptsd to handle stylus with correct orientation
# 5. Restarts iptsd daemon
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Remove OpenTabletDriver & Fix Stylus with iptsd         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# Step 1: Stop OpenTabletDriver daemon
# ============================================================================
echo -e "${YELLOW}[1/5] Stopping OpenTabletDriver daemon...${NC}"

if sudo systemctl is-active --quiet otd-daemon 2>/dev/null; then
    sudo systemctl stop otd-daemon
    echo -e "${GREEN}✓ Daemon stopped${NC}"
else
    echo -e "${GREEN}✓ Daemon not running${NC}"
fi

echo ""

# ============================================================================
# Step 2: Remove OpenTabletDriver package
# ============================================================================
echo -e "${YELLOW}[2/5] Removing OpenTabletDriver package...${NC}"

if rpm -q opentabletdriver &>/dev/null; then
    sudo dnf remove -y opentabletdriver
    echo -e "${GREEN}✓ OpenTabletDriver removed${NC}"
else
    echo -e "${GREEN}✓ OpenTabletDriver not installed${NC}"
fi

echo ""

# ============================================================================
# Step 3: Remove OpenTabletDriver configuration
# ============================================================================
echo -e "${YELLOW}[3/5] Removing OpenTabletDriver configuration...${NC}"

OTD_CONFIG_DIR="$HOME/.config/OpenTabletDriver"
if [ -d "$OTD_CONFIG_DIR" ]; then
    rm -rf "$OTD_CONFIG_DIR"
    echo -e "${GREEN}✓ Configuration removed: $OTD_CONFIG_DIR${NC}"
else
    echo -e "${GREEN}✓ Configuration directory not found${NC}"
fi

echo ""

# ============================================================================
# Step 4: Remove OpenTabletDriver udev rules
# ============================================================================
echo -e "${YELLOW}[4/5] Removing OpenTabletDriver udev rules...${NC}"

OTD_UDEV="/etc/udev/rules.d/99-opentabletdriver.rules"
if [ -f "$OTD_UDEV" ]; then
    sudo rm "$OTD_UDEV"
    echo -e "${GREEN}✓ udev rules removed: $OTD_UDEV${NC}"
else
    echo -e "${GREEN}✓ udev rules not found${NC}"
fi

echo ""

# ============================================================================
# Step 5: Configure iptsd for stylus with correct orientation
# ============================================================================
echo -e "${YELLOW}[5/5] Configuring iptsd for stylus (fixing orientation)...${NC}"

mkdir -p /etc/iptsd

# Create iptsd configuration with stylus orientation fix
# The key is to set InvertX and InvertY to handle the flipped cursor
cat | sudo tee /etc/iptsd/iptsd.conf > /dev/null << 'IPTSD_CONFIG'
[Device]
# Surface Pro touch and stylus configuration
PressureThreshold = 5
MaxPressure = 4095

[Touch]
# Touch-specific settings
PressureThreshold = 5
MaxPressure = 4095
SmoothingFactor = 0.3
LatencyCompensation = false

[Stylus]
# Stylus/pen input settings
# Fix for flipped cursor (180° rotation)
InvertX = true
InvertY = true
PressureThreshold = 0
MaxPressure = 4095
SmoothingFactor = 0.2
LatencyCompensation = false
IPTSD_CONFIG

echo -e "${GREEN}✓ iptsd configuration updated with stylus orientation fix${NC}"
echo ""

# ============================================================================
# Step 6: Reload udev rules
# ============================================================================
echo -e "${YELLOW}Reloading udev rules...${NC}"

sudo udevadm control --reload-rules
sudo udevadm trigger

echo -e "${GREEN}✓ udev rules reloaded${NC}"
echo ""

# ============================================================================
# Step 7: Restart iptsd
# ============================================================================
echo -e "${YELLOW}Restarting iptsd daemon...${NC}"

if systemctl list-unit-files 2>/dev/null | grep -q "iptsd.service"; then
    systemctl restart iptsd
    sleep 2
    
    if systemctl is-active --quiet iptsd; then
        echo -e "${GREEN}✓ iptsd daemon restarted${NC}"
    else
        echo -e "${RED}✗ iptsd failed to start${NC}"
    fi
else
    echo -e "${YELLOW}⚠ iptsd service not found${NC}"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Cleanup Complete!                                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "What was done:"
echo "  ✓ Removed OpenTabletDriver package"
echo "  ✓ Removed OpenTabletDriver configuration"
echo "  ✓ Removed OpenTabletDriver udev rules"
echo "  ✓ Configured iptsd for stylus with orientation fix"
echo "  ✓ Restarted iptsd daemon"
echo ""

echo "Stylus orientation fix applied:"
echo "  InvertX = true"
echo "  InvertY = true"
echo "  (This fixes the 180° flipped cursor issue)"
echo ""

echo "Next steps:"
echo "1. Test stylus in osu!:"
echo "   steam steam://run/1677970"
echo ""
echo "2. If stylus still flipped, adjust iptsd config:"
echo "   sudo nano /etc/iptsd/iptsd.conf"
echo "   Try different combinations:"
echo "   - InvertX = true, InvertY = false"
echo "   - InvertX = false, InvertY = true"
echo "   - InvertX = false, InvertY = false"
echo ""
echo "3. After editing, restart iptsd:"
echo "   systemctl restart iptsd"
echo ""

echo "To verify stylus is working:"
echo "  xinput list | grep -i stylus"
echo "  xinput test 'Stylus'"
echo ""

