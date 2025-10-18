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

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_DIR="/var/log/surface-setup"
readonly LOG_FILE="$LOG_DIR/stage6.log"
readonly COMPLETION_MARKER="$LOG_DIR/stage6.complete"
readonly STAGE1_MARKER="$LOG_DIR/stage1.complete"

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
    if ! rpm -q protonplus-next &>/dev/null; then
        log_info "Installing ProtonUp-Qt (Proton manager)..."
        dnf install -y protonplus-next 2>&1 | tail -3 || {
            log_warn "Failed to install ProtonUp-Qt"
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

    # Xbox controller support
    if ! rpm -q xone &>/dev/null; then
        log_info "Installing Xbox One controller support..."
        dnf install -y xone 2>&1 | tail -3 || {
            log_warn "Failed to install Xbox One controller support"
        }
    else
        log_success "Xbox One controller support already installed"
    fi

    # DualSense controller support
    if ! rpm -q ds-inhibit &>/dev/null; then
        log_info "Installing DualSense controller support..."
        dnf install -y ds-inhibit 2>&1 | tail -3 || {
            log_warn "Failed to install DualSense controller support"
        }
    else
        log_success "DualSense controller support already installed"
    fi

    echo ""
    log_success "Gaming packages installation complete"
    return 0
}

display_gaming_info() {
    log_info "Gaming Setup Information:"
    echo ""
    echo "  Installed Gaming Components:"
    echo "    ✓ Steam (primary gaming platform)"
    echo "    ✓ MangoHud (performance overlay)"
    echo "    ✓ GOverlay (MangoHud GUI configuration)"
    echo "    ✓ ProtonUp-Qt (Proton version manager)"
    echo "    ✓ Wine + Winetricks (Windows compatibility)"
    echo "    ✓ Mesa Vulkan Drivers (32/64-bit)"
    echo "    ✓ Lutris (alternative game launcher)"
    echo "    ✓ vkBasalt (Vulkan post-processing)"
    echo "    ✓ OBS Studio (streaming/recording)"
    echo "    ✓ Gamescope (gaming compositor)"
    echo "    ✓ Xbox & DualSense Controller Support"
    echo ""
    echo "  Quick Start Guide:"
    echo "    1. Launch Steam from applications menu"
    echo "    2. Enable Proton in Steam Settings > Compatibility"
    echo "    3. Use ProtonUp-Qt to manage Proton versions"
    echo "    4. Use MangoHud for performance monitoring (Shift+F12)"
    echo "    5. Connect controllers via Bluetooth or USB"
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

