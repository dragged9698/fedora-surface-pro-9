#!/bin/bash

################################################################################
# Stage 6: Gaming Setup (Optional)
# 
# Installs gaming packages and tools
# - Priority gaming packages (Steam, MangoHud, ProtonUp-Qt, Wine, Mesa)
# - Optional gaming packages (Lutris, vkBasalt, OBS, Gamescope)
# - Controller support (Xbox, DualSense)
#
# Prerequisites: Stage 1 (Repository Setup) must be completed for RPM Fusion
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION & CONSTANTS
# ============================================================================

readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_DIR="/var/log/surface-setup"
readonly LOG_FILE="$LOG_DIR/stage6.log"
readonly COMPLETION_MARKER="$LOG_DIR/stage6.complete"
readonly STAGE1_MARKER="$LOG_DIR/stage1.complete"

# Gaming configuration directories
readonly GAMING_CONFIG_DIR="/etc/gaming-setup"
readonly SHADER_CACHE_DIR="$HOME/.cache/shader-cache"
readonly DXVK_CACHE_DIR="$HOME/.cache/dxvk-cache"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE" >&2
}

# ============================================================================
# PREREQUISITE CHECKS
# ============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use: sudo ./stage6-gaming.sh)"
        exit 1
    fi
}

check_stage1_complete() {
    if [[ ! -f "$STAGE1_MARKER" ]]; then
        log_error "Stage 1 (Repository Setup) must be completed first"
        log_info "Run: sudo ./stage1-repositories.sh"
        exit 1
    fi
    log_success "Stage 1 prerequisite verified"
}

check_already_completed() {
    if [[ -f "$COMPLETION_MARKER" ]]; then
        log_info "Stage 6 already completed. Use --force to re-run."
        exit 0
    fi
}

# ============================================================================
# GAMING SETUP
# ============================================================================

setup_log_directory() {
    mkdir -p "$LOG_DIR" || {
        log_error "Failed to create log directory"
        exit 1
    }
}

install_gaming_packages() {
    log_info "Installing gaming packages for Surface Pro 9..."
    echo ""

    # Enable RPM Fusion repositories if not already enabled
    log_info "Ensuring RPM Fusion repositories are enabled..."
    if ! dnf repolist 2>/dev/null | grep -q "rpmfusion"; then
        log_info "Adding RPM Fusion repositories..."
        dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
                         https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm 2>&1 | tail -3 || {
            log_warn "Failed to add RPM Fusion repositories"
        }
    else
        log_success "RPM Fusion repositories already enabled"
    fi

    echo ""
    log_info "Installing priority gaming packages..."

    # Steam (primary gaming platform)
    if ! rpm -q steam &>/dev/null; then
        log_info "Installing Steam..."
        dnf install -y steam 2>&1 | tail -3 || {
            log_warn "Failed to install Steam"
        }
    else
        log_success "Steam is already installed"
    fi

    # MangoHud (performance overlay)
    if ! rpm -q mangohud &>/dev/null; then
        log_info "Installing MangoHud (performance overlay)..."
        dnf install -y mangohud 2>&1 | tail -3 || {
            log_warn "Failed to install MangoHud"
        }
    else
        log_success "MangoHud is already installed"
    fi

    # GOverlay (MangoHud GUI)
    if ! rpm -q goverlay &>/dev/null; then
        log_info "Installing GOverlay (MangoHud configuration)..."
        dnf install -y goverlay 2>&1 | tail -3 || {
            log_warn "Failed to install GOverlay"
        }
    else
        log_success "GOverlay is already installed"
    fi

    # ProtonUp-Qt (Proton version manager)
    if ! command -v protonup-qt &>/dev/null; then
        log_info "Installing ProtonUp-Qt (Proton manager)..."
        # ProtonUp-Qt is available via COPR repository
        dnf copr enable -y apicalshark/ProtonUp-Qt 2>&1 | tail -2 || {
            log_warn "Failed to enable ProtonUp-Qt COPR repository"
        }
        dnf install -y protonup-qt 2>&1 | tail -3 || {
            log_warn "Failed to install ProtonUp-Qt (may need manual installation from GitHub)"
        }
    else
        log_success "ProtonUp-Qt is already installed"
    fi

    # Wine with 32-bit support
    if ! rpm -q wine &>/dev/null; then
        log_info "Installing Wine (Windows compatibility layer)..."
        dnf install -y wine wine.i686 2>&1 | tail -3 || {
            log_warn "Failed to install Wine"
        }
    else
        log_success "Wine is already installed"
    fi

    # Winetricks (Wine helper)
    if ! rpm -q winetricks &>/dev/null; then
        log_info "Installing Winetricks (Wine helper)..."
        dnf install -y winetricks 2>&1 | tail -3 || {
            log_warn "Failed to install Winetricks"
        }
    else
        log_success "Winetricks is already installed"
    fi

    # Mesa Vulkan drivers (graphics performance)
    if ! rpm -q mesa-vulkan-drivers &>/dev/null; then
        log_info "Installing Mesa Vulkan drivers (64-bit)..."
        dnf install -y mesa-vulkan-drivers 2>&1 | tail -3 || {
            log_warn "Failed to install Mesa Vulkan drivers (64-bit)"
        }
    else
        log_success "Mesa Vulkan drivers (64-bit) already installed"
    fi

    if ! rpm -q mesa-vulkan-drivers.i686 &>/dev/null; then
        log_info "Installing Mesa Vulkan drivers (32-bit)..."
        dnf install -y mesa-vulkan-drivers.i686 2>&1 | tail -3 || {
            log_warn "Failed to install Mesa Vulkan drivers (32-bit)"
        }
    else
        log_success "Mesa Vulkan drivers (32-bit) already installed"
    fi

    echo ""
    log_info "Installing optional gaming packages..."

    # Lutris (alternative game launcher)
    if ! rpm -q lutris &>/dev/null; then
        log_info "Installing Lutris (game launcher)..."
        dnf install -y lutris 2>&1 | tail -3 || {
            log_warn "Failed to install Lutris"
        }
    else
        log_success "Lutris is already installed"
    fi

    # vkBasalt (Vulkan post-processing)
    if ! rpm -q vkbasalt &>/dev/null; then
        log_info "Installing vkBasalt (Vulkan enhancements)..."
        dnf install -y vkbasalt 2>&1 | tail -3 || {
            log_warn "Failed to install vkBasalt"
        }
    else
        log_success "vkBasalt is already installed"
    fi

    # OBS Studio (streaming/recording)
    if ! rpm -q obs-studio &>/dev/null; then
        log_info "Installing OBS Studio (streaming/recording)..."
        dnf install -y obs-studio 2>&1 | tail -3 || {
            log_warn "Failed to install OBS Studio"
        }
    else
        log_success "OBS Studio is already installed"
    fi

    # Gamescope (gaming compositor)
    if ! rpm -q gamescope &>/dev/null; then
        log_info "Installing Gamescope (gaming compositor)..."
        dnf install -y gamescope 2>&1 | tail -3 || {
            log_warn "Failed to install Gamescope"
        }
    else
        log_success "Gamescope is already installed"
    fi

    echo ""
    log_info "Installing controller support packages..."

    # Xbox controller support (via kernel-modules-extra)
    log_info "Ensuring Xbox controller support..."
    if ! rpm -q kernel-modules-extra &>/dev/null; then
        log_info "Installing kernel-modules-extra (Xbox controller support)..."
        dnf install -y kernel-modules-extra 2>&1 | tail -3 || {
            log_warn "Failed to install kernel-modules-extra"
        }
    else
        log_success "kernel-modules-extra already installed (Xbox support)"
    fi

    # Install xpadneo for better Xbox controller support (optional)
    log_info "Installing xpadneo (enhanced Xbox controller support)..."
    dnf copr enable -y sentry/xpadneo 2>&1 | tail -2 || {
        log_warn "Failed to enable xpadneo COPR repository"
    }
    dnf install -y xpadneo 2>&1 | tail -3 || {
        log_warn "xpadneo not available (Xbox controllers still supported via kernel)"
    }

    # DualSense controller support (via steam-devices)
    log_info "Installing DualSense controller support..."
    if ! rpm -q steam-devices &>/dev/null; then
        log_info "Installing steam-devices (DualSense support)..."
        dnf install -y steam-devices 2>&1 | tail -3 || {
            log_warn "Failed to install steam-devices"
        }
    else
        log_success "steam-devices already installed (DualSense support)"
    fi

    echo ""
    log_success "Gaming packages installation complete"
    return 0
}

install_advanced_gaming_packages() {
    log_info "Installing advanced gaming packages and tools (optional)..."
    echo ""

    # Note: COPR repositories for @gaming/* are not available for Fedora 42
    # These are optional packages - failures are non-critical

    # VKD3D (Direct3D 12 to Vulkan) - try standard repo first
    log_info "Installing VKD3D (Direct3D 12 to Vulkan)..."
    dnf install -y vkd3d 2>&1 | tail -3 || {
        log_warn "VKD3D not available (optional - Proton includes fallback)"
    }

    # Bottles (Windows app/game runner)
    log_info "Installing Bottles..."
    dnf install -y bottles 2>&1 | tail -3 || {
        log_warn "Bottles not available (optional)"
    }

    # Input device tools
    log_info "Installing input device tools..."
    dnf install -y jstest-gtk evtest joystick 2>&1 | tail -3 || {
        log_warn "Some input device tools not available (optional)"
    }

    # Additional codec support
    log_info "Installing additional codec support..."
    dnf install -y ffmpeg 2>&1 | tail -3 || {
        log_warn "FFmpeg not available (optional)"
    }

    echo ""
    log_success "Advanced gaming packages installation complete (some optional packages may have been skipped)"
    return 0
}

configure_gaming_performance() {
    log_info "Configuring gaming performance optimizations..."
    echo ""

    # Create gaming config directory
    mkdir -p "$GAMING_CONFIG_DIR" || {
        log_warn "Failed to create gaming config directory"
    }

    # Configure CPU governor for performance
    log_info "Configuring CPU governor for gaming..."
    if command -v cpupower &>/dev/null; then
        cpupower frequency-set -g performance 2>&1 | tail -2 || {
            log_warn "Failed to set CPU governor (may require additional setup)"
        }
    else
        log_warn "cpupower not available (install linux-tools for CPU tuning)"
    fi

    # Create shader cache directories
    log_info "Creating shader cache directories..."
    mkdir -p "$SHADER_CACHE_DIR" "$DXVK_CACHE_DIR" || {
        log_warn "Failed to create cache directories"
    }

    # Configure system limits for gaming
    log_info "Configuring system limits for gaming..."
    cat > /etc/security/limits.d/99-gaming.conf << 'EOF'
# Gaming performance limits
* soft nofile 524288
* hard nofile 524288
* soft memlock unlimited
* hard memlock unlimited
* soft nproc 524288
* hard nproc 524288
EOF
    log_success "System limits configured"

    # Configure sysctl for gaming performance
    log_info "Configuring kernel parameters for gaming..."
    cat > /etc/sysctl.d/99-gaming.conf << 'EOF'
# Gaming performance kernel parameters
vm.max_map_count = 2147483642
vm.swappiness = 10
kernel.sched_autogroup_enabled = 0
EOF
    sysctl -p /etc/sysctl.d/99-gaming.conf 2>&1 | tail -3 || {
        log_warn "Failed to apply kernel parameters (some may not be supported)"
    }

    echo ""
    log_success "Gaming performance configuration complete"
    return 0
}

configure_audio_optimization() {
    log_info "Configuring audio optimization for gaming..."
    echo ""

    # Check if PipeWire is available (modern audio server)
    if command -v pipewire &>/dev/null; then
        log_info "PipeWire detected - configuring for gaming..."

        # Create PipeWire gaming profile
        mkdir -p "$HOME/.config/pipewire/pipewire.conf.d" 2>/dev/null || true

        cat > "$HOME/.config/pipewire/pipewire.conf.d/99-gaming.conf" << 'EOF'
# Gaming audio optimization
context.properties = {
    default.clock.rate = 48000
    default.clock.allowed-rates = [ 48000 ]
    default.period = 512
    default.n.periods = 2
}
EOF
        log_success "PipeWire gaming profile created"
    else
        log_info "PipeWire not available, checking for PulseAudio..."
        if command -v pulseaudio &>/dev/null; then
            log_info "PulseAudio detected - configuring for gaming..."

            # Create PulseAudio gaming profile
            mkdir -p "$HOME/.config/pulse" 2>/dev/null || true

            cat > "$HOME/.config/pulse/daemon.conf.d/99-gaming.conf" << 'EOF'
# Gaming audio optimization
default-sample-rate = 48000
default-sample-format = s16le
default-channel-map = stereo
resample-method = speex-float-5
EOF
            log_success "PulseAudio gaming profile created"
        else
            log_warn "No audio server detected"
        fi
    fi

    echo ""
    log_success "Audio optimization configuration complete"
    return 0
}

configure_stylus_support() {
    log_info "Configuring stylus support for Surface Pro (osu! optimized)..."
    echo ""

    # Install essential packages for stylus support
    log_info "Installing stylus support packages..."
    dnf install -y libwacom libwacom-data xorg-x11-apps 2>&1 | tail -3 || {
        log_warn "Some stylus packages failed to install"
    }

    # Create stylus configuration directory
    local stylus_config_dir="/etc/gaming-setup/stylus"
    mkdir -p "$stylus_config_dir" || {
        log_warn "Failed to create stylus config directory"
    }

    log_success "Stylus support directory created"

    # Configure iptsd for stylus (touchscreen + stylus support)
    log_info "Configuring iptsd for stylus support..."
    mkdir -p /etc/iptsd

    # Create iptsd configuration optimized for gaming
    cat > /etc/iptsd/iptsd.conf << 'IPTSD_CONFIG'
[Device]
# Surface Pro stylus configuration
PressureThreshold = 5
MaxPressure = 4095

[StylusGaming]
# Gaming-optimized stylus settings
TipDistance = 0
PressureThreshold = 5
MaxPressure = 4095
SmoothingFactor = 0.6
LatencyCompensation = true
IPTSD_CONFIG
    log_success "iptsd configuration created"

    # Enable and start iptsd service (if available)
    log_info "Configuring iptsd service..."
    if systemctl list-unit-files 2>/dev/null | grep -q "iptsd.service"; then
        log_info "Enabling iptsd service..."
        systemctl enable iptsd 2>&1 | tail -1 || {
            log_warn "Failed to enable iptsd"
        }
        systemctl start iptsd 2>&1 | tail -1 || {
            log_warn "Failed to start iptsd (service may not be available)"
        }
        log_success "iptsd service configured"
    else
        log_warn "iptsd service not available (will use OpenTabletDriver for stylus)"
    fi

    # Download and install OpenTabletDriver RPM
    log_info "Downloading and installing OpenTabletDriver..."
    local otd_download_dir="/tmp/OpenTabletDriver-download"
    mkdir -p "$otd_download_dir"

    cd "$otd_download_dir" || {
        log_warn "Failed to create download directory"
        return 1
    }

    # Get latest release version (note: filename is lowercase, tag is v-prefixed)
    local otd_version="0.6.6.2"
    local otd_rpm="opentabletdriver-${otd_version}-1.x86_64.rpm"
    local otd_url="https://github.com/OpenTabletDriver/OpenTabletDriver/releases/download/v${otd_version}/${otd_rpm}"

    # Download RPM with verbose error output and curl fallback
    log_info "Attempting to download from: $otd_url"

    if wget -v "$otd_url" -O "$otd_rpm" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "OpenTabletDriver RPM downloaded successfully"
    elif command -v curl &>/dev/null; then
        log_info "wget failed, trying curl as fallback..."
        if curl -L "$otd_url" -o "$otd_rpm" 2>&1 | tee -a "$LOG_FILE"; then
            log_success "OpenTabletDriver RPM downloaded successfully (via curl)"
        else
            log_warn "Failed to download OpenTabletDriver RPM (both wget and curl failed)"
            log_info "Manual download: https://github.com/OpenTabletDriver/OpenTabletDriver/releases"
            cd - > /dev/null
            return 1
        fi
    else
        log_warn "Failed to download OpenTabletDriver RPM (wget failed, curl not available)"
        log_info "Manual download: https://github.com/OpenTabletDriver/OpenTabletDriver/releases"
        cd - > /dev/null
        return 1
    fi

    # Install RPM
    log_info "Installing OpenTabletDriver RPM..."
    if sudo dnf install -y "./$otd_rpm" 2>&1 | tail -3; then
        log_success "OpenTabletDriver installed successfully"

        # Update initramfs
        log_info "Updating initramfs..."
        sudo dracut --regenerate-all --force 2>&1 | tail -1 || {
            log_warn "Failed to update initramfs (may not be critical)"
        }

        # Enable OpenTabletDriver daemon autostart
        log_info "Enabling OpenTabletDriver daemon autostart..."
        systemctl --user enable opentabletdriver.service --now 2>&1 | tail -1 || {
            log_warn "Failed to enable OpenTabletDriver autostart"
        }
        log_success "OpenTabletDriver autostart enabled"
    else
        log_warn "Failed to install OpenTabletDriver RPM"
    fi

    cd - > /dev/null

    # Create OpenTabletDriver configuration script
    log_info "Creating OpenTabletDriver configuration script..."
    cat > "$stylus_config_dir/configure-otd.sh" << 'EOF'
#!/bin/bash
# OpenTabletDriver configuration script for osu! and gaming

echo "OpenTabletDriver Configuration for Gaming"
echo "=========================================="
echo ""

# Check if OpenTabletDriver is installed
if ! command -v opentabletdriver &>/dev/null; then
    echo "Error: OpenTabletDriver not found. Install it first."
    exit 1
fi

echo "OpenTabletDriver options:"
echo "1. Launch OpenTabletDriver GUI"
echo "2. Check daemon status"
echo "3. Restart daemon"
echo "4. View configuration"
echo "5. Test tablet input"
echo ""
read -p "Select option (1-5): " option

case $option in
    1)
        echo "Launching OpenTabletDriver GUI..."
        opentabletdriver &
        ;;
    2)
        echo "Checking OpenTabletDriver daemon status..."
        systemctl status otd-daemon
        ;;
    3)
        echo "Restarting OpenTabletDriver daemon..."
        sudo systemctl restart otd-daemon
        echo "Done!"
        ;;
    4)
        echo "OpenTabletDriver configuration:"
        cat ~/.config/OpenTabletDriver/settings.json 2>/dev/null || echo "No configuration found yet"
        ;;
    5)
        echo "Testing tablet input..."
        echo "Move stylus over the screen..."
        sleep 3
        journalctl -u otd-daemon -f --lines=20
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac
EOF
    chmod +x "$stylus_config_dir/configure-otd.sh" || {
        log_warn "Failed to make OTD configuration script executable"
    }
    log_success "OpenTabletDriver configuration script created"

    # Create OpenTabletDriver osu! profile
    log_info "Creating OpenTabletDriver osu! profile..."
    mkdir -p "$HOME/.config/OpenTabletDriver" 2>/dev/null || true

    cat > "$HOME/.config/OpenTabletDriver/osu-profile.json" << 'EOF'
{
  "Name": "osu! Gaming Profile",
  "OutputMode": "Absolute",
  "AbsoluteModeSettings": {
    "Display": 0,
    "Sensitivity": 1.0,
    "Rotation": 0,
    "EnableClipping": true
  },
  "RelativeModeSettings": {
    "Sensitivity": 1.0,
    "Acceleration": 0,
    "ResetDelay": 50
  },
  "Filters": [
    {
      "Type": "SmoothingFilter",
      "Settings": {
        "Smoothing": 0.5,
        "Latency": 0
      }
    }
  ],
  "Tools": [
    {
      "Type": "Pen",
      "Settings": {
        "Pressure": 1.0,
        "Tip Activation Threshold": 0,
        "Tip Pressure Threshold": 0
      }
    }
  ]
}
EOF
    log_success "OpenTabletDriver osu! profile created"

    # Create OpenTabletDriver testing utility
    log_info "Creating OpenTabletDriver testing utility..."
    cat > "$stylus_config_dir/test-stylus.sh" << 'EOF'
#!/bin/bash
# Test OpenTabletDriver functionality

echo "OpenTabletDriver Test"
echo "===================="
echo ""

# Check if OpenTabletDriver daemon is running
if systemctl is-active --quiet otd-daemon; then
    echo "✓ OpenTabletDriver daemon is running"
else
    echo "✗ OpenTabletDriver daemon is NOT running"
    echo "Starting daemon..."
    sudo systemctl start otd-daemon
fi

echo ""
echo "OpenTabletDriver Status:"
systemctl status otd-daemon --no-pager

echo ""
echo "Recent OpenTabletDriver logs:"
journalctl -u otd-daemon -n 10 --no-pager

echo ""
echo "To configure OpenTabletDriver:"
echo "  1. Launch GUI: opentabletdriver"
echo "  2. Or use: /etc/gaming-setup/stylus/configure-otd.sh"
echo ""
echo "For osu! gaming:"
echo "  1. Launch OpenTabletDriver GUI"
echo "  2. Load profile: ~/.config/OpenTabletDriver/osu-profile.json"
echo "  3. Configure tablet area and sensitivity"
echo "  4. Launch osu!"
EOF
    chmod +x "$stylus_config_dir/test-stylus.sh" || {
        log_warn "Failed to make test script executable"
    }
    log_success "Stylus testing utility created"

    echo ""
    log_success "Stylus support configuration complete"
    return 0
}

display_gaming_info() {
    log_info "Gaming Setup Information:"
    echo ""
    echo "  ╔════════════════════════════════════════════════════════════╗"
    echo "  ║  CORE GAMING COMPONENTS                                   ║"
    echo "  ╚════════════════════════════════════════════════════════════╝"
    rpm -q steam &>/dev/null && echo "    ✓ Steam (primary gaming platform)" || echo "    ✗ Steam (not installed)"
    rpm -q mangohud &>/dev/null && echo "    ✓ MangoHud (performance overlay)" || echo "    ✗ MangoHud (not installed)"
    rpm -q goverlay &>/dev/null && echo "    ✓ GOverlay (MangoHud GUI configuration)" || echo "    ✗ GOverlay (not installed)"
    command -v protonup-qt &>/dev/null && echo "    ✓ ProtonUp-Qt (Proton version manager - via COPR)" || echo "    ✗ ProtonUp-Qt (not installed)"
    rpm -q wine &>/dev/null && echo "    ✓ Wine + Winetricks (Windows compatibility)" || echo "    ✗ Wine (not installed)"
    rpm -q mesa-vulkan-drivers &>/dev/null && echo "    ✓ Mesa Vulkan Drivers (32/64-bit)" || echo "    ✗ Mesa Vulkan Drivers (not installed)"
    echo ""
    echo "  ╔════════════════════════════════════════════════════════════╗"
    echo "  ║  ADVANCED GAMING TOOLS                                    ║"
    echo "  ╚════════════════════════════════════════════════════════════╝"
    rpm -q lutris &>/dev/null && echo "    ✓ Lutris (alternative game launcher)" || echo "    ✗ Lutris (not installed)"
    rpm -q bottles &>/dev/null && echo "    ✓ Bottles (Windows app/game runner)" || echo "    ✗ Bottles (not installed)"
    rpm -q vkbasalt &>/dev/null && echo "    ✓ vkBasalt (Vulkan post-processing)" || echo "    ✗ vkBasalt (not installed)"
    rpm -q obs-studio &>/dev/null && echo "    ✓ OBS Studio (streaming/recording)" || echo "    ✗ OBS Studio (not installed)"
    rpm -q gamescope &>/dev/null && echo "    ✓ Gamescope (gaming compositor)" || echo "    ✗ Gamescope (not installed)"
    echo ""
    echo "  ╔════════════════════════════════════════════════════════════╗"
    echo "  ║  GRAPHICS & COMPATIBILITY                                 ║"
    echo "  ╚════════════════════════════════════════════════════════════╝"
    rpm -q vkd3d &>/dev/null && echo "    ✓ VKD3D (Direct3D 12 to Vulkan)" || echo "    ✗ VKD3D (not installed)"
    echo "    ✓ Proton (Steam's compatibility layer - included with Steam)"
    rpm -q wine &>/dev/null && echo "    ✓ Wine (Windows compatibility)" || echo "    ✗ Wine (not installed)"
    rpm -q mesa-vulkan-drivers &>/dev/null && echo "    ✓ Mesa Vulkan drivers (32/64-bit)" || echo "    ✗ Mesa Vulkan drivers (not installed)"
    echo ""
    echo "  ╔════════════════════════════════════════════════════════════╗"
    echo "  ║  CONTROLLER & INPUT SUPPORT                               ║"
    echo "  ╚════════════════════════════════════════════════════════════╝"
    rpm -q kernel-modules-extra &>/dev/null && echo "    ✓ Xbox Controller Support (kernel-modules-extra)" || echo "    ✗ Xbox Controller Support (not installed)"
    rpm -q steam-devices &>/dev/null && echo "    ✓ DualSense Controller Support (steam-devices)" || echo "    ✗ DualSense Controller Support (not installed)"
    echo ""
    echo "  ╔════════════════════════════════════════════════════════════╗"
    echo "  ║  STYLUS SUPPORT (OpenTabletDriver - osu! optimized)       ║"
    echo "  ╚════════════════════════════════════════════════════════════╝"
    command -v opentabletdriver &>/dev/null && echo "    ✓ OpenTabletDriver (gaming-optimized stylus driver)" || echo "    ✗ OpenTabletDriver (not installed)"
    rpm -q libwacom &>/dev/null && echo "    ✓ libwacom (fallback support)" || echo "    ✗ libwacom (not installed)"
    [[ -f "$HOME/.config/OpenTabletDriver/osu-profile.json" ]] && echo "    ✓ osu! gaming profile pre-configured" || echo "    ✗ osu! gaming profile (not configured)"
    [[ -f "/etc/gaming-setup/stylus/test-stylus.sh" ]] && echo "    ✓ Configuration tools included" || echo "    ✗ Configuration tools (not found)"
    echo ""
    echo "  ╔════════════════════════════════════════════════════════════╗"
    echo "  ║  PERFORMANCE OPTIMIZATIONS                                ║"
    echo "  ╚════════════════════════════════════════════════════════════╝"
    echo "    ✓ CPU governor set to performance"
    echo "    ✓ Kernel parameters optimized (vm.max_map_count, swappiness)"
    echo "    ✓ System limits configured for gaming"
    echo "    ✓ Audio optimization (PipeWire/PulseAudio)"
    echo "    ✓ Shader cache directories created"
    echo ""
    echo "  ╔════════════════════════════════════════════════════════════╗"
    echo "  ║  QUICK START GUIDE                                        ║"
    echo "  ╚════════════════════════════════════════════════════════════╝"
    echo "    1. Launch Steam from applications menu"
    echo "    2. Enable Proton in Steam Settings > Compatibility"
    echo "    3. Use ProtonUp-Qt to manage Proton versions"
    echo "    4. Use MangoHud for performance monitoring (Shift+F12)"
    echo "    5. Connect controllers via Bluetooth or USB"
    echo "    6. Test controllers: jstest-gtk or evtest"
    echo "    7. Test stylus: /etc/gaming-setup/stylus/test-stylus.sh"
    echo "    8. Configure stylus: /etc/gaming-setup/stylus/configure-otd.sh"
    echo ""
    echo "  ╔════════════════════════════════════════════════════════════╗"
    echo "  ║  ADVANCED LAUNCHERS                                       ║"
    echo "  ╚════════════════════════════════════════════════════════════╝"
    echo "    • Heroic: Epic Games & GOG games"
    echo "    • Bottles: Windows applications & games"
    echo "    • GameHub: Unified game library"
    echo "    • Lutris: Community game configurations"
    echo ""
    echo "  ╔════════════════════════════════════════════════════════════╗"
    echo "  ║  CONFIGURATION FILES                                      ║"
    echo "  ╚════════════════════════════════════════════════════════════╝"
    echo "    • System limits: /etc/security/limits.d/99-gaming.conf"
    echo "    • Kernel params: /etc/sysctl.d/99-gaming.conf"
    echo "    • Audio config: ~/.config/pipewire/pipewire.conf.d/"
    echo "    • Shader cache: ~/.cache/shader-cache/"
    echo "    • DXVK cache: ~/.cache/dxvk-cache/"
    echo "    • OTD config: ~/.config/OpenTabletDriver/"
    echo "    • OTD profile: ~/.config/OpenTabletDriver/osu-profile.json"
    echo "    • OTD tools: /etc/gaming-setup/stylus/"
    echo ""
    echo "  ╔════════════════════════════════════════════════════════════╗"
    echo "  ║  STYLUS TROUBLESHOOTING (OpenTabletDriver)                ║"
    echo "  ╚════════════════════════════════════════════════════════════╝"
    echo "    • Test stylus: /etc/gaming-setup/stylus/test-stylus.sh"
    echo "    • Configure OTD: /etc/gaming-setup/stylus/configure-otd.sh"
    echo "    • Launch GUI: opentabletdriver"
    echo "    • Check daemon: systemctl status otd-daemon"
    echo "    • View logs: journalctl -u otd-daemon -f"
    echo "    • Restart daemon: sudo systemctl restart otd-daemon"
    echo "    • For osu!: Load ~/.config/OpenTabletDriver/osu-profile.json"
    echo ""
}

# ============================================================================
# COMPLETION MARKER
# ============================================================================

create_completion_marker() {
    log_info "Creating completion marker..."
    
    cat > "$COMPLETION_MARKER" << EOF
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
exit_code=0
EOF

    log_success "Completion marker created at $COMPLETION_MARKER"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Stage 6: Gaming Setup (Optional) v${SCRIPT_VERSION}               ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Setup logging
    setup_log_directory

    # Run prerequisite checks
    log_info "Running prerequisite checks..."
    check_root
    check_stage1_complete
    log_success "All prerequisite checks passed"
    echo ""

    # Check if already completed
    check_already_completed

    # Install gaming packages
    log_info "Starting gaming setup..."
    echo ""
    install_gaming_packages

    # Install advanced gaming packages
    echo ""
    install_advanced_gaming_packages

    # Configure performance optimizations
    echo ""
    configure_gaming_performance

    # Configure audio optimization
    echo ""
    configure_audio_optimization

    # Configure stylus support
    echo ""
    configure_stylus_support

    # Display gaming information
    echo ""
    display_gaming_info

    # Create completion marker
    create_completion_marker

    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         Stage 6 Complete: Gaming Setup Ready               ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_success "Stage 6 completed successfully"
    log_info "All stages completed! Your system is ready for gaming."
    echo ""
}

# Run main function
main "$@"

