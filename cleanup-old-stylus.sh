#!/bin/bash
# Remove old iptsd/libwacom stylus configuration
# Keep OpenTabletDriver as the primary stylus driver

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Cleaning up old iptsd/libwacom stylus configuration      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Stop iptsd service
echo "Stopping iptsd service..."
sudo systemctl stop iptsd 2>/dev/null || echo "  ℹ iptsd not running"
sudo systemctl disable iptsd 2>/dev/null || echo "  ℹ iptsd not enabled"

# Remove iptsd package
echo "Removing iptsd package..."
sudo dnf remove -y iptsd 2>/dev/null || echo "  ℹ iptsd not installed"

# Remove old configuration files
echo "Removing old configuration files..."
sudo rm -rf /etc/iptsd/ && echo "  ✓ Removed /etc/iptsd/" || echo "  ℹ /etc/iptsd/ not found"
sudo rm -f /etc/udev/rules.d/99-stylus-gaming.rules && echo "  ✓ Removed udev rules" || echo "  ℹ udev rules not found"

# Remove old wacom configuration
echo "Removing old wacom configuration..."
rm -rf ~/.config/wacom/ && echo "  ✓ Removed ~/.config/wacom/" || echo "  ℹ ~/.config/wacom/ not found"

# Remove old stylus tools (if they exist)
echo "Removing old stylus tools..."
rm -f /etc/gaming-setup/stylus/calibrate-stylus.sh 2>/dev/null && echo "  ✓ Removed old calibrate-stylus.sh" || true
rm -f /etc/gaming-setup/stylus/test-stylus.sh.old 2>/dev/null && echo "  ✓ Removed old test-stylus.sh" || true

# Reload udev rules
echo "Reloading udev rules..."
sudo udevadm control --reload-rules 2>/dev/null || true
sudo udevadm trigger 2>/dev/null || true

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Cleanup Complete                                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "✅ Old iptsd/libwacom configuration removed"
echo "✅ OpenTabletDriver is now the primary stylus driver"
echo ""
echo "Next steps:"
echo "  1. Verify OpenTabletDriver is running:"
echo "     systemctl status otd-daemon"
echo ""
echo "  2. Launch OpenTabletDriver GUI:"
echo "     opentabletdriver"
echo ""
echo "  3. Configure for osu!:"
echo "     Load ~/.config/OpenTabletDriver/osu-profile.json"
echo ""
echo "  4. Test stylus:"
echo "     /etc/gaming-setup/stylus/test-stylus.sh"
echo ""

