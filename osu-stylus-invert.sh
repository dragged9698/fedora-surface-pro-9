#!/bin/bash

################################################################################
# osu! Stylus Inversion - Runtime Remapping
# 
# This script inverts stylus input ONLY while osu! is running
# using xinput coordinate transformation matrix.
# 
# How it works:
# 1. Gets stylus device ID
# 2. Applies coordinate inversion matrix when osu! starts
# 3. Restores normal coordinates when osu! exits
# 4. Stylus works normally outside of osu!
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  osu! Stylus Inversion - Runtime Remapping               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# Get stylus device ID
# ============================================================================
echo -e "${YELLOW}Finding stylus device...${NC}"

STYLUS_ID=$(xinput list | grep -i stylus | grep -o 'id=[0-9]*' | head -1 | cut -d'=' -f2)

if [ -z "$STYLUS_ID" ]; then
    echo -e "${RED}✗ Stylus device not found${NC}"
    echo "Available devices:"
    xinput list
    exit 1
fi

echo -e "${GREEN}✓ Stylus device found: ID $STYLUS_ID${NC}"
echo ""

# Get screen resolution for coordinate transformation
RESOLUTION=$(xrandr | grep " connected primary" | awk '{print $4}' | cut -d'+' -f1)
if [ -z "$RESOLUTION" ]; then
    RESOLUTION=$(xrandr | grep " connected" | grep -v disconnected | awk '{print $3}' | cut -d'+' -f1)
fi

WIDTH=$(echo "$RESOLUTION" | cut -d'x' -f1)
HEIGHT=$(echo "$RESOLUTION" | cut -d'x' -f2)

echo "Screen resolution: ${WIDTH}x${HEIGHT}"
echo ""

# ============================================================================
# Function: Apply inversion matrix
# ============================================================================
apply_inversion() {
    echo -e "${YELLOW}Applying stylus inversion for osu!...${NC}"
    
    # Coordinate transformation matrix for 180° rotation (inversion)
    # Format: a b c d e f g h i
    # This matrix inverts both X and Y coordinates
    xinput set-prop $STYLUS_ID "Coordinate Transformation Matrix" \
        -1 0 1 \
        0 -1 1 \
        0 0 1
    
    echo -e "${GREEN}✓ Stylus inverted (180° rotation applied)${NC}"
}

# ============================================================================
# Function: Restore normal coordinates
# ============================================================================
restore_normal() {
    echo -e "${YELLOW}Restoring normal stylus coordinates...${NC}"
    
    # Identity matrix (no transformation)
    xinput set-prop $STYLUS_ID "Coordinate Transformation Matrix" \
        1 0 0 \
        0 1 0 \
        0 0 1
    
    echo -e "${GREEN}✓ Stylus restored to normal${NC}"
}

# ============================================================================
# Main: Launch osu! with inversion
# ============================================================================

echo -e "${BLUE}Launching osu! with inverted stylus...${NC}"
echo ""

# Apply inversion
apply_inversion
echo ""

# Launch osu! via Steam
echo "Starting osu!..."
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

# Restore normal coordinates
restore_normal
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Done! Stylus restored to normal                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "Stylus is now back to normal orientation for other applications."
echo ""

