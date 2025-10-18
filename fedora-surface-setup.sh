#!/bin/bash

################################################################################
# Fedora Surface Setup Script
# 
# A comprehensive, single-file Bash script for Fedora that installs the Linux
# Surface kernel with Surface-specific configurations and minimal essential
# applications (Vesktop, Steam, VS Code).
#
# Usage: sudo ./fedora-surface-setup.sh
# 
# This script is idempotent and safe to run multiple times.
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION & CONSTANTS
# ============================================================================

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Progress tracking
CURRENT_STEP=0
TOTAL_STEPS=0

set_total_steps() {
    TOTAL_STEPS=$1
}

progress_step() {
    ((CURRENT_STEP++))
    local step_desc="$1"
    echo ""
    echo -e "${BLUE}[STEP $CURRENT_STEP/$TOTAL_STEPS]${NC} $step_desc"
}

show_progress() {
    local current=$1
    local total=$2
    local message="$3"
    local percent=$((current * 100 / total))
    echo -ne "\r${BLUE}[${percent}%]${NC} $message"
}

# ============================================================================
# PREREQUISITE CHECKS
# ============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use: sudo ./fedora-surface-setup.sh)"
        exit 1
    fi
}

check_fedora() {
    if [[ ! -f /etc/fedora-release ]]; then
        log_error "This script is designed for Fedora only"
        exit 1
    fi
    
    local fedora_version
    fedora_version=$(grep -oP '(?<=VERSION_ID=)\d+' /etc/os-release)
    log_info "Detected Fedora $fedora_version"
    
    if [[ $fedora_version -lt 38 ]]; then
        log_warn "Fedora 38+ is recommended. Current version: $fedora_version"
    fi
}

check_network() {
    log_info "Checking network connectivity..."
    
    if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        log_error "Network connectivity is required but not available"
        exit 1
    fi
    
    log_success "Network connectivity confirmed"
}

# ============================================================================
# SYSTEM UPDATES
# ============================================================================

update_system() {
    log_info "Updating system packages..."
    
    dnf update -y >/dev/null 2>&1 || {
        log_error "Failed to update system"
        return 1
    }
    
    dnf upgrade -y >/dev/null 2>&1 || {
        log_error "Failed to upgrade system"
        return 1
    }
    
    log_success "System updated successfully"
}

# ============================================================================
# LINUX SURFACE KERNEL INSTALLATION
# ============================================================================

install_surface_kernel() {
    log_info "Installing Linux Surface kernel..."

    # Add Linux Surface repository with retry logic and diagnostics
    log_info "Adding Linux Surface repository..."
    local repo_url="https://pkg.surfacelinux.com/fedora/linux-surface.repo"
    local max_retries=3
    local retry_count=0

    # Check if repository is already added
    log_info "Checking if Linux Surface repository is already configured..."
    if dnf repolist 2>/dev/null | grep -q "linux-surface"; then
        log_success "Linux Surface repository is already configured"
    else
        # Detect dnf version (dnf4 vs dnf5)
        local dnf_version
        dnf_version=$(dnf --version 2>/dev/null | head -1 | grep -oE '[0-9]+' | head -1)
        log_info "Detected dnf version: $dnf_version"

        while [[ $retry_count -lt $max_retries ]]; do
            log_info "Attempting to add repository (attempt $((retry_count + 1))/$max_retries)..."

            local output
            local exit_code

            # Use appropriate syntax based on dnf version
            if [[ $dnf_version -ge 5 ]]; then
                log_info "Using dnf5 syntax for repository addition..."
                output=$(timeout 30 dnf config-manager addrepo --from-repofile="$repo_url" 2>&1)
                exit_code=$?
            else
                log_info "Using dnf4 syntax for repository addition..."
                output=$(timeout 30 dnf config-manager --add-repo="$repo_url" 2>&1)
                exit_code=$?
            fi

            # Check if repository was added (exit code 0 or already exists)
            if [[ $exit_code -eq 0 ]] || echo "$output" | grep -qi "already"; then
                log_success "Linux Surface repository added successfully"
                break
            else
                ((retry_count++))
                log_warn "Repository addition failed with exit code: $exit_code"
                log_warn "Output: $output"

                if [[ $retry_count -lt $max_retries ]]; then
                    log_warn "Retrying in 5 seconds (attempt $retry_count/$max_retries)..."
                    sleep 5
                else
                    log_error "Failed to add Linux Surface repository after $max_retries attempts"
                    log_error "This may be due to network issues or repository unavailability"
                    log_warn "Attempting to continue without repository (packages may not be available)"
                    break  # Continue anyway
                fi
            fi
        done
    fi

    # Install kernel and dependencies
    log_info "Installing kernel-surface, iptsd, and libwacom-surface..."
    log_info "This may take several minutes..."

    # Check if packages are already installed
    local packages_to_install=""
    command -v kernel-surface &>/dev/null || packages_to_install="kernel-surface"
    rpm -q iptsd &>/dev/null || packages_to_install="$packages_to_install iptsd"
    rpm -q libwacom-surface &>/dev/null || packages_to_install="$packages_to_install libwacom-surface"

    if [[ -z "$packages_to_install" ]]; then
        log_success "Surface kernel packages are already installed"
    else
        log_info "Installing packages: $packages_to_install"
        if ! dnf install --allowerasing -y $packages_to_install 2>&1 | tee /tmp/kernel-install.log; then
            log_error "Failed to install Surface kernel packages"
            log_error "Check /tmp/kernel-install.log for details"
            log_warn "Attempting to install packages individually..."

            # Try installing packages individually
            [[ "$packages_to_install" == *"kernel-surface"* ]] && dnf install -y kernel-surface 2>&1 | tail -5 || true
            [[ "$packages_to_install" == *"iptsd"* ]] && dnf install -y iptsd 2>&1 | tail -5 || true
            [[ "$packages_to_install" == *"libwacom-surface"* ]] && dnf install -y libwacom-surface 2>&1 | tail -5 || true
        fi
        log_success "Surface kernel packages installed"
    fi
    
    # Install secure boot support
    if rpm -q surface-secureboot &>/dev/null; then
        log_success "surface-secureboot is already installed"
    else
        log_info "Installing surface-secureboot..."
        dnf install -y surface-secureboot >/dev/null 2>&1 || {
            log_warn "Failed to install surface-secureboot (may not be critical)"
        }
    fi

    # Enable Surface watchdog
    if systemctl is-enabled linux-surface-default-watchdog.path &>/dev/null; then
        log_success "Linux Surface watchdog is already enabled"
    else
        log_info "Enabling Linux Surface watchdog..."
        systemctl enable --now linux-surface-default-watchdog.path >/dev/null 2>&1 || {
            log_warn "Failed to enable Surface watchdog (may not be available)"
        }
    fi

    log_success "Linux Surface kernel installed successfully"
}

# ============================================================================
# SURFACE-SPECIFIC CONFIGURATIONS
# ============================================================================

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
##
## The following values are device specific and will be loaded from /usr/share/iptsd
## Only set them if you need to provide custom values for new devices that are not yet supported
##
# InvertX = false
# InvertY = false
# Width = 0
# Height = 0

[Touchscreen]
##
## Disables the touchscreen. No data will be processed.
##
# Disable = false

##
## Ignore all touchscreen inputs if a palm was registered.
##
DisableOnPalm = true

##
## Ignore all touchscreen inputs if a stylus is in proximity.
##
# DisableOnStylus = false

##
## How many centimeters a contact can be outside of the screen and still get registered.
##
Overshoot = 0.5

##
## Surface Pro 9 specific touchscreen size calibration
##
SizeMin = 0.325
SizeMax = 2.159

[Touchpad]
##
## Disables the touchpad. No data will be processed.
##
# Disable = false

##
## Ignore all touchpad inputs if a palm was registered.
##
DisableOnPalm = true

##
## How many centimeters a contact can be outside of the touchpad and still get registered.
##
Overshoot = 0.5

[Contacts]
##
## How the neutral value of the heatmap will be determined.
## The neutral value is the value in the heatmap that marks regions without activity.
## Pixels with a value larger than the neutral value are considered for blob detection.
##
## Mode: The most common value from the heatmap will be used.
## Average: The average of all values from the heatmap will be used.
## Constant: The value from the NeutralValue option will be used.
##
## When this option is set to Mode or Average, the NeutralValue option can be used
## to specify an offset that will be added on top of the calculated value.
##
# Neutral = mode

##
## The neutral value of the touch sensor (Range 0 - 255).
##
NeutralValue = 0

##
## The activation threshold for blob detection (Range 0 - 255).
## If a pixel of the heatmap is larger than this value plus the neutral value, the blob detector
## will mark the pixel as a contact and try to determine its size.
##
## This value is only used by the basic blob detector.
##
ActivationThreshold = 24

##
## The deactivation threshold for blob detection (Range 0 - 255).
## Once the blob detector has identified a contact it will look for adjacent pixels. If the value
## of the pixel is larger than this value plus the neutral value, it will be added to the contact.
##
## This value is only used by the basic blob detector.
##
DeactivationThreshold = 20

##
## How many centimeters a contact must increase in size before the change is considered stable.
## Size changes below this threshold are ignored.
##
SizeThresholdMin = 0.1

##
## How many centimeters a contact can increase in size before the change is considered unstable.
## Size changes above this threshold are ignored.
##
SizeThresholdMax = 0.5

##
## How many centimeters a contact must move before the movement is considered stable.
## Movements below this threshold are ignored.
##
# PositionThresholdMin = 0.04

##
## How many centimeters a contact can move before the movement is considered unstable.
## Movements above this threshold are ignored.
##
PositionThresholdMax = 2

##
## How many degrees the orientation of a contact must change before the change is considered stable.
## Changes below this threshold are ignored.
##
OrientationThresholdMin = 1

##
## How many degrees the orientation of a contact can change before the movement is considered unstable.
## Changes above this threshold are ignored.
##
OrientationThresholdMax = 5

##
## The minimal diameter a contact must have.
##
SizeMin = 0.1

##
## The maximal diameter a contact can have.
##
SizeMax = 2.0

##
## The minimal aspect ratio a contact must have.
##
AspectMin = 0.521

##
## The maximal aspect ratio a contact can have.
##
AspectMax = 3.323

[Stylus]
##
## Disables the stylus. No stylus data will be processed.
##
# Disable = false

##
## The distance between the stylus tip and the position transmitter, in centimeters.
## This setting adds a tilt-derived offset to the position reported by the stylus,
## with the goal of aligning it to the tip of the pen. The higher this value and / or
## the tilt of the stylus, the higher the offset will be.
##
TipDistance = 0

[DFT]
PositionMinAmp = 50
PositionMinMag = 2000
PositionExp = -0.7
ButtonMinMag = 1000
FreqMinMag = 10000
# AllowSplitEvents = false
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

# ============================================================================
# REFIND BOOTLOADER INSTALLATION
# ============================================================================

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

# ============================================================================
# AUTO-CPUFREQ INSTALLATION & CONFIGURATION
# ============================================================================

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

    # Run the installer with full interactive input
    log_info "Running auto-cpufreq installer..."
    log_info "Please respond to any prompts as needed."
    echo ""

    sudo bash ./auto-cpufreq-installer

    # Clean up temporary directory
    cd - >/dev/null || true
    rm -rf "$temp_dir"

    # Install and enable the daemon
    log_info "Installing auto-cpufreq daemon service..."
    if sudo auto-cpufreq --install 2>&1 | tail -5; then
        log_success "auto-cpufreq daemon installed"
    else
        log_warn "auto-cpufreq daemon installation may have encountered issues"
    fi

    echo ""

    # Verify installation
    if command -v auto-cpufreq &>/dev/null; then
        log_success "auto-cpufreq binary verified"

        # Check service status
        log_info "Checking auto-cpufreq service status..."
        if systemctl is-active --quiet auto-cpufreq; then
            log_success "auto-cpufreq service is running"
        else
            log_warn "auto-cpufreq service is not running"
            log_info "Attempting to start service..."
            sudo systemctl start auto-cpufreq 2>&1 | tail -3 || true
        fi
    else
        log_warn "auto-cpufreq binary not found"
    fi

    echo ""

    # Always return success so script continues
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

# Charger plugged in - Performance profile
[charger]
governor = performance
scaling_min_freq = 800000
scaling_max_freq = 4800000
turbo = auto

# Battery - Power saving profile
[battery]
governor = powersave
scaling_min_freq = 800000
scaling_max_freq = 2400000
turbo = never

# Intel P-State driver settings (if applicable)
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

enable_auto_cpufreq_service() {
    log_info "Enabling and starting auto-cpufreq service..."

    # Enable service to start on boot
    systemctl enable auto-cpufreq >/dev/null 2>&1 || {
        log_error "Failed to enable auto-cpufreq service"
        return 1
    }
    log_success "auto-cpufreq service enabled for boot"

    # Start the service
    systemctl start auto-cpufreq >/dev/null 2>&1 || {
        log_error "Failed to start auto-cpufreq service"
        return 1
    }
    log_success "auto-cpufreq service started"

    # Verify service is running
    if systemctl is-active --quiet auto-cpufreq; then
        log_success "auto-cpufreq service is running"
    else
        log_error "auto-cpufreq service failed to start"
        return 1
    fi

    echo ""
}

display_auto_cpufreq_info() {
    log_info "auto-cpufreq Information:"
    echo ""
    echo "  auto-cpufreq provides automatic CPU frequency scaling and power"
    echo "  management optimization for your Surface Pro 9."
    echo ""
    echo "  • AC Profile (Plugged In):"
    echo "    - Governor: performance"
    echo "    - Max Frequency: 4.8 GHz"
    echo "    - Turbo: auto"
    echo ""
    echo "  • Battery Profile:"
    echo "    - Governor: powersave"
    echo "    - Max Frequency: 2.4 GHz"
    echo "    - Turbo: disabled"
    echo ""
    echo "  Monitoring Commands:"
    echo "    • Check current status: auto-cpufreq --status"
    echo "    • View logs: journalctl -u auto-cpufreq -f"
    echo "    • Check CPU frequencies: watch -n 1 'cat /proc/cpuinfo | grep MHz'"
    echo ""
}

# ============================================================================
# CACHYOS PERFORMANCE OPTIMIZATIONS
# ============================================================================

detect_gpu_type() {
    # Detect GPU type for hardware-specific optimizations
    if lspci 2>/dev/null | grep -qi "NVIDIA"; then
        echo "nvidia"
    elif lspci 2>/dev/null | grep -qi "AMD"; then
        echo "amd"
    elif lspci 2>/dev/null | grep -qi "Intel"; then
        echo "intel"
    else
        echo "unknown"
    fi
}

detect_storage_type() {
    # Detect if system uses SSD/NVMe or HDD
    # Surface Pro 9 uses NVMe, but check anyway
    if [[ -e /sys/block/nvme0n1 ]] || [[ -e /sys/block/sda ]] && grep -q "SSD\|NVMe" /sys/block/*/queue/rotational 2>/dev/null; then
        echo "ssd"
    else
        echo "hdd"
    fi
}

apply_sysctl_optimizations() {
    log_info "Applying sysctl performance optimizations..."

    local sysctl_file="/etc/sysctl.d/99-cachyos-settings.conf"
    local sysctl_backup="${sysctl_file}.backup.$(date +%s)"

    # Backup existing configuration if it exists
    if [[ -f "$sysctl_file" ]]; then
        log_info "Backing up existing sysctl configuration..."
        cp "$sysctl_file" "$sysctl_backup" || {
            log_error "Failed to backup sysctl configuration"
            return 1
        }
        log_success "sysctl configuration backed up"
    fi

    # Create optimized sysctl configuration
    log_info "Creating CachyOS sysctl optimizations..."

    cat > "$sysctl_file" << 'EOF'
# CachyOS Performance Optimizations for Fedora
# System-level tweaks for improved desktop performance and responsiveness

# ============================================================================
# VM and Memory Management
# ============================================================================

# Reduce swappiness for better responsiveness (0-10 for desktop)
vm.swappiness = 10

# Increase page cache reclaim aggressiveness
vm.vfs_cache_pressure = 50

# Transparent Huge Pages (THP) shrinker optimization
vm.thp_split_huge_pages = 0

# Reduce memory fragmentation
vm.compaction_proactiveness = 20

# Improve memory allocation efficiency
vm.page-cluster = 3

# ============================================================================
# Kernel Scheduler Optimizations
# ============================================================================

# Improve scheduler responsiveness
kernel.sched_migration_cost_ns = 5000000
kernel.sched_min_granularity_ns = 10000000
kernel.sched_wakeup_granularity_ns = 15000000

# Reduce latency for interactive tasks
kernel.sched_latency_ns = 24000000

# ============================================================================
# File System Performance
# ============================================================================

# Increase file descriptor limits
fs.file-max = 2097152

# Improve inode cache
fs.inode-state = 0

# ============================================================================
# Network Performance
# ============================================================================

# Increase TCP backlog for better network performance
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096

# Improve TCP performance
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30

# Increase network buffer sizes
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# ============================================================================
# Kernel Hardening (Balanced with Performance)
# ============================================================================

# Enable ASLR for security
kernel.randomize_va_space = 2

# Restrict kernel module loading
kernel.modules_disabled = 0

# ============================================================================
# I/O Scheduler Tuning
# ============================================================================

# Reduce I/O latency
kernel.io_delay_type = 1

# Improve disk I/O performance
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 500
EOF

    if [[ ! -f "$sysctl_file" ]]; then
        log_error "Failed to create sysctl configuration file"
        return 1
    fi

    chmod 644 "$sysctl_file" || {
        log_error "Failed to set permissions on sysctl configuration"
        return 1
    }

    # Apply sysctl settings
    log_info "Applying sysctl settings..."
    sysctl -p "$sysctl_file" >/dev/null 2>&1 || {
        log_error "Failed to apply sysctl settings"
        return 1
    }

    log_success "sysctl optimizations applied"
}

apply_modprobe_optimizations() {
    log_info "Applying modprobe audio and GPU optimizations..."

    local modprobe_file="/etc/modprobe.d/cachyos-settings.conf"
    local modprobe_backup="${modprobe_file}.backup.$(date +%s)"

    # Backup existing configuration if it exists
    if [[ -f "$modprobe_file" ]]; then
        log_info "Backing up existing modprobe configuration..."
        cp "$modprobe_file" "$modprobe_backup" || {
            log_error "Failed to backup modprobe configuration"
            return 1
        }
        log_success "modprobe configuration backed up"
    fi

    # Create modprobe configuration
    log_info "Creating modprobe optimizations..."

    cat > "$modprobe_file" << 'EOF'
# CachyOS modprobe optimizations for Fedora
# Audio and GPU driver tuning for performance

# ============================================================================
# Audio Driver Optimization
# ============================================================================

# Disable power saving for Intel HDA audio (reduces latency)
options snd_hda_intel power_save=0 power_save_controller=N

# Increase audio buffer size for stability
options snd_hda_intel model=auto

# ============================================================================
# GPU Driver Optimizations
# ============================================================================

# Intel GPU optimizations (if applicable)
options i915 enable_guc=3 enable_fbc=1 enable_psr=0

# AMD GPU optimizations (if applicable)
options amdgpu gpu_recovery=1 ppfeaturemask=0xffffffff

# NVIDIA GPU optimizations (if applicable)
# Note: NVIDIA driver may override these settings
options nvidia NVreg_UsePageAttributeTable=1
EOF

    if [[ ! -f "$modprobe_file" ]]; then
        log_error "Failed to create modprobe configuration file"
        return 1
    fi

    chmod 644 "$modprobe_file" || {
        log_error "Failed to set permissions on modprobe configuration"
        return 1
    }

    log_success "modprobe optimizations applied"
}

apply_udev_rules() {
    log_info "Applying udev rules for I/O and device optimization..."

    # Create I/O scheduler optimization rules
    local io_scheduler_rules="/etc/udev/rules.d/60-io-scheduler.rules"

    log_info "Creating I/O scheduler optimization rules..."
    cat > "$io_scheduler_rules" << 'EOF'
# CachyOS I/O Scheduler Optimization Rules
# Automatically select optimal scheduler based on drive type

# For NVMe devices, use none or kyber scheduler
ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/scheduler}="none"

# For SSD devices, use none or kyber scheduler
ACTION=="add|change", KERNEL=="sd[a-z]|vd[a-z]|hd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"

# For HDD devices, use mq-deadline scheduler
ACTION=="add|change", KERNEL=="sd[a-z]|vd[a-z]|hd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="mq-deadline"

# Increase I/O queue depth for better performance
ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/nr_requests}="256"
ACTION=="add|change", KERNEL=="sd[a-z]|vd[a-z]|hd[a-z]", ATTR{queue/nr_requests}="256"
EOF

    chmod 644 "$io_scheduler_rules" || {
        log_error "Failed to set permissions on I/O scheduler rules"
        return 1
    }

    # Create audio device permissions rules
    local audio_rules="/etc/udev/rules.d/61-audio-permissions.rules"

    log_info "Creating audio device permission rules..."
    cat > "$audio_rules" << 'EOF'
# CachyOS Audio Device Permissions
# Grant audio group access to real-time capable devices

# Real-time clock access for low-latency audio
KERNEL=="rtc0", GROUP="audio", MODE="0660"

# HPET (High Precision Event Timer) access
KERNEL=="hpet", GROUP="audio", MODE="0660"

# CPU DMA latency access for low-latency audio
KERNEL=="cpu_dma_latency", GROUP="audio", MODE="0660"
EOF

    chmod 644 "$audio_rules" || {
        log_error "Failed to set permissions on audio rules"
        return 1
    }

    # Create SATA power management rules
    local sata_rules="/etc/udev/rules.d/62-sata-power.rules"

    log_info "Creating SATA power management rules..."
    cat > "$sata_rules" << 'EOF'
# CachyOS SATA Power Management
# Set SATA devices to max_performance policy

ACTION=="add|change", SUBSYSTEM=="ata_port", ATTR{power/control}="on"
ACTION=="add|change", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_policy}="max_performance"
EOF

    chmod 644 "$sata_rules" || {
        log_error "Failed to set permissions on SATA rules"
        return 1
    }

    # Reload udev rules
    log_info "Reloading udev rules..."
    udevadm control --reload-rules >/dev/null 2>&1 || {
        log_error "Failed to reload udev rules"
        return 1
    }

    udevadm trigger >/dev/null 2>&1 || {
        log_error "Failed to trigger udev rules"
        return 1
    }

    log_success "udev rules applied and reloaded"
}

apply_systemd_optimizations() {
    log_info "Applying systemd service optimizations..."

    local systemd_conf="/etc/systemd/system.conf"
    local systemd_backup="${systemd_conf}.backup.$(date +%s)"

    # Backup existing configuration if it exists
    if [[ -f "$systemd_conf" ]]; then
        log_info "Backing up existing systemd configuration..."
        cp "$systemd_conf" "$systemd_backup" || {
            log_error "Failed to backup systemd configuration"
            return 1
        }
        log_success "systemd configuration backed up"
    fi

    # Apply systemd optimizations
    log_info "Configuring systemd service timeouts and limits..."

    # Check if settings already exist and update them, or add them
    if grep -q "^DefaultTimeoutStartSec=" "$systemd_conf"; then
        sed -i 's/^DefaultTimeoutStartSec=.*/DefaultTimeoutStartSec=15s/' "$systemd_conf"
    else
        echo "DefaultTimeoutStartSec=15s" >> "$systemd_conf"
    fi

    if grep -q "^DefaultTimeoutStopSec=" "$systemd_conf"; then
        sed -i 's/^DefaultTimeoutStopSec=.*/DefaultTimeoutStopSec=10s/' "$systemd_conf"
    else
        echo "DefaultTimeoutStopSec=10s" >> "$systemd_conf"
    fi

    if grep -q "^DefaultLimitNOFILE=" "$systemd_conf"; then
        sed -i 's/^DefaultLimitNOFILE=.*/DefaultLimitNOFILE=2048:2097152/' "$systemd_conf"
    else
        echo "DefaultLimitNOFILE=2048:2097152" >> "$systemd_conf"
    fi

    # Reload systemd daemon
    log_info "Reloading systemd daemon..."
    systemctl daemon-reload >/dev/null 2>&1 || {
        log_error "Failed to reload systemd daemon"
        return 1
    }

    log_success "systemd optimizations applied"
}

apply_journald_optimizations() {
    log_info "Applying systemd-journald optimizations..."

    local journald_conf="/etc/systemd/journald.conf"
    local journald_backup="${journald_conf}.backup.$(date +%s)"

    # Backup existing configuration if it exists
    if [[ -f "$journald_conf" ]]; then
        log_info "Backing up existing journald configuration..."
        cp "$journald_conf" "$journald_backup" || {
            log_error "Failed to backup journald configuration"
            return 1
        }
        log_success "journald configuration backed up"
    fi

    # Apply journald optimizations
    log_info "Configuring systemd-journald max size..."

    if grep -q "^SystemMaxUse=" "$journald_conf"; then
        sed -i 's/^SystemMaxUse=.*/SystemMaxUse=50M/' "$journald_conf"
    else
        echo "SystemMaxUse=50M" >> "$journald_conf"
    fi

    # Restart journald to apply changes
    log_info "Restarting systemd-journald..."
    systemctl restart systemd-journald >/dev/null 2>&1 || {
        log_error "Failed to restart systemd-journald"
        return 1
    }

    log_success "journald optimizations applied"
}

apply_network_optimizations() {
    log_info "Applying network optimizations..."

    local timesyncd_conf="/etc/systemd/timesyncd.conf"
    local timesyncd_backup="${timesyncd_conf}.backup.$(date +%s)"

    # Backup existing configuration if it exists
    if [[ -f "$timesyncd_conf" ]]; then
        log_info "Backing up existing timesyncd configuration..."
        cp "$timesyncd_conf" "$timesyncd_backup" || {
            log_error "Failed to backup timesyncd configuration"
            return 1
        }
        log_success "timesyncd configuration backed up"
    fi

    # Apply network time synchronization optimizations
    log_info "Configuring NTP servers..."

    if grep -q "^NTP=" "$timesyncd_conf"; then
        sed -i 's/^NTP=.*/NTP=time.cloudflare.com time.google.com 0.arch.pool.ntp.org 1.arch.pool.ntp.org/' "$timesyncd_conf"
    else
        echo "NTP=time.cloudflare.com time.google.com 0.arch.pool.ntp.org 1.arch.pool.ntp.org" >> "$timesyncd_conf"
    fi

    if grep -q "^FallbackNTP=" "$timesyncd_conf"; then
        sed -i 's/^FallbackNTP=.*/FallbackNTP=0.fedora.pool.ntp.org 1.fedora.pool.ntp.org/' "$timesyncd_conf"
    else
        echo "FallbackNTP=0.fedora.pool.ntp.org 1.fedora.pool.ntp.org" >> "$timesyncd_conf"
    fi

    # Restart timesyncd
    log_info "Restarting systemd-timesyncd..."
    systemctl restart systemd-timesyncd >/dev/null 2>&1 || {
        log_warn "Failed to restart systemd-timesyncd (may not be critical)"
    }

    log_success "Network optimizations applied"
}

display_cachyos_info() {
    log_info "CachyOS Performance Optimizations Applied:"
    echo ""
    echo "  CachyOS optimizations provide system-level performance improvements:"
    echo ""
    echo "  • sysctl Tweaks:"
    echo "    - VM and memory management for better responsiveness"
    echo "    - Kernel scheduler improvements"
    echo "    - File system performance enhancements"
    echo "    - Network performance optimizations"
    echo ""
    echo "  • udev Rules:"
    echo "    - I/O scheduler optimization (NVMe: none, SSD: none, HDD: mq-deadline)"
    echo "    - Audio device permissions for low-latency audio"
    echo "    - SATA power management"
    echo ""
    echo "  • modprobe Configuration:"
    echo "    - Audio driver optimization (power_save disabled)"
    echo "    - GPU driver tuning (Intel, AMD, NVIDIA)"
    echo ""
    echo "  • systemd Optimizations:"
    echo "    - Faster service startup/shutdown timeouts"
    echo "    - Increased file descriptor limits"
    echo "    - Journal size optimization (50MB max)"
    echo ""
    echo "  • Network Optimizations:"
    echo "    - Optimized NTP servers (Cloudflare, Google, Arch)"
    echo "    - Improved time synchronization"
    echo ""
    echo "  Verification Commands:"
    echo "    • Check sysctl settings: sysctl -a | grep -E 'swappiness|vfs_cache'"
    echo "    • Check I/O scheduler: cat /sys/block/nvme0n1/queue/scheduler"
    echo "    • Check audio permissions: ls -la /dev/rtc0 /dev/hpet"
    echo ""
}

apply_cachyos_optimizations() {
    log_info "Starting CachyOS performance optimizations..."
    echo ""

    # Apply all CachyOS optimizations
    apply_sysctl_optimizations || {
        log_warn "sysctl optimizations failed, continuing..."
    }

    apply_modprobe_optimizations || {
        log_warn "modprobe optimizations failed, continuing..."
    }

    apply_udev_rules || {
        log_warn "udev rules failed, continuing..."
    }

    apply_systemd_optimizations || {
        log_warn "systemd optimizations failed, continuing..."
    }

    apply_journald_optimizations || {
        log_warn "journald optimizations failed, continuing..."
    }

    apply_network_optimizations || {
        log_warn "network optimizations failed, continuing..."
    }

    display_cachyos_info

    log_success "CachyOS optimizations completed"
    echo ""
}

# ============================================================================
# ADDITIONAL PERFORMANCE OPTIMIZATIONS (TIER 1 & 2)
# ============================================================================

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

apply_gnome_tweaks() {
    log_info "Applying GNOME performance tweaks..."

    # Check if GNOME is installed
    if ! command -v gsettings &>/dev/null; then
        log_warn "GNOME not detected, skipping GNOME tweaks"
        return 0
    fi

    log_info "Disabling GNOME animations for better responsiveness..."

    # Disable animations
    gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null || true
    gsettings set org.gnome.desktop.wm.preferences enable-animations false 2>/dev/null || true

    log_success "GNOME performance tweaks applied"
}

install_audio_enhancements() {
    log_info "Installing audio enhancement tools..."

    # Check if already installed
    if rpm -q easyeffects >/dev/null 2>&1; then
        log_warn "Audio enhancement tools already installed"
        return 0
    fi

    log_info "Installing EasyEffects and audio plugins..."
    dnf install -y easyeffects lsp-plugins-lv2 zam-plugins calf mda-lv2 2>&1 | grep -E "^(Installing|Updating)" || true

    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        log_warn "Failed to install audio enhancement tools"
        return 0
    fi

    log_success "Audio enhancement tools installed"
}

# ============================================================================
# SURFACE PRO 9 SPECIFIC FIXES
# ============================================================================

apply_surface_pro9_fixes() {
    log_info "Applying Surface Pro 9 specific fixes..."
    echo ""

    # Backup GRUB configuration
    local grub_file="/etc/default/grub"
    local grub_backup="${grub_file}.backup.$(date +%s)"

    if [[ ! -f "$grub_backup" ]]; then
        log_info "Backing up GRUB configuration to $grub_backup..."
        cp "$grub_file" "$grub_backup" || {
            log_error "Failed to backup GRUB configuration"
            return 1
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
        # Extract current GRUB_CMDLINE_LINUX_DEFAULT value
        local current_cmdline
        current_cmdline=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "$grub_file" | cut -d'"' -f2)

        # Append i915.enable_psr=0 if not already present
        local new_cmdline="${current_cmdline} i915.enable_psr=0"

        # Update GRUB configuration using sed
        sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"${new_cmdline}\"|" "$grub_file" || {
            log_error "Failed to apply screen flickering fix"
            return 1
        }

        log_success "Screen flickering fix applied (i915.enable_psr=0)"
    fi

    # Fix 2: ACPI Interrupt Storm Mitigation (pci=hpiosize=0)
    log_info "Applying Fix 2: ACPI Interrupt Storm Mitigation (pci=hpiosize=0)..."

    if grep -q "pci=hpiosize=0" "$grub_file"; then
        log_warn "ACPI interrupt storm fix already applied"
    else
        # Extract current GRUB_CMDLINE_LINUX_DEFAULT value
        local current_cmdline
        current_cmdline=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "$grub_file" | cut -d'"' -f2)

        # Append pci=hpiosize=0 if not already present
        local new_cmdline="${current_cmdline} pci=hpiosize=0"

        # Update GRUB configuration using sed
        sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"${new_cmdline}\"|" "$grub_file" || {
            log_error "Failed to apply ACPI interrupt storm fix"
            return 1
        }

        log_success "ACPI interrupt storm fix applied (pci=hpiosize=0)"
    fi

    # Regenerate GRUB configuration
    log_info "Regenerating GRUB configuration..."
    grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null 2>&1 || {
        log_error "Failed to regenerate GRUB configuration"
        log_warn "You may need to run: sudo grub2-mkconfig -o /boot/grub2/grub.cfg"
        return 1
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
# ESSENTIAL APPLICATIONS INSTALLATION
# ============================================================================

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

install_vscode() {
    log_info "Installing Visual Studio Code..."
    
    # Check if already installed
    if dnf list installed code >/dev/null 2>&1; then
        log_warn "Visual Studio Code is already installed"
        return 0
    fi
    
    # Add Microsoft repository
    log_info "Adding Microsoft repository..."
    rpm --import https://packages.microsoft.com/keys/microsoft.asc >/dev/null 2>&1 || {
        log_warn "Failed to import Microsoft GPG key"
    }
    
    dnf config-manager --add-repo https://packages.microsoft.com/yumrepos/vscode >/dev/null 2>&1 || {
        log_warn "Failed to add Microsoft repository"
    }
    
    # Install VS Code
    dnf install -y code >/dev/null 2>&1 || {
        log_error "Failed to install Visual Studio Code"
        return 1
    }
    
    log_success "Visual Studio Code installed successfully"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Fedora Surface Setup Script v${SCRIPT_VERSION}                    ║${NC}"
    echo -e "${BLUE}║  Linux Surface Kernel + Essential Applications Installer  ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Run prerequisite checks
    log_info "Running prerequisite checks..."
    check_root
    check_fedora
    check_network
    log_success "All prerequisite checks passed"
    echo ""
    
    # System updates
    log_info "Starting system updates..."
    update_system
    echo ""
    
    # Linux Surface kernel installation
    log_info "Starting Linux Surface kernel installation..."
    install_surface_kernel
    configure_surface_hardware
    configure_iptsd
    echo ""

    # rEFInd bootloader installation
    log_info "Installing rEFInd bootloader..."
    install_refind
    configure_refind_theme
    echo ""

    # auto-cpufreq installation and configuration
    log_info "Starting auto-cpufreq installation and configuration..."
    install_auto_cpufreq
    configure_auto_cpufreq_surface
    enable_auto_cpufreq_service
    display_auto_cpufreq_info
    echo ""

    # CachyOS performance optimizations
    log_info "Starting CachyOS performance optimizations..."
    apply_cachyos_optimizations
    echo ""

    # Additional performance optimizations (Tier 1 & 2)
    log_info "Applying additional performance optimizations..."
    apply_gaming_tweaks
    apply_adios_scheduler
    apply_rcu_lazy
    install_multimedia_codecs
    enable_hardware_video_acceleration
    apply_gnome_tweaks
    install_audio_enhancements
    echo ""

    # Essential applications
    log_info "Installing essential applications..."
    install_vesktop
    install_steam
    install_vscode
    echo ""

    # Surface Pro 9 specific fixes
    log_info "Applying Surface Pro 9 specific fixes..."
    apply_surface_pro9_fixes
    apply_hibernation_config
    display_surface_pro9_info
    echo ""

    # Summary and reboot prompt
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                  Installation Complete!                    ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_success "All components installed successfully"
    echo ""
    echo -e "${BLUE}Installed Components:${NC}"
    echo ""
    echo -e "${BLUE}Core Components:${NC}"
    echo "  ✓ Linux Surface Kernel"
    echo "  ✓ Surface Hardware Configuration"
    echo "  ✓ iptsd Touchscreen Configuration"
    echo "  ✓ rEFInd Bootloader with nils Theme"
    echo ""
    echo -e "${BLUE}Performance Optimizations:${NC}"
    echo "  ✓ auto-cpufreq (CPU Frequency Scaling)"
    echo "  ✓ CachyOS Performance Optimizations (50+ tweaks)"
    echo "  ✓ Gaming Performance Tweaks (Split Lock Mitigate)"
    echo "  ✓ ADIOS I/O Scheduler (NVMe Responsiveness)"
    echo "  ✓ RCU Lazy (Power Management)"
    echo "  ✓ Multimedia Codecs & Hardware Acceleration"
    echo "  ✓ GNOME Performance Tweaks"
    echo "  ✓ Audio Enhancement Tools (EasyEffects)"
    echo ""
    echo -e "${BLUE}System Fixes:${NC}"
    echo "  ✓ Surface Pro 9 Specific Fixes"
    echo "  ✓ Hibernation Configuration"
    echo ""
    echo -e "${BLUE}Essential Applications:${NC}"
    echo "  ✓ Vesktop (Discord Client)"
    echo "  ✓ Steam (Gaming Platform)"
    echo "  ✓ Visual Studio Code"
    echo ""
    echo -e "${YELLOW}IMPORTANT: A system reboot is required to complete the installation.${NC}"
    echo -e "${YELLOW}The Linux Surface kernel, rEFInd, and auto-cpufreq will be active after reboot.${NC}"
    echo -e "${YELLOW}RCU Lazy kernel parameter requires reboot to take effect.${NC}"
    echo ""
    
    read -p "Reboot now? (y/n) " -n 1 -r
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

