#!/bin/bash

################################################################################
# Stage 5: Desktop Environment
# 
# Configures desktop environment and installs essential applications
# - rEFInd bootloader installation
# - rEFInd nils theme configuration
# - GNOME customizations
# - Essential applications (Vesktop, Steam)
#
# Prerequisites: None (can run independently)
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION & CONSTANTS
# ============================================================================

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_DIR="/var/log/surface-setup"
readonly LOG_FILE="$LOG_DIR/stage5.log"
readonly COMPLETION_MARKER="$LOG_DIR/stage5.complete"

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
        log_error "This script must be run as root (use: sudo ./stage5-desktop.sh)"
        exit 1
    fi
}

check_already_completed() {
    if [[ -f "$COMPLETION_MARKER" ]]; then
        log_info "Stage 5 already completed. Use --force to re-run."
        exit 0
    fi
}

# ============================================================================
# DESKTOP ENVIRONMENT SETUP
# ============================================================================

setup_log_directory() {
    mkdir -p "$LOG_DIR" || {
        log_error "Failed to create log directory"
        exit 1
    }
}

install_refind() {
    log_info "Installing rEFInd bootloader..."

    # Check if rEFInd is already installed
    if [[ -d /boot/efi/EFI/refind ]]; then
        log_warn "rEFInd is already installed"
        return 0
    fi

    # Install rEFInd package
    log_info "Installing rEFInd package..."
    dnf install -y refind 2>&1 | grep -E "^(Installing|Updating)" || true

    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        log_error "Failed to install rEFInd package"
        return 1
    fi

    log_success "rEFInd package installed"
}

configure_refind_theme() {
    log_info "Configuring rEFInd with nils theme..."

    local refind_dir="/boot/efi/EFI/refind"
    local themes_dir="$refind_dir/themes"

    # Create themes directory if it doesn't exist
    if [[ ! -d "$themes_dir" ]]; then
        mkdir -p "$themes_dir" || {
            log_error "Failed to create rEFInd themes directory"
            return 1
        }
    fi

    # Check if nils theme is already installed
    if [[ -d "$themes_dir/rEFInd-nils" ]]; then
        log_warn "rEFInd-nils theme is already installed"
    else
        log_info "Downloading rEFInd-nils theme..."

        # Clone the theme repository
        cd "$themes_dir" || return 1
        git clone https://github.com/NilsPvR/rEFInd-nils.git >/dev/null 2>&1 || {
            log_warn "Failed to download rEFInd-nils theme (git may not be installed)"
            cd - >/dev/null
            return 0
        }
        cd - >/dev/null

        log_success "rEFInd-nils theme installed"
    fi

    # Update refind.conf to use the nils theme
    local refind_conf="$refind_dir/refind.conf"
    if [[ -f "$refind_conf" ]]; then
        # Check if theme is already configured
        if ! grep -q "include themes/rEFInd-nils" "$refind_conf"; then
            log_info "Configuring rEFInd to use nils theme..."

            # Add theme configuration
            echo "" >> "$refind_conf"
            echo "# rEFInd-nils theme configuration" >> "$refind_conf"
            echo "include themes/rEFInd-nils/theme.conf" >> "$refind_conf"

            log_success "rEFInd theme configuration updated"
        fi
    fi
}

apply_gnome_tweaks() {
    log_info "Applying GNOME desktop customizations..."
    echo ""

    # Check if GNOME is installed
    if ! command -v gsettings &>/dev/null; then
        log_warn "GNOME not detected, skipping GNOME customizations"
        return 0
    fi

    # Install gnome-tweaks if not already installed
    if ! rpm -q gnome-tweaks &>/dev/null; then
        log_info "Installing gnome-tweaks package..."
        dnf install -y gnome-tweaks 2>&1 | tail -3 || {
            log_warn "Failed to install gnome-tweaks"
        }
    else
        log_success "gnome-tweaks is already installed"
    fi

    echo ""
    log_info "Configuring GNOME desktop settings..."

    # Restore window control buttons (minimize, maximize, close)
    log_info "Restoring window control buttons..."
    gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close' 2>/dev/null || true

    # Interface improvements
    log_info "Configuring interface settings..."
    gsettings set org.gnome.desktop.interface show-battery-percentage true 2>/dev/null || true
    gsettings set org.gnome.desktop.interface clock-format '12h' 2>/dev/null || true

    # Mouse and touchpad settings
    log_info "Configuring mouse and touchpad..."
    gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'flat' 2>/dev/null || true
    gsettings set org.gnome.desktop.peripherals.mouse natural-scroll true 2>/dev/null || true

    # Disable hot corners (better for touchscreen)
    log_info "Disabling hot corners (better for touchscreen)..."
    gsettings set org.gnome.desktop.interface enable-hot-corners false 2>/dev/null || true

    # Mutter window manager improvements
    log_info "Configuring window manager..."
    gsettings set org.gnome.mutter dynamic-workspaces true 2>/dev/null || true
    gsettings set org.gnome.mutter edge-tiling true 2>/dev/null || true

    # Night light settings
    log_info "Enabling night light..."
    gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true 2>/dev/null || true
    gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-automatic true 2>/dev/null || true

    # Power management
    log_info "Configuring power management..."
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 1800 2>/dev/null || true
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'suspend' 2>/dev/null || true
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 900 2>/dev/null || true
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'suspend' 2>/dev/null || true

    # Privacy settings
    log_info "Configuring privacy settings..."
    gsettings set org.gnome.desktop.privacy remember-recent-files false 2>/dev/null || true
    gsettings set org.gnome.desktop.privacy remove-old-temp-files true 2>/dev/null || true
    gsettings set org.gnome.desktop.privacy remove-old-trash-files true 2>/dev/null || true

    # File manager settings
    log_info "Configuring file manager..."
    gsettings set org.gnome.nautilus.preferences click-policy 'single' 2>/dev/null || true

    # Location services
    log_info "Enabling location services..."
    gsettings set org.gnome.system.location enabled true 2>/dev/null || true

    # File chooser settings
    log_info "Configuring file chooser..."
    gsettings set org.gtk.settings.file-chooser clock-format '12h' 2>/dev/null || true
    gsettings set org.gtk.settings.file-chooser show-hidden false 2>/dev/null || true

    echo ""
    log_success "GNOME desktop customizations applied"
    return 0
}

install_vesktop() {
    log_info "Installing Vesktop (Discord client)..."
    
    # Check if already installed
    if dnf list installed vesktop >/dev/null 2>&1; then
        log_warn "Vesktop is already installed"
        return 0
    fi
    
    # Add Flathub repository if not present
    if ! flatpak remote-list | grep -q flathub; then
        log_info "Adding Flathub repository..."
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || {
            log_warn "Failed to add Flathub repository"
        }
    fi
    
    # Install via Flatpak
    flatpak install -y flathub dev.vencord.Vesktop >/dev/null 2>&1 || {
        log_error "Failed to install Vesktop"
        return 1
    }
    
    log_success "Vesktop installed successfully"
}

install_steam() {
    log_info "Installing Steam..."
    
    # Check if already installed
    if dnf list installed steam >/dev/null 2>&1; then
        log_warn "Steam is already installed"
        return 0
    fi
    
    # Enable RPM Fusion repositories (required for Steam)
    log_info "Enabling RPM Fusion repositories..."
    dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
                     https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm >/dev/null 2>&1 || {
        log_warn "Failed to enable RPM Fusion repositories"
    }
    
    # Install Steam
    dnf install -y steam >/dev/null 2>&1 || {
        log_error "Failed to install Steam"
        return 1
    }
    
    log_success "Steam installed successfully"
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
    echo -e "${BLUE}║  Stage 5: Desktop Environment v${SCRIPT_VERSION}                  ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Setup logging
    setup_log_directory

    # Run prerequisite checks
    log_info "Running prerequisite checks..."
    check_root
    log_success "All prerequisite checks passed"
    echo ""

    # Check if already completed
    check_already_completed

    # Configure desktop environment
    log_info "Starting desktop environment configuration..."
    echo ""
    install_refind
    configure_refind_theme
    apply_gnome_tweaks
    install_vesktop
    install_steam
    echo ""

    # Create completion marker
    create_completion_marker

    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      Stage 5 Complete: Desktop Environment Ready           ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_success "Stage 5 completed successfully"
    log_info "Next step: Run Stage 6 (Gaming Setup) - Optional"
    echo ""
}

# Run main function
main "$@"

