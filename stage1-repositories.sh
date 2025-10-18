#!/bin/bash

################################################################################
# Stage 1: Repository Setup
# 
# Configures all required package repositories for Fedora Surface setup
# - Linux Surface repository
# - RPM Fusion Free repository
# - RPM Fusion Nonfree repository
#
# This script is idempotent and safe to run multiple times.
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION & CONSTANTS
# ============================================================================

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_DIR="/var/log/surface-setup"
readonly LOG_FILE="$LOG_DIR/stage1.log"
readonly COMPLETION_MARKER="$LOG_DIR/stage1.complete"

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
        log_error "This script must be run as root (use: sudo ./stage1-repositories.sh)"
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
# IDEMPOTENCY CHECK
# ============================================================================

check_already_completed() {
    if [[ -f "$COMPLETION_MARKER" ]]; then
        log_info "Stage 1 already completed. Use --force to re-run."
        exit 0
    fi
}

# ============================================================================
# REPOSITORY SETUP
# ============================================================================

setup_log_directory() {
    mkdir -p "$LOG_DIR" || {
        log_error "Failed to create log directory"
        exit 1
    }
}

add_linux_surface_repo() {
    log_info "Adding Linux Surface repository..."
    
    local repo_url="https://pkg.surfacelinux.com/fedora/linux-surface.repo"
    local max_retries=3
    local retry_count=0

    # Check if repository is already added
    if dnf repolist 2>/dev/null | grep -q "linux-surface"; then
        log_success "Linux Surface repository is already configured"
        return 0
    fi

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
            log_info "Using dnf5 syntax: dnf config-manager addrepo --from-repofile=..."
            output=$(timeout 30 dnf config-manager addrepo --from-repofile="$repo_url" 2>&1)
            exit_code=$?
        else
            log_info "Using dnf4 syntax: dnf config-manager --add-repo=..."
            output=$(timeout 30 dnf config-manager --add-repo="$repo_url" 2>&1)
            exit_code=$?
        fi

        # Check if repository was added (exit code 0 or already exists)
        if [[ $exit_code -eq 0 ]] || echo "$output" | grep -qi "already"; then
            log_success "Linux Surface repository added successfully"
            return 0
        else
            ((retry_count++))
            log_warn "Repository addition failed with exit code: $exit_code"

            if [[ $retry_count -lt $max_retries ]]; then
                log_warn "Retrying in 5 seconds (attempt $retry_count/$max_retries)..."
                sleep 5
            else
                log_warn "Failed to add Linux Surface repository after $max_retries attempts"
                log_warn "Continuing anyway (packages may not be available)"
                return 0
            fi
        fi
    done
}

add_rpm_fusion_repos() {
    log_info "Adding RPM Fusion repositories..."
    
    local fedora_version
    fedora_version=$(rpm -E %fedora)
    
    # Check if already added
    if dnf repolist 2>/dev/null | grep -q "rpmfusion"; then
        log_success "RPM Fusion repositories already configured"
        return 0
    fi

    log_info "Installing RPM Fusion Free repository..."
    dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_version}.noarch.rpm" 2>&1 | tail -3 || {
        log_warn "Failed to install RPM Fusion Free repository"
    }

    log_info "Installing RPM Fusion Nonfree repository..."
    dnf install -y "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_version}.noarch.rpm" 2>&1 | tail -3 || {
        log_warn "Failed to install RPM Fusion Nonfree repository"
    }

    log_success "RPM Fusion repositories added"
}

verify_repositories() {
    log_info "Verifying repositories are accessible..."
    
    if ! dnf repolist 2>/dev/null | grep -q "linux-surface"; then
        log_warn "Linux Surface repository not found in repolist"
    fi

    if ! dnf repolist 2>/dev/null | grep -q "rpmfusion"; then
        log_warn "RPM Fusion repositories not found in repolist"
    fi

    log_success "Repository verification complete"
}

update_repository_metadata() {
    log_info "Updating repository metadata..."
    
    dnf makecache 2>&1 | tail -3 || {
        log_warn "Failed to update repository metadata"
    }

    log_success "Repository metadata updated"
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
    echo -e "${BLUE}║  Stage 1: Repository Setup v${SCRIPT_VERSION}                        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Setup logging
    setup_log_directory

    # Run prerequisite checks
    log_info "Running prerequisite checks..."
    check_root
    check_fedora
    check_network
    log_success "All prerequisite checks passed"
    echo ""

    # Check if already completed
    check_already_completed

    # Add repositories
    log_info "Starting repository configuration..."
    echo ""
    add_linux_surface_repo
    add_rpm_fusion_repos
    verify_repositories
    update_repository_metadata
    echo ""

    # Create completion marker
    create_completion_marker

    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           Stage 1 Complete: Repositories Ready             ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_success "Stage 1 completed successfully"
    log_info "Next step: Run Stage 2 (Kernel Installation)"
    echo ""
}

# Run main function
main "$@"

