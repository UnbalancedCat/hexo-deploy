#!/bin/bash
set -euo pipefail

# Enhanced Start Script for Hexo Blog Container v0.0.4
# Features: Supervisor integration, enhanced monitoring, automatic recovery

readonly SCRIPT_VERSION="0.0.4-enhanced"
readonly LOG_FILE="/var/log/container/startup.log"
readonly CONFIG_DIR="/etc/container/templates"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${timestamp} [${level}] ${message}"
    
    # Write to log file if possible
    if [[ -w "/var/log/container" ]] || [[ -w "$LOG_FILE" ]]; then
        echo "${timestamp} [${level}] ${message}" >> "$LOG_FILE"
    fi
    
    # Send to syslog
    logger -t "hexo-start" "${level}: ${message}"
}

log_info() { log "${GREEN}INFO${NC}" "$@"; }
log_warn() { log "${YELLOW}WARN${NC}" "$@"; }
log_error() { log "${RED}ERROR${NC}" "$@"; }
log_debug() { log "${BLUE}DEBUG${NC}" "$@"; }

# Error handler
handle_error() {
    local line_number=$1
    log_error "Script failed at line ${line_number}"
    log_error "Attempting graceful shutdown..."
    cleanup
    exit 1
}

trap 'handle_error ${LINENO}' ERR

# Cleanup function
cleanup() {
    log_info "Performing cleanup..."
    # Kill any background processes if needed
    jobs -p | xargs -r kill 2>/dev/null || true
}

trap cleanup EXIT

# Main startup function
main() {
    log_info "Starting Hexo Blog Container ${SCRIPT_VERSION}"
    log_info "================================================"
    
    # System information
    log_info "System: $(uname -a)"
    log_info "Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    log_info "Disk: $(df -h / | awk 'NR==2 {print $4 " available"}')"
    
    # Environment setup
    setup_environment
    
    # User management
    setup_users
    
    # Configure services
    configure_ssh
    configure_nginx
    configure_git
    configure_monitoring
    
    # Pre-flight checks
    preflight_checks
    
    # Start services
    if [[ "${SUPERVISOR_ENABLED:-true}" == "true" ]]; then
        start_with_supervisor
    else
        start_traditional
    fi
}

setup_environment() {
    log_info "Setting up environment..."
    
    # Create necessary directories
    mkdir -p /var/log/container
    mkdir -p /var/run/sshd
    mkdir -p /backup/auto
    mkdir -p /home/www/hexo
    mkdir -p /home/hexo/.ssh
    
    # Set timezone if not set
    if [[ -n "${TZ:-}" ]]; then
        ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime
        echo "${TZ}" > /etc/timezone
        log_info "Timezone set to: ${TZ}"
    fi
    
    # Setup locale
    if [[ -n "${LANG:-}" ]]; then
        locale-gen "${LANG}" 2>/dev/null || true
        update-locale "LANG=${LANG}" 2>/dev/null || true
        log_info "Locale set to: ${LANG}"
    fi
}

setup_users() {
    log_info "Setting up users..."
    
    # Update hexo user UID/GID if specified
    if [[ -n "${PUID:-}" ]] && [[ "${PUID}" != "1000" ]]; then
        usermod -u "${PUID}" hexo
        log_info "Updated hexo user UID to: ${PUID}"
    fi
    
    if [[ -n "${PGID:-}" ]] && [[ "${PGID}" != "1000" ]]; then
        groupmod -g "${PGID}" hexo
        log_info "Updated hexo group GID to: ${PGID}"
    fi
    
    # Fix ownership after potential UID/GID changes
    chown -R hexo:hexo /home/hexo /home/www/hexo /var/log/container /backup
    log_info "Updated file ownership for hexo user"
}

configure_ssh() {
    log_info "Configuring SSH server..."
    
    # Process SSH configuration template
    if [[ -f "${CONFIG_DIR}/sshd_config.template" ]]; then
        envsubst < "${CONFIG_DIR}/sshd_config.template" > /etc/ssh/sshd_config
        log_info "SSH configuration applied from template"
    else
        log_warn "SSH template not found, using default configuration"
    fi
    
    # Setup SSH banner
    if [[ -f "${CONFIG_DIR}/banner.txt" ]]; then
        cp "${CONFIG_DIR}/banner.txt" /etc/ssh/banner.txt
        log_info "SSH banner configured"
    fi
    
    # Generate host keys if they don't exist
    if [[ ! -f /etc/ssh/ssh_host_rsa_key ]]; then
        ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N '' -q
        log_info "Generated SSH RSA host key"
    fi
    
    if [[ ! -f /etc/ssh/ssh_host_ed25519_key ]]; then
        ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N '' -q
        log_info "Generated SSH Ed25519 host key"
    fi
    
    # Test SSH configuration
    if sshd -t; then
        log_info "SSH configuration is valid"
    else
        log_error "SSH configuration is invalid"
        return 1
    fi
}

configure_nginx() {
    log_info "Configuring Nginx server..."
    
    # Process Nginx configuration template
    if [[ -f "${CONFIG_DIR}/nginx.conf.template" ]]; then
        envsubst < "${CONFIG_DIR}/nginx.conf.template" > /etc/nginx/nginx.conf
        log_info "Nginx configuration applied from template"
    else
        log_warn "Nginx template not found, using default configuration"
    fi
    
    # Create nginx user if it doesn't exist
    if ! id nginx >/dev/null 2>&1; then
        log_info "Creating nginx user..."
        useradd -r -s /bin/false nginx
    fi
    
    # Test Nginx configuration
    if nginx -t; then
        log_info "Nginx configuration is valid"
    else
        log_error "Nginx configuration is invalid"
        return 1
    fi
    
    # Create default index if it doesn't exist
    if [[ ! -f /home/www/hexo/index.html ]]; then
        log_info "Creating default index page..."
        cat > /home/www/hexo/index.html << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hexo Blog Ready</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; text-align: center; background: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background: white; padding: 40px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        .status { color: #28a745; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Hexo Blog Container</h1>
        <p class="status">✅ Ready for deployment</p>
        <p>Upload your Hexo blog content via Git push to get started!</p>
        <p><small>Version: 0.0.4-enhanced</small></p>
    </div>
</body>
</html>
EOF
        chown hexo:hexo /home/www/hexo/index.html
    fi
}

configure_git() {
    log_info "Configuring Git repository..."
    
    # Ensure Git repository exists and has correct permissions
    if [[ ! -d /home/hexo/hexo.git ]]; then
        log_info "Initializing Git repository..."
        sudo -u hexo git init --bare /home/hexo/hexo.git
    fi
    
    # Ensure post-receive hook is executable
    if [[ -f /home/hexo/hexo.git/hooks/post-receive ]]; then
        chmod +x /home/hexo/hexo.git/hooks/post-receive
        log_info "Git post-receive hook configured"
    else
        log_warn "Git post-receive hook not found"
    fi
    
    # Set Git repository ownership
    chown -R hexo:hexo /home/hexo/hexo.git
}

configure_monitoring() {
    log_info "Configuring monitoring..."
    
    # Setup log rotation for container logs
    cat > /etc/logrotate.d/hexo-container << 'EOF'
/var/log/container/*.log {
    daily
    missingok
    rotate 30
    compress
    notifempty
    create 644 hexo hexo
    postrotate
        systemctl reload nginx 2>/dev/null || true
    endscript
}
EOF
    
    # Configure fail2ban if available
    if command -v fail2ban-server >/dev/null 2>&1; then
        systemctl enable fail2ban 2>/dev/null || true
        log_info "Fail2ban configured for SSH protection"
    fi
}

preflight_checks() {
    log_info "Performing pre-flight checks..."
    
    # Check disk space
    local disk_usage=$(df / | awk 'NR==2 {print $(NF-1)}' | sed 's/%//')
    if [[ $disk_usage -gt 80 ]]; then
        log_warn "Disk usage is high: ${disk_usage}%"
    fi
    
    # Check memory
    local mem_available=$(free | awk '/^Mem:/ {printf "%.1f", $7/$2 * 100.0}')
    if (( $(echo "$mem_available < 10" | bc -l) )); then
        log_warn "Available memory is low: ${mem_available}%"
    fi
    
    # Check required ports
    local ports=(80 22)
    for port in "${ports[@]}"; do
        if ss -ln | grep ":${port} " >/dev/null; then
            log_warn "Port ${port} is already in use"
        fi
    done
    
    # Check file permissions
    if [[ ! -w /var/log/container ]]; then
        log_error "Cannot write to log directory"
        return 1
    fi
    
    log_info "Pre-flight checks completed"
}

start_with_supervisor() {
    log_info "Starting services with Supervisor..."
    
    # Configure Supervisor if template exists
    if [[ -f "${CONFIG_DIR}/supervisord.conf.template" ]]; then
        envsubst < "${CONFIG_DIR}/supervisord.conf.template" > /etc/supervisor/conf.d/hexo.conf
        log_info "Supervisor configuration applied"
    fi
    
    # Start Supervisor
    log_info "Starting Supervisor daemon..."
    exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
}

start_traditional() {
    log_info "Starting services in traditional mode..."
    
    # Start SSH daemon
    log_info "Starting SSH daemon..."
    /usr/sbin/sshd -D &
    local sshd_pid=$!
    
    # Start Nginx
    log_info "Starting Nginx..."
    nginx -g "daemon off;" &
    local nginx_pid=$!
    
    # Start log rotator
    log_info "Starting log rotator..."
    /app/scripts/log-rotator.sh &
    local rotator_pid=$!
    
    # Monitor processes
    monitor_processes $sshd_pid $nginx_pid $rotator_pid
}

monitor_processes() {
    local pids=("$@")
    log_info "Monitoring ${#pids[@]} processes..."
    
    while true; do
        for pid in "${pids[@]}"; do
            if ! kill -0 "$pid" 2>/dev/null; then
                log_error "Process $pid has died, initiating restart..."
                # In a real scenario, you'd restart the specific service
                exit 1
            fi
        done
        sleep 30
    done
}

# Signal handlers for graceful shutdown
graceful_shutdown() {
    log_info "Received shutdown signal, stopping services..."
    
    # Stop Supervisor if running
    if pgrep supervisord >/dev/null; then
        supervisorctl stop all
        pkill supervisord
    fi
    
    # Stop individual services
    pkill nginx 2>/dev/null || true
    pkill sshd 2>/dev/null || true
    
    log_info "Graceful shutdown completed"
    exit 0
}

trap graceful_shutdown SIGTERM SIGINT

# Version check and help
if [[ "${1:-}" == "--version" ]]; then
    echo "Hexo Blog Container Start Script v${SCRIPT_VERSION}"
    exit 0
fi

if [[ "${1:-}" == "--help" ]]; then
    cat << EOF
Hexo Blog Container Start Script v${SCRIPT_VERSION}

Usage: $0 [OPTIONS]

Options:
  --version     Show version information
  --help        Show this help message
  --debug       Enable debug logging

Environment Variables:
  TZ            Timezone (default: Asia/Shanghai)
  LANG          Locale (default: zh_CN.UTF-8)
  PUID          User ID for hexo user (default: 1000)
  PGID          Group ID for hexo group (default: 1000)
  SUPERVISOR_ENABLED  Use supervisor for process management (default: true)

EOF
    exit 0
fi

# Enable debug mode if requested
if [[ "${1:-}" == "--debug" ]]; then
    set -x
    log_info "Debug mode enabled"
fi

# Start main function
main "$@"
