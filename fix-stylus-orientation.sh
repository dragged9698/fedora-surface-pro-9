#!/bin/bash

################################################################################
# Fix Stylus Orientation (Flipped/Inverted)
# 
# This script fixes stylus orientation issues where the cursor appears
# in the opposite position from where the stylus is on the screen.
# 
# Common issues:
# - Stylus on bottom right → cursor on top left (180° rotation)
# - Stylus on right → cursor on left (horizontal flip)
# - Stylus on bottom → cursor on top (vertical flip)
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Fix Stylus Orientation (Flipped/Inverted)               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

OTD_CONFIG="$HOME/.config/OpenTabletDriver/settings.json"

if [ ! -f "$OTD_CONFIG" ]; then
    echo -e "${RED}✗ Settings file not found: $OTD_CONFIG${NC}"
    exit 1
fi

echo -e "${YELLOW}Current orientation issue:${NC}"
echo "  Stylus position: Bottom Right"
echo "  Cursor position: Top Left"
echo "  Problem: 180° rotation (flipped both horizontally and vertically)"
echo ""

# Backup current settings
BACKUP_FILE="$HOME/.config/OpenTabletDriver/settings.json.backup.$(date +%s)"
cp "$OTD_CONFIG" "$BACKUP_FILE"
echo -e "${GREEN}✓ Backup created: $BACKUP_FILE${NC}"
echo ""

# Stop daemon
echo -e "${YELLOW}Stopping OpenTabletDriver daemon...${NC}"
sudo systemctl stop otd-daemon
sleep 1

# Fix orientation by setting rotation to 180 degrees
echo -e "${YELLOW}Fixing orientation (applying 180° rotation)...${NC}"

# Use sed to replace rotation value
# This handles both cases: "Rotation": 0 and "Rotation":0
sed -i 's/"Rotation":[[:space:]]*[0-9]\+/"Rotation": 180/g' "$OTD_CONFIG"

echo -e "${GREEN}✓ Rotation set to 180°${NC}"
echo ""

# Verify the change
ROTATION=$(grep -o '"Rotation":[[:space:]]*[0-9]*' "$OTD_CONFIG" | grep -o '[0-9]*$')
echo "Verification: Rotation = $ROTATION°"
echo ""

# Start daemon
echo -e "${YELLOW}Starting OpenTabletDriver daemon...${NC}"
sudo systemctl start otd-daemon
sleep 2

if sudo systemctl is-active --quiet otd-daemon; then
    echo -e "${GREEN}✓ Daemon started successfully${NC}"
else
    echo -e "${RED}✗ Daemon failed to start${NC}"
    echo "Restoring backup..."
    cp "$BACKUP_FILE" "$OTD_CONFIG"
    sudo systemctl start otd-daemon
    exit 1
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Orientation Fix Applied!                                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "Next steps:"
echo "1. Launch OpenTabletDriver GUI: opentabletdriver"
echo "2. Test cursor movement:"
echo "   - Move stylus to bottom right → cursor should go to bottom right"
echo "   - Move stylus to top left → cursor should go to top left"
echo "3. If still wrong, try different rotation values:"
echo "   - 0° (no rotation)"
echo "   - 90° (rotate 90° clockwise)"
echo "   - 180° (rotate 180°)"
echo "   - 270° (rotate 270° clockwise)"
echo "4. Once correct, launch osu!"
echo ""

echo "If you need to try a different rotation:"
echo "  nano ~/.config/OpenTabletDriver/settings.json"
echo "  Find: \"Rotation\": 180"
echo "  Change to: \"Rotation\": 0 (or 90, 270)"
echo "  Save and restart: sudo systemctl restart otd-daemon"
echo ""

echo "To restore backup if needed:"
echo "  cp $BACKUP_FILE $OTD_CONFIG"
echo "  sudo systemctl restart otd-daemon"
echo ""

