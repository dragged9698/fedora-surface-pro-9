#!/bin/bash

################################################################################
# osu! Stylus Inversion - iptsd Config Method
# 
# This script inverts stylus input ONLY while osu! is running
# by temporarily modifying iptsd configuration.
# 
# No xinput required - works with iptsd directly.
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
echo -e "${BLUE}║  osu! Stylus Inversion - iptsd Config Method             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# Check if iptsd config exists
# ============================================================================
if [ ! -f "$IPTSD_CONFIG" ]; then
    echo -e "${RED}✗ iptsd config not found: $IPTSD_CONFIG${NC}"
    exit 1
fi

echo -e "${GREEN}✓ iptsd config found${NC}"
echo ""

# ============================================================================
# Function: Invert stylus for osu!
# ============================================================================
invert_stylus_for_osu() {
    echo -e "${YELLOW}[1/3] Inverting stylus for osu!...${NC}"
    
    # Backup current config
    sudo cp "$IPTSD_CONFIG" "$BACKUP_FILE"
    
    # Check if [Stylus] section exists
    if ! grep -q "\[Stylus\]" "$IPTSD_CONFIG"; then
        echo -e "${YELLOW}Creating [Stylus] section...${NC}"
        echo "" | sudo tee -a "$IPTSD_CONFIG" > /dev/null
        echo "[Stylus]" | sudo tee -a "$IPTSD_CONFIG" > /dev/null
        echo "InvertX = true" | sudo tee -a "$IPTSD_CONFIG" > /dev/null
        echo "InvertY = true" | sudo tee -a "$IPTSD_CONFIG" > /dev/null
    else
        # Update existing [Stylus] section
        # Use a more robust sed approach
        sudo sed -i '/\[Stylus\]/,/^\[/ {
            /^\[Stylus\]/!{
                /^\[/!{
                    s/InvertX = .*/InvertX = true/
                    s/InvertY = .*/InvertY = true/
                }
            }
        }' "$IPTSD_CONFIG"
        
        # If InvertX/InvertY don't exist, add them
        if ! grep -q "InvertX" "$IPTSD_CONFIG"; then
            sudo sed -i '/\[Stylus\]/a InvertX = true' "$IPTSD_CONFIG"
        fi
        if ! grep -q "InvertY" "$IPTSD_CONFIG"; then
            sudo sed -i '/\[Stylus\]/a InvertY = true' "$IPTSD_CONFIG"
        fi
    fi
    
    echo -e "${GREEN}✓ Stylus inversion configured${NC}"
}

# ============================================================================
# Function: Restart iptsd
# ============================================================================
restart_iptsd() {
    echo -e "${YELLOW}[2/3] Restarting iptsd daemon...${NC}"

    # Try different ways to restart iptsd
    if sudo systemctl restart iptsd 2>/dev/null; then
        sleep 2
        echo -e "${GREEN}✓ iptsd restarted via systemctl${NC}"
    elif sudo service iptsd restart 2>/dev/null; then
        sleep 2
        echo -e "${GREEN}✓ iptsd restarted via service${NC}"
    elif sudo /etc/init.d/iptsd restart 2>/dev/null; then
        sleep 2
        echo -e "${GREEN}✓ iptsd restarted via init.d${NC}"
    else
        echo -e "${YELLOW}⚠ Could not restart iptsd via standard methods${NC}"
        echo "Trying to kill and restart iptsd process..."
        sudo pkill -f iptsd 2>/dev/null || true
        sleep 1
        sudo iptsd &
        sleep 2
        echo -e "${GREEN}✓ iptsd process restarted${NC}"
    fi
}

# ============================================================================
# Function: Restore normal stylus
# ============================================================================
restore_stylus() {
    echo -e "${YELLOW}Restoring normal stylus orientation...${NC}"

    # Set InvertX and InvertY to false
    sudo sed -i '/\[Stylus\]/,/^\[/ {
        /^\[Stylus\]/!{
            /^\[/!{
                s/InvertX = .*/InvertX = false/
                s/InvertY = .*/InvertY = false/
            }
        }
    }' "$IPTSD_CONFIG"

    # Restart iptsd using multiple methods
    if sudo systemctl restart iptsd 2>/dev/null; then
        sleep 1
    elif sudo service iptsd restart 2>/dev/null; then
        sleep 1
    elif sudo /etc/init.d/iptsd restart 2>/dev/null; then
        sleep 1
    else
        sudo pkill -f iptsd 2>/dev/null || true
        sleep 1
        sudo iptsd &
        sleep 1
    fi

    echo -e "${GREEN}✓ Stylus restored to normal orientation${NC}"
}

# ============================================================================
# Main: Launch osu! with stylus inversion
# ============================================================================

# Invert stylus
invert_stylus_for_osu

# Restart iptsd
restart_iptsd

echo ""
echo -e "${BLUE}[3/3] Launching osu!...${NC}"
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

# Clean up backup
rm -f "$BACKUP_FILE"

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Done! Stylus restored to normal orientation             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "Stylus is now back to normal orientation for other applications."
echo ""

