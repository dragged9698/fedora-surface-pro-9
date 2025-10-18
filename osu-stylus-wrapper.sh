#!/bin/bash

################################################################################
# osu! Stylus Wrapper - Invert Stylus Only for osu!
# 
# This script:
# 1. Inverts stylus input when osu! starts
# 2. Restores normal stylus input when osu! exits
# 3. Allows normal stylus behavior outside of osu!
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

IPTSD_CONFIG="/etc/iptsd/iptsd.conf"
BACKUP_FILE="/tmp/iptsd.conf.backup.$$"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  osu! Stylus Wrapper - Invert for osu! Only              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# Function: Invert stylus for osu!
# ============================================================================
invert_stylus_for_osu() {
    echo -e "${YELLOW}Inverting stylus for osu!...${NC}"
    
    # Backup current config
    sudo cp "$IPTSD_CONFIG" "$BACKUP_FILE"
    
    # Set InvertX and InvertY to true for osu!
    sudo sed -i '/\[Stylus\]/,/^\[/ {
        s/InvertX = .*/InvertX = true/
        s/InvertY = .*/InvertY = true/
    }' "$IPTSD_CONFIG"
    
    # Restart iptsd to apply changes
    systemctl restart iptsd
    sleep 1
    
    echo -e "${GREEN}✓ Stylus inverted for osu!${NC}"
}

# ============================================================================
# Function: Restore normal stylus
# ============================================================================
restore_stylus() {
    echo -e "${YELLOW}Restoring normal stylus orientation...${NC}"
    
    # Set InvertX and InvertY to false for normal use
    sudo sed -i '/\[Stylus\]/,/^\[/ {
        s/InvertX = .*/InvertX = false/
        s/InvertY = .*/InvertY = false/
    }' "$IPTSD_CONFIG"
    
    # Restart iptsd to apply changes
    systemctl restart iptsd
    sleep 1
    
    echo -e "${GREEN}✓ Stylus restored to normal orientation${NC}"
}

# ============================================================================
# Main: Launch osu! with stylus inversion
# ============================================================================

echo "Checking for stylus device..."
if ! xinput list | grep -qi stylus; then
    echo -e "${RED}✗ Stylus device not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Stylus device found${NC}"
echo ""

# Invert stylus for osu!
invert_stylus_for_osu
echo ""

echo -e "${BLUE}Launching osu!...${NC}"
echo ""

# Launch osu! via Steam
steam steam://run/1677970 &
OSU_PID=$!

echo -e "${GREEN}osu! launched (PID: $OSU_PID)${NC}"
echo "Waiting for osu! to exit..."
echo ""

# Wait for osu! to exit
wait $OSU_PID 2>/dev/null || true

echo ""
echo -e "${YELLOW}osu! has exited${NC}"
echo ""

# Restore normal stylus orientation
restore_stylus
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Done! Stylus restored to normal orientation             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

