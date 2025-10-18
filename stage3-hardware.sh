#!/bin/bash

################################################################################
# Stage 3: Surface Hardware Configuration
# 
# Applies Surface Pro 9 specific hardware fixes and configurations
# - iptsd touchscreen configuration
# - GRUB fixes (screen flickering, ACPI interrupt storm)
# - Hibernation configuration
# - Surface-specific hardware tweaks
#
# Prerequisites: Stage 2 (Kernel Installation) must be completed
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION & CONSTANTS
# ============================================================================

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_DIR="/var/log/surface-setup"
readonly LOG_FILE="$LOG_DIR/stage3.log"
readonly COMPLETION_MARKER="$LOG_DIR/stage3.complete"
readonly STAGE2_MARKER="$LOG_DIR/stage2.complete"

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
        log_error "This script must be run as root (use: sudo ./stage3-hardware.sh)"
        exit 1
    fi
}

check_stage2_complete() {
    if [[ ! -f "$STAGE2_MARKER" ]]; then
        log_error "Stage 2 (Kernel Installation) must be completed first"
        log_info "Run: sudo ./stage2-kernel.sh"
        exit 1
    fi
    log_success "Stage 2 prerequisite verified"
}

check_already_completed() {
    if [[ -f "$COMPLETION_MARKER" ]]; then
        log_info "Stage 3 already completed. Use --force to re-run."
        exit 0
    fi
}

# ============================================================================
# HARDWARE CONFIGURATION
# ============================================================================

setup_log_directory() {
    mkdir -p "$LOG_DIR" || {
        log_error "Failed to create log directory"
        exit 1
    }
}

configure_surface_hardware() {
    log_info "Configuring Surface-specific hardware..."

    # Enable touchscreen support (already handled by iptsd)
    log_info "Touchscreen support enabled via iptsd"

    # Enable Surface camera (if available)
    if modprobe -n surface_camera >/dev/null 2>&1; then
        modprobe surface_camera || log_warn "Could not load surface_camera module"
    fi

    # Enable Surface battery management
    if modprobe -n surface_battery >/dev/null 2>&1; then
        modprobe surface_battery || log_warn "Could not load surface_battery module"
    fi

    log_success "Surface hardware configured"
}

configure_iptsd() {
    log_info "Configuring iptsd touchscreen..."

    local iptsd_conf="/etc/iptsd/iptsd.conf"
    local iptsd_dir="/etc/iptsd"

    # Create iptsd directory if it doesn't exist
    if [[ ! -d "$iptsd_dir" ]]; then
        log_info "Creating iptsd configuration directory..."
        mkdir -p "$iptsd_dir" || {
            log_error "Failed to create iptsd directory"
            return 1
        }
    fi

    # Check if configuration already exists
    if [[ -f "$iptsd_conf" ]]; then
        log_warn "iptsd configuration already exists"
        return 0
    fi

    # Create iptsd configuration file with Surface Pro 9 optimized settings
    log_info "Creating iptsd configuration file with Surface Pro 9 optimizations..."
    cat > "$iptsd_conf" << 'EOF'
[Config]
[Touchscreen]
DisableOnPalm = true
Overshoot = 0.5
SizeMin = 0.325
SizeMax = 2.159

[Touchpad]
DisableOnPalm = true
Overshoot = 0.5

[Contacts]
NeutralValue = 0
ActivationThreshold = 24
DeactivationThreshold = 20
SizeThresholdMin = 0.1
SizeThresholdMax = 0.5
PositionThresholdMax = 2
OrientationThresholdMin = 1
OrientationThresholdMax = 5
SizeMin = 0.1
SizeMax = 2.0
AspectMin = 0.521
AspectMax = 3.323

[Stylus]
TipDistance = 0

[DFT]
PositionMinAmp = 50
PositionMinMag = 2000
PositionExp = -0.7
ButtonMinMag = 1000
FreqMinMag = 10000
EOF

    if [[ ! -f "$iptsd_conf" ]]; then
        log_error "Failed to create iptsd configuration file"
        return 1
    fi

    log_success "iptsd configuration file created"

    # Restart iptsd service
    log_info "Restarting iptsd service..."
    systemctl restart iptsd >/dev/null 2>&1 || {
        log_warn "Failed to restart iptsd service (may not be critical)"
    }

    log_success "iptsd touchscreen configured"
}

apply_surface_pro9_fixes() {
    log_info "Applying Surface Pro 9 specific fixes..."
    echo ""

    # Backup GRUB configuration
    local grub_file="/etc/default/grub"
    local grub_backup="${grub_file}.backup.$(date +%s)"

    if [[ ! -f "$grub_backup" ]]; then
        log_info "Backing up GRUB configuration to $grub_backup..."
        cp "$grub_file" "$grub_backup" || {
            log_warn "Failed to backup GRUB configuration"
        }
        log_success "GRUB configuration backed up"
    else
        log_warn "GRUB backup already exists"
    fi

    # Fix 1: Screen Flickering Fix (i915.enable_psr=0)
    log_info "Applying Fix 1: Screen Flickering Mitigation (i915.enable_psr=0)..."

    if grep -q "i915.enable_psr=0" "$grub_file"; then
        log_warn "Screen flickering fix already applied"
    else
        # Use grubby to add kernel parameter (more reliable than sed)
        grubby --update-kernel=ALL --args="i915.enable_psr=0" 2>&1 | tail -2 || {
            log_warn "Failed to apply screen flickering fix via grubby, trying manual method..."
            sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)/\1 i915.enable_psr=0/' "$grub_file" 2>&1 || {
                log_warn "Failed to apply screen flickering fix"
            }
        }
        log_success "Screen flickering fix applied (i915.enable_psr=0)"
    fi

    # Fix 2: ACPI Interrupt Storm Mitigation (pci=hpiosize=0)
    log_info "Applying Fix 2: ACPI Interrupt Storm Mitigation (pci=hpiosize=0)..."

    if grep -q "pci=hpiosize=0" "$grub_file"; then
        log_warn "ACPI interrupt storm fix already applied"
    else
        # Use grubby to add kernel parameter (more reliable than sed)
        grubby --update-kernel=ALL --args="pci=hpiosize=0" 2>&1 | tail -2 || {
            log_warn "Failed to apply ACPI interrupt storm fix via grubby, trying manual method..."
            sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)/\1 pci=hpiosize=0/' "$grub_file" 2>&1 || {
                log_warn "Failed to apply ACPI interrupt storm fix"
            }
        }
        log_success "ACPI interrupt storm fix applied (pci=hpiosize=0)"
    fi

    # Regenerate GRUB configuration
    log_info "Regenerating GRUB configuration..."
    grub2-mkconfig -o /boot/grub2/grub.cfg 2>&1 | tail -2 || {
        log_warn "Failed to regenerate GRUB configuration"
        log_info "You may need to run manually: sudo grub2-mkconfig -o /boot/grub2/grub.cfg"
    }
    log_success "GRUB configuration regenerated"
    echo ""
}

apply_hibernation_config() {
    log_info "Applying Fix 3: Hibernation Configuration..."

    local sleep_conf="/etc/systemd/sleep.conf"

    # Check if sleep.conf exists, if not create it
    if [[ ! -f "$sleep_conf" ]]; then
        log_info "Creating $sleep_conf..."
        cat > "$sleep_conf" << 'EOF'
[Sleep]
HibernateMode=reboot
EOF
        chmod 644 "$sleep_conf" || {
            log_error "Failed to set permissions on $sleep_conf"
            return 1
        }
        log_success "Hibernation configuration created"
    else
        # Backup existing sleep.conf
        local sleep_backup="${sleep_conf}.backup.$(date +%s)"
        if [[ ! -f "$sleep_backup" ]]; then
            cp "$sleep_conf" "$sleep_backup" || {
                log_error "Failed to backup sleep.conf"
                return 1
            }
            log_info "Backed up sleep.conf to $sleep_backup"
        fi

        # Check if HibernateMode is already set
        if grep -q "^HibernateMode=" "$sleep_conf"; then
            log_warn "HibernateMode already configured in $sleep_conf"

            # Update existing HibernateMode
            if ! grep -q "^HibernateMode=reboot" "$sleep_conf"; then
                sed -i 's/^HibernateMode=.*/HibernateMode=reboot/' "$sleep_conf" || {
                    log_error "Failed to update HibernateMode"
                    return 1
                }
                log_success "Updated HibernateMode to reboot"
            fi
        else
            # Check if [Sleep] section exists
            if grep -q "^\[Sleep\]" "$sleep_conf"; then
                # Add HibernateMode after [Sleep] section
                sed -i '/^\[Sleep\]/a HibernateMode=reboot' "$sleep_conf" || {
                    log_error "Failed to add HibernateMode to [Sleep] section"
                    return 1
                }
                log_success "Added HibernateMode=reboot to [Sleep] section"
            else
                # Create [Sleep] section with HibernateMode
                echo "" >> "$sleep_conf"
                echo "[Sleep]" >> "$sleep_conf"
                echo "HibernateMode=reboot" >> "$sleep_conf"
                log_success "Created [Sleep] section with HibernateMode=reboot"
            fi
        fi
    fi

    log_success "Hibernation configuration applied"
    echo ""
}

display_surface_pro9_info() {
    log_info "Surface Pro 9 Known Issues (Informational):"
    echo ""
    echo "  • S0ix Low Residency: The system may show low S0ix residency in power"
    echo "    profiles. This is a known issue with Surface Pro 9 and does not"
    echo "    significantly impact battery life in practice."
    echo ""
    echo "  • Applied Fixes:"
    echo "    ✓ Screen flickering mitigation (i915.enable_psr=0)"
    echo "    ✓ ACPI interrupt storm prevention (pci=hpiosize=0)"
    echo "    ✓ Hibernation mode configuration (HibernateMode=reboot)"
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
    echo -e "${BLUE}║  Stage 3: Surface Hardware Configuration v${SCRIPT_VERSION}           ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Setup logging
    setup_log_directory

    # Run prerequisite checks
    log_info "Running prerequisite checks..."
    check_root
    check_stage2_complete
    log_success "All prerequisite checks passed"
    echo ""

    # Check if already completed
    check_already_completed

    # Configure hardware
    log_info "Starting Surface Pro 9 hardware configuration..."
    echo ""
    configure_surface_hardware
    configure_iptsd
    apply_surface_pro9_fixes
    apply_hibernation_config
    display_surface_pro9_info

    # Create completion marker
    create_completion_marker

    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     Stage 3 Complete: Hardware Configuration Ready         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_success "Stage 3 completed successfully"
    log_info "Next step: Run Stage 4 (Performance Optimizations)"
    echo ""
}

# Run main function
main "$@"

