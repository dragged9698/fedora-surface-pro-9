#!/bin/bash

################################################################################
# Fedora Surface Setup - Multi-Stage Orchestrator
# 
# Interactive menu-driven orchestrator for managing multi-stage installation
# Tracks completion status, handles dependencies, and allows resumable setup
#
# Usage: sudo ./fedora-surface-setup-orchestrator.sh
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION & CONSTANTS
# ============================================================================

readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="/var/log/surface-setup"

# Stage markers
readonly STAGE1_MARKER="$LOG_DIR/stage1.complete"
readonly STAGE2_MARKER="$LOG_DIR/stage2.complete"
readonly STAGE3_MARKER="$LOG_DIR/stage3.complete"
readonly STAGE4_MARKER="$LOG_DIR/stage4.complete"
readonly STAGE5_MARKER="$LOG_DIR/stage5.complete"
readonly STAGE6_MARKER="$LOG_DIR/stage6.complete"

# Stage scripts
readonly STAGE1_SCRIPT="$SCRIPT_DIR/stage1-repositories.sh"
readonly STAGE2_SCRIPT="$SCRIPT_DIR/stage2-kernel.sh"
readonly STAGE3_SCRIPT="$SCRIPT_DIR/stage3-hardware.sh"
readonly STAGE4_SCRIPT="$SCRIPT_DIR/stage4-performance.sh"
readonly STAGE5_SCRIPT="$SCRIPT_DIR/stage5-desktop.sh"
readonly STAGE6_SCRIPT="$SCRIPT_DIR/stage6-gaming.sh"

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

# ============================================================================
# PREREQUISITE CHECKS
# ============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use: sudo ./fedora-surface-setup-orchestrator.sh)"
        exit 1
    fi
}

check_fedora() {
    if [[ ! -f /etc/fedora-release ]]; then
        log_error "This script is designed for Fedora only"
        exit 1
    fi
}

setup_log_directory() {
    mkdir -p "$LOG_DIR" || {
        log_error "Failed to create log directory"
        exit 1
    }
}

# ============================================================================
# STAGE STATUS FUNCTIONS
# ============================================================================

is_stage_complete() {
    local stage_num=$1
    local marker_file="$LOG_DIR/stage${stage_num}.complete"
    [[ -f "$marker_file" ]]
}

get_stage_status() {
    local stage_num=$1
    if is_stage_complete "$stage_num"; then
        echo "✓"
    else
        echo " "
    fi
}

get_stage_timestamp() {
    local stage_num=$1
    local marker_file="$LOG_DIR/stage${stage_num}.complete"
    if [[ -f "$marker_file" ]]; then
        grep "timestamp=" "$marker_file" | cut -d'=' -f2
    else
        echo "Not completed"
    fi
}

# ============================================================================
# STAGE EXECUTION FUNCTIONS
# ============================================================================

run_stage() {
    local stage_num=$1
    local stage_script
    
    case $stage_num in
        1) stage_script="$STAGE1_SCRIPT" ;;
        2) stage_script="$STAGE2_SCRIPT" ;;
        3) stage_script="$STAGE3_SCRIPT" ;;
        4) stage_script="$STAGE4_SCRIPT" ;;
        5) stage_script="$STAGE5_SCRIPT" ;;
        6) stage_script="$STAGE6_SCRIPT" ;;
        *) log_error "Invalid stage number: $stage_num"; return 1 ;;
    esac

    if [[ ! -f "$stage_script" ]]; then
        log_error "Stage script not found: $stage_script"
        return 1
    fi

    log_info "Running Stage $stage_num..."
    bash "$stage_script"
}

check_stage_prerequisites() {
    local stage_num=$1
    
    case $stage_num in
        1) return 0 ;; # No prerequisites
        2) 
            if ! is_stage_complete 1; then
                log_error "Stage 1 must be completed first"
                return 1
            fi
            ;;
        3)
            if ! is_stage_complete 2; then
                log_error "Stage 2 must be completed first"
                return 1
            fi
            ;;
        4) return 0 ;; # No prerequisites
        5) return 0 ;; # No prerequisites
        6)
            if ! is_stage_complete 1; then
                log_error "Stage 1 must be completed first"
                return 1
            fi
            ;;
    esac
    return 0
}

# ============================================================================
# MENU FUNCTIONS
# ============================================================================

display_main_menu() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║    Fedora Surface Pro 9 Setup Script - Multi-Stage Installer║${NC}"
    echo -e "${BLUE}║                      v${SCRIPT_VERSION}                                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${BLUE}Stage Status:${NC}"
    echo "  [$(get_stage_status 1)] Stage 1: Repository Setup"
    echo "      $(get_stage_timestamp 1)"
    echo "  [$(get_stage_status 2)] Stage 2: Kernel Installation"
    echo "      $(get_stage_timestamp 2)"
    echo "  [$(get_stage_status 3)] Stage 3: Surface Hardware Configuration"
    echo "      $(get_stage_timestamp 3)"
    echo "  [$(get_stage_status 4)] Stage 4: Performance Optimizations"
    echo "      $(get_stage_timestamp 4)"
    echo "  [$(get_stage_status 5)] Stage 5: Desktop Environment"
    echo "      $(get_stage_timestamp 5)"
    echo "  [$(get_stage_status 6)] Stage 6: Gaming Setup (Optional)"
    echo "      $(get_stage_timestamp 6)"
    echo ""
    
    echo -e "${BLUE}Select an option:${NC}"
    echo "  [1] Run all remaining stages"
    echo "  [2] Run individual stage"
    echo "  [3] Resume from last incomplete stage"
    echo "  [4] View stage details and logs"
    echo "  [5] Force re-run completed stage"
    echo "  [6] Exit"
    echo ""
}

display_stage_menu() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              Select Stage to Run                           ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo "  [1] Stage 1: Repository Setup"
    echo "  [2] Stage 2: Kernel Installation (requires Stage 1)"
    echo "  [3] Stage 3: Surface Hardware Configuration (requires Stage 2)"
    echo "  [4] Stage 4: Performance Optimizations"
    echo "  [5] Stage 5: Desktop Environment"
    echo "  [6] Stage 6: Gaming Setup (requires Stage 1)"
    echo "  [0] Back to main menu"
    echo ""
}

display_log_menu() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              View Stage Logs                               ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo "  [1] Stage 1: Repository Setup"
    echo "  [2] Stage 2: Kernel Installation"
    echo "  [3] Stage 3: Surface Hardware Configuration"
    echo "  [4] Stage 4: Performance Optimizations"
    echo "  [5] Stage 5: Desktop Environment"
    echo "  [6] Stage 6: Gaming Setup"
    echo "  [0] Back to main menu"
    echo ""
}

view_stage_log() {
    local stage_num=$1
    local log_file="$LOG_DIR/stage${stage_num}.log"
    
    if [[ ! -f "$log_file" ]]; then
        log_warn "Log file not found: $log_file"
        read -p "Press Enter to continue..."
        return
    fi
    
    clear
    echo -e "${BLUE}Stage $stage_num Log:${NC}"
    echo "=================================================="
    tail -50 "$log_file"
    echo "=================================================="
    echo ""
    read -p "Press Enter to continue..."
}

find_last_incomplete_stage() {
    for stage in 1 2 3 4 5 6; do
        if ! is_stage_complete "$stage"; then
            echo "$stage"
            return 0
        fi
    done
    echo "0" # All stages complete
}

run_all_remaining_stages() {
    local last_incomplete=$(find_last_incomplete_stage)
    
    if [[ "$last_incomplete" == "0" ]]; then
        log_success "All stages are already completed!"
        read -p "Press Enter to continue..."
        return
    fi
    
    log_info "Running all stages from Stage $last_incomplete onwards..."
    echo ""
    
    for stage in $(seq "$last_incomplete" 6); do
        if ! check_stage_prerequisites "$stage"; then
            log_warn "Skipping Stage $stage due to unmet prerequisites"
            continue
        fi
        
        if is_stage_complete "$stage"; then
            log_warn "Stage $stage already completed, skipping..."
            continue
        fi
        
        read -p "Ready to run Stage $stage? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            run_stage "$stage" || {
                log_error "Stage $stage failed"
                read -p "Press Enter to continue..."
                return 1
            }
        else
            log_info "Skipped Stage $stage"
        fi
        
        echo ""
    done
    
    log_success "All stages completed!"
    read -p "Press Enter to continue..."
}

run_individual_stage() {
    display_stage_menu
    read -p "Enter stage number [0-6]: " stage_choice
    
    case $stage_choice in
        0) return ;;
        1|2|3|4|5|6)
            if ! check_stage_prerequisites "$stage_choice"; then
                log_error "Cannot run Stage $stage_choice: prerequisites not met"
                read -p "Press Enter to continue..."
                return
            fi
            
            if is_stage_complete "$stage_choice"; then
                log_warn "Stage $stage_choice is already completed"
                read -p "Run anyway? (y/n) " -n 1 -r
                echo ""
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    return
                fi
            fi
            
            run_stage "$stage_choice"
            read -p "Press Enter to continue..."
            ;;
        *)
            log_error "Invalid choice"
            read -p "Press Enter to continue..."
            ;;
    esac
}

resume_from_last_incomplete() {
    local last_incomplete=$(find_last_incomplete_stage)
    
    if [[ "$last_incomplete" == "0" ]]; then
        log_success "All stages are already completed!"
        read -p "Press Enter to continue..."
        return
    fi
    
    log_info "Resuming from Stage $last_incomplete..."
    echo ""
    
    if ! check_stage_prerequisites "$last_incomplete"; then
        log_error "Cannot resume: prerequisites for Stage $last_incomplete not met"
        read -p "Press Enter to continue..."
        return
    fi
    
    run_stage "$last_incomplete"
    read -p "Press Enter to continue..."
}

view_logs() {
    display_log_menu
    read -p "Enter stage number [0-6]: " log_choice
    
    case $log_choice in
        0) return ;;
        1|2|3|4|5|6)
            view_stage_log "$log_choice"
            ;;
        *)
            log_error "Invalid choice"
            read -p "Press Enter to continue..."
            ;;
    esac
}

force_rerun_stage() {
    display_stage_menu
    read -p "Enter stage number to force re-run [0-6]: " stage_choice
    
    case $stage_choice in
        0) return ;;
        1|2|3|4|5|6)
            if ! is_stage_complete "$stage_choice"; then
                log_warn "Stage $stage_choice is not completed yet"
                read -p "Press Enter to continue..."
                return
            fi
            
            log_warn "Force re-running Stage $stage_choice..."
            rm -f "$LOG_DIR/stage${stage_choice}.complete"
            
            if ! check_stage_prerequisites "$stage_choice"; then
                log_error "Cannot run Stage $stage_choice: prerequisites not met"
                read -p "Press Enter to continue..."
                return
            fi
            
            run_stage "$stage_choice"
            read -p "Press Enter to continue..."
            ;;
        *)
            log_error "Invalid choice"
            read -p "Press Enter to continue..."
            ;;
    esac
}

# ============================================================================
# MAIN LOOP
# ============================================================================

main() {
    check_root
    check_fedora
    setup_log_directory
    
    while true; do
        display_main_menu
        read -p "Enter your choice [1-6]: " choice
        
        case $choice in
            1) run_all_remaining_stages ;;
            2) run_individual_stage ;;
            3) resume_from_last_incomplete ;;
            4) view_logs ;;
            5) force_rerun_stage ;;
            6) 
                log_info "Exiting setup orchestrator"
                exit 0
                ;;
            *)
                log_error "Invalid choice"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Run main function
main "$@"

