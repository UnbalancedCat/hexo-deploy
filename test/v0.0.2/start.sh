#!/bin/bash

# Enhanced startup script with improved logging, error handling, and dynamic permissions
# Version: 0.0.2 - Test version for development

# Color definitions for logging
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

# Configuration
LOG_DIR="/var/log/container"
LOG_FILE="$LOG_DIR/services.log"
MAX_LOG_SIZE=10485760  # 10MB

# Logging functions
_log() {
    local level_color=$1
    local level_name=$2
    shift 2
    echo -e "${level_color}[${level_name}]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_info() { _log "$BLUE" "INFO" "$@"; }
log_success() { _log "$GREEN" "SUCCESS" "$@"; }
log_warning() { _log "$YELLOW" "WARNING" "$@"; }
log_error() { _log "$RED" "ERROR" "$@"; }

# Setup logging with rotation
setup_logging() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    
    # Rotate log if it's too large
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt $MAX_LOG_SIZE ]; then
        log_info "Log file size exceeded ${MAX_LOG_SIZE} bytes, rotating..."
        mv "$LOG_FILE" "${LOG_FILE}.old"
        touch "$LOG_FILE"
        log_info "Log rotation completed"
    fi
    
    log_info "Logging to console and $LOG_FILE"
    exec > >(tee -a "$LOG_FILE") 2> >(tee -a "$LOG_FILE" >&2)
}

# Apply dynamic PUID/PGID if different from defaults
apply_dynamic_permissions() {
    local current_uid=$(id -u hexo)
    local current_gid=$(id -g hexo)
    local target_uid=${PUID:-1000}
    local target_gid=${PGID:-1000}
    
    if [ "$current_uid" != "$target_uid" ] || [ "$current_gid" != "$target_gid" ]; then
        log_info "Applying dynamic user/group mapping: $current_uid:$current_gid -> $target_uid:$target_gid"
        
        # Update group if needed
        if [ "$current_gid" != "$target_gid" ]; then
            groupmod -g "$target_gid" hexo
            log_info "Updated hexo group ID to $target_gid"
        fi
        
        # Update user if needed
        if [ "$current_uid" != "$target_uid" ]; then
            usermod -u "$target_uid" hexo
            log_info "Updated hexo user ID to $target_uid"
        fi
        
        # Update ownership of important directories
        log_info "Updating ownership of critical directories..."
        chown -R hexo:hexo /home/hexo /home/www/hexo 2>/dev/null || true
        log_success "Dynamic permissions applied successfully"
    else
        log_info "User/group IDs already match target values ($target_uid:$target_gid)"
    fi
}

# Main execution function
main() {
    setup_logging
    
    log_info "===== Hexo Container Starting (v0.0.2) ====="
    log_info "Timestamp: $(date)"
    log_info "This is a test version of the enhanced startup script"
    
    # Test dynamic permissions function
    apply_dynamic_permissions
    
    log_success "===== Test completed successfully ====="
}

# Start main execution
main
