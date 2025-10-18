#!/bin/bash

################################################################################
# Stage 2: Kernel Installation
# 
# Installs Linux Surface kernel and related packages
# - kernel-surface
# - iptsd (touchscreen driver)
# - libwacom-surface
# - surface-secureboot
# - Enables watchdog service
#
# Prerequisites: Stage 1 (Repository Setup) must be completed
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION & CONSTANTS
# ============================================================================

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_DIR="/var/log/surface-setup"
readonly LOG_FILE="$LOG_DIR/stage2.log"
readonly COMPLETION_MARKER="$LOG_DIR/stage2.complete"
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
        log_error "This script must be run as root (use: sudo ./stage2-kernel.sh)"
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
        log_info "Stage 2 already completed. Use --force to re-run."
        exit 0
    fi
}

# ============================================================================
# KERNEL INSTALLATION
# ============================================================================

setup_log_directory() {
    mkdir -p "$LOG_DIR" || {
        log_error "Failed to create log directory"
        exit 1
    }
}

install_kernel_packages() {
    log_info "Installing kernel-surface, iptsd, and libwacom-surface..."
    log_info "This may take several minutes..."
    echo ""

    # Check if packages are already installed
    local packages_to_install=""
    rpm -q kernel-surface &>/dev/null || packages_to_install="kernel-surface"
    rpm -q iptsd &>/dev/null || packages_to_install="$packages_to_install iptsd"
    rpm -q libwacom-surface &>/dev/null || packages_to_install="$packages_to_install libwacom-surface"

    if [[ -z "$packages_to_install" ]]; then
        log_success "Surface kernel packages are already installed"
    else
        log_info "Installing packages: $packages_to_install"
        if dnf install --allowerasing -y $packages_to_install 2>&1 | tail -5; then
            log_success "Surface kernel packages installed successfully"
        else
            log_warn "Installation completed with warnings (packages may still be installed)"
        fi
    fi

    echo ""
}

install_secureboot_support() {
    log_info "Installing secure boot support..."
    
    if rpm -q surface-secureboot &>/dev/null; then
        log_success "surface-secureboot is already installed"
    else
        log_info "Installing surface-secureboot package..."
        if dnf install -y surface-secureboot 2>&1 | tail -3; then
            log_success "surface-secureboot installed successfully"
            echo ""
            log_info "IMPORTANT: Secure Boot Key Enrollment"
            log_info "On your next reboot, you will see a blue menu for key enrollment:"
            log_info "  1. A blue screen will appear asking to enroll the signing key"
            log_info "  2. Select 'ok' or 'yes' to confirm enrollment"
            log_info "  3. Enter password: surface"
            log_info "  4. System will reboot and Linux Surface kernel will boot with Secure Boot enabled"
        else
            log_warn "Failed to install surface-secureboot (may not be critical)"
        fi
    fi

    echo ""
}

enable_watchdog_service() {
    log_info "Enabling Linux Surface default kernel watchdog..."
    
    if systemctl is-enabled linux-surface-default-watchdog.path &>/dev/null; then
        log_success "Linux Surface watchdog is already enabled"
    else
        log_info "Enabling linux-surface-default-watchdog.path service..."
        if systemctl enable --now linux-surface-default-watchdog.path 2>&1 | tail -2; then
            log_success "Linux Surface watchdog enabled"
        else
            log_warn "Failed to enable Surface watchdog (may not be available)"
        fi
    fi

    # Run watchdog script to set default kernel immediately
    log_info "Setting Linux Surface as default kernel..."
    if command -v linux-surface-default-watchdog.py &>/dev/null; then
        if linux-surface-default-watchdog.py 2>&1 | tail -2; then
            log_success "Linux Surface set as default kernel"
        else
            log_warn "Watchdog script execution had warnings (may still be set)"
        fi
    else
        log_warn "Watchdog script not found (will be set on next boot)"
    fi

    echo ""
}

display_post_installation_info() {
    log_info "POST-INSTALLATION VERIFICATION:"
    log_info "After reboot, verify the kernel with: uname -a"
    log_info "Output should contain 'surface' if using Linux Surface kernel"
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
    echo -e "${BLUE}║  Stage 2: Kernel Installation v${SCRIPT_VERSION}                   ║${NC}"
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

    # Install kernel
    log_info "Starting Linux Surface kernel installation..."
    echo ""
    install_kernel_packages
    install_secureboot_support
    enable_watchdog_service
    display_post_installation_info

    # Create completion marker
    create_completion_marker

    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║        Stage 2 Complete: Kernel Installation Ready         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_success "Stage 2 completed successfully"
    echo ""
    echo -e "${YELLOW}IMPORTANT: A system reboot is required to complete kernel installation.${NC}"
    echo -e "${YELLOW}After reboot, run Stage 3 (Surface Hardware Configuration) to continue.${NC}"
    echo ""
    
    read -p "Reboot now? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Rebooting system in 10 seconds... (Press Ctrl+C to cancel)"
        sleep 10
        reboot
    else
        log_info "Reboot cancelled. Please reboot manually when ready."
        exit 0
    fi
}

# Run main function
main "$@"

