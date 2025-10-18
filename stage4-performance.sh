#!/bin/bash

################################################################################
# Stage 4: Performance Optimizations
# 
# Installs and configures performance optimization tools
# - auto-cpufreq (CPU frequency scaling)
# - Gaming performance tweaks
# - ADIOS I/O scheduler
# - RCU Lazy kernel parameter
# - Multimedia codecs and hardware acceleration
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
readonly LOG_FILE="$LOG_DIR/stage4.log"
readonly COMPLETION_MARKER="$LOG_DIR/stage4.complete"

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
        log_error "This script must be run as root (use: sudo ./stage4-performance.sh)"
        exit 1
    fi
}

check_already_completed() {
    if [[ -f "$COMPLETION_MARKER" ]]; then
        log_info "Stage 4 already completed. Use --force to re-run."
        exit 0
    fi
}

# ============================================================================
# PERFORMANCE OPTIMIZATIONS
# ============================================================================

setup_log_directory() {
    mkdir -p "$LOG_DIR" || {
        log_error "Failed to create log directory"
        exit 1
    }
}

install_auto_cpufreq() {
    log_info "Installing auto-cpufreq for CPU frequency scaling and power management..."
    echo ""

    # Check if auto-cpufreq is already installed
    if command -v auto-cpufreq &>/dev/null; then
        log_success "auto-cpufreq is already installed"
        return 0
    fi

    # Create temporary directory for cloning
    local temp_dir
    temp_dir=$(mktemp -d) || {
        log_error "Failed to create temporary directory"
        return 0
    }

    log_info "Cloning auto-cpufreq repository..."
    git clone https://github.com/AdnanHodzic/auto-cpufreq.git "$temp_dir" 2>&1 | tail -3 || {
        log_warn "Failed to clone auto-cpufreq repository"
        rm -rf "$temp_dir"
        return 0
    }

    # Change to the cloned directory
    cd "$temp_dir" || {
        log_warn "Failed to change to auto-cpufreq directory"
        rm -rf "$temp_dir"
        return 0
    }

    # Run the installer
    log_info "Running auto-cpufreq installer..."
    bash ./auto-cpufreq-installer 2>&1 | tail -5 || {
        log_warn "auto-cpufreq installer had warnings"
    }

    # Clean up temporary directory
    cd - >/dev/null || true
    rm -rf "$temp_dir"

    # Install and enable the daemon
    log_info "Installing auto-cpufreq daemon service..."
    auto-cpufreq --install 2>&1 | tail -3 || {
        log_warn "auto-cpufreq --install had warnings"
    }

    echo ""

    # Verify installation
    sleep 2

    if command -v auto-cpufreq &>/dev/null; then
        log_success "auto-cpufreq binary verified"

        # Check service status
        log_info "Checking auto-cpufreq service status..."
        if systemctl is-active --quiet auto-cpufreq; then
            log_success "auto-cpufreq service is running"
        else
            log_warn "auto-cpufreq service is not running"
            log_info "Attempting to start service..."
            systemctl start auto-cpufreq 2>&1 | tail -3 || true

            # Check again
            sleep 1
            if systemctl is-active --quiet auto-cpufreq; then
                log_success "auto-cpufreq service started successfully"
            else
                log_warn "auto-cpufreq service still not running"
            fi
        fi
    else
        log_warn "auto-cpufreq binary not found"
    fi

    echo ""
    return 0
}

configure_auto_cpufreq_surface() {
    log_info "Configuring auto-cpufreq for Surface Pro 9..."
    echo ""

    local config_file="/etc/auto-cpufreq.conf"
    local config_backup="${config_file}.backup.$(date +%s)"

    # Backup existing configuration if it exists
    if [[ -f "$config_file" ]]; then
        log_info "Backing up existing auto-cpufreq configuration..."
        cp "$config_file" "$config_backup" || {
            log_error "Failed to backup auto-cpufreq configuration"
            return 1
        }
        log_success "Configuration backed up to $config_backup"
    fi

    # Create optimized Surface Pro 9 configuration
    log_info "Creating Surface Pro 9 optimized configuration..."

    cat > "$config_file" << 'EOF'
# auto-cpufreq configuration for Surface Pro 9
# Optimized for battery life and performance balance

[charger]
governor = performance
scaling_min_freq = 800000
scaling_max_freq = 4800000
turbo = auto

[battery]
governor = powersave
scaling_min_freq = 800000
scaling_max_freq = 2400000
turbo = never

[intel_pstate]
min_perf_pct = 0
max_perf_pct = 100
no_turbo = 0
EOF

    if [[ ! -f "$config_file" ]]; then
        log_error "Failed to create auto-cpufreq configuration file"
        return 1
    fi

    chmod 644 "$config_file" || {
        log_error "Failed to set permissions on auto-cpufreq configuration"
        return 1
    }

    log_success "Surface Pro 9 configuration created at $config_file"
    echo ""
}

apply_gaming_tweaks() {
    log_info "Applying gaming performance tweaks..."

    local gaming_conf="/etc/sysctl.d/99-gaming-tweaks.conf"

    if [[ -f "$gaming_conf" ]]; then
        log_warn "Gaming tweaks already applied"
        return 0
    fi

    log_info "Creating gaming performance configuration..."
    cat > "$gaming_conf" << 'EOF'
# Gaming Performance Tweaks
# Disable split lock mitigate for better gaming performance
kernel.split_lock_mitigate=0
EOF

    # Apply sysctl settings
    sysctl -p "$gaming_conf" >/dev/null 2>&1 || {
        log_error "Failed to apply gaming tweaks"
        return 1
    }

    log_success "Gaming performance tweaks applied"
}

apply_adios_scheduler() {
    log_info "Configuring ADIOS I/O scheduler..."

    local io_rules="/etc/udev/rules.d/60-ioschedulers.conf"

    if grep -q "adios" "$io_rules" 2>/dev/null; then
        log_warn "ADIOS scheduler already configured"
        return 0
    fi

    log_info "Updating I/O scheduler rules to use ADIOS..."

    # Backup existing rules
    if [[ -f "$io_rules" ]]; then
        cp "$io_rules" "${io_rules}.backup.$(date +%s)"
    fi

    # Update NVMe rules to use ADIOS
    sed -i 's/scheduler}="none"/scheduler}="adios"/g' "$io_rules" 2>/dev/null || true

    # Reload udev rules
    udevadm control --reload-rules >/dev/null 2>&1
    udevadm trigger >/dev/null 2>&1

    log_success "ADIOS I/O scheduler configured"
}

apply_rcu_lazy() {
    log_info "Enabling RCU Lazy for power management..."

    local grub_file="/etc/default/grub"

    if grep -q "rcutree.enable_rcu_lazy=1" "$grub_file"; then
        log_warn "RCU Lazy already enabled"
        return 0
    fi

    log_info "Adding RCU Lazy kernel parameter..."

    # Backup GRUB configuration
    cp "$grub_file" "${grub_file}.backup.rcu.$(date +%s)"

    # Add RCU Lazy parameter
    sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="rcutree.enable_rcu_lazy=1 /' "$grub_file"

    # Regenerate GRUB configuration
    grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null 2>&1 || {
        log_warn "Failed to regenerate GRUB configuration"
    }

    log_success "RCU Lazy enabled (requires reboot)"
}

install_multimedia_codecs() {
    log_info "Installing multimedia codecs and hardware acceleration..."

    # Check if already installed
    if rpm -q gstreamer1-plugins-good >/dev/null 2>&1; then
        log_warn "Multimedia codecs already installed"
        return 0
    fi

    log_info "Installing gstreamer plugins and ffmpeg..."
    dnf install -y \
        gstreamer1-plugins-good \
        gstreamer1-plugins-bad-free \
        gstreamer1-plugins-ugly-free \
        gstreamer1-libav \
        ffmpeg \
        2>&1 | grep -E "^(Installing|Updating)" || true

    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        log_error "Failed to install multimedia codecs"
        return 1
    fi

    log_success "Multimedia codecs installed"
}

enable_hardware_video_acceleration() {
    log_info "Enabling hardware video acceleration..."

    # Check if already installed
    if rpm -q libva-intel-driver >/dev/null 2>&1; then
        log_warn "Hardware video acceleration already enabled"
        return 0
    fi

    log_info "Installing Intel hardware acceleration drivers..."
    dnf install -y libva-intel-driver intel-media-driver 2>&1 | grep -E "^(Installing|Updating)" || true

    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        log_warn "Failed to install hardware acceleration drivers"
        return 0
    fi

    # Create hardware acceleration profile
    local hw_accel_profile="/etc/profile.d/hardware-acceleration.sh"
    if [[ ! -f "$hw_accel_profile" ]]; then
        cat > "$hw_accel_profile" << 'EOF'
# Hardware Video Acceleration
export LIBVA_DRIVER_NAME=iHD
export VDPAU_DRIVER=va_gl
EOF
        chmod 644 "$hw_accel_profile"
    fi

    log_success "Hardware video acceleration enabled"
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
    echo -e "${BLUE}║  Stage 4: Performance Optimizations v${SCRIPT_VERSION}              ║${NC}"
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

    # Apply optimizations
    log_info "Starting performance optimizations..."
    echo ""
    install_auto_cpufreq
    configure_auto_cpufreq_surface
    apply_gaming_tweaks
    apply_adios_scheduler
    apply_rcu_lazy
    install_multimedia_codecs
    enable_hardware_video_acceleration
    echo ""

    # Create completion marker
    create_completion_marker

    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      Stage 4 Complete: Performance Optimizations Ready     ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_success "Stage 4 completed successfully"
    log_info "Next step: Run Stage 5 (Desktop Environment)"
    echo ""
}

# Run main function
main "$@"

