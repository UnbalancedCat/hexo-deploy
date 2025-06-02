#!/bin/bash

# Docker Hexo Static Blog v0.0.3-fixed - Container Start Script
# This script handles container initialization and service startup
# Fixed: Git Hook permission issues for deployment logging

set -e

# Environment variables with defaults
PUID=${PUID:-1000}
PGID=${PGID:-1000}
TZ=${TZ:-Asia/Shanghai}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Set timezone
if [ ! -z "$TZ" ]; then
    log "Setting timezone to $TZ"
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo $TZ > /etc/timezone
fi

# Update hexo user UID/GID if needed
current_uid=$(id -u hexo)
current_gid=$(id -g hexo)

if [ "$current_uid" != "$PUID" ] || [ "$current_gid" != "$PGID" ]; then
    log "Updating hexo user UID/GID from $current_uid:$current_gid to $PUID:$PGID"
    
    # Update group first
    groupmod -g "$PGID" hexo
    
    # Update user
    usermod -u "$PUID" -g "$PGID" hexo
    
    # Fix ownership of hexo directories
    chown -R hexo:hexo /home/hexo
    chown -R hexo:hexo /home/www/hexo
fi

# Ensure proper permissions
log "Setting up permissions..."
chown -R hexo:hexo /home/hexo
chown -R hexo:hexo /home/www/hexo
chown hexo:hexo /var/log/container
chmod 755 /var/log/container
chmod +x /home/hexo/hexo.git/hooks/post-receive

# Setup SSH host keys if they don't exist
log "Checking SSH host keys..."
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    log "Generating SSH host keys..."
    ssh-keygen -A
fi

# Setup SSH configuration from template
log "Setting up SSH configuration..."
if [ -f /etc/container/templates/sshd_config.template ]; then
    envsubst < /etc/container/templates/sshd_config.template > /etc/ssh/sshd_config
else
    log_warn "SSH template not found, using default configuration"
fi

# Setup SSH authorized keys for hexo user (for testing)
log "Setting up SSH access for hexo user..."
mkdir -p /home/hexo/.ssh
chmod 700 /home/hexo/.ssh

# Create a test SSH key pair if it doesn't exist (for development/testing)
if [ ! -f /home/hexo/.ssh/authorized_keys ]; then
    log "Creating test SSH key for hexo user..."
    
    # Generate a temporary key pair for testing
    ssh-keygen -t rsa -b 2048 -f /home/hexo/.ssh/id_rsa -N "" -C "hexo@container"
    
    # Add the public key to authorized_keys
    cat /home/hexo/.ssh/id_rsa.pub > /home/hexo/.ssh/authorized_keys
    
    # Set proper permissions
    chmod 600 /home/hexo/.ssh/authorized_keys
    chmod 600 /home/hexo/.ssh/id_rsa
    chmod 644 /home/hexo/.ssh/id_rsa.pub
    
    log "Test SSH key created and configured"
    log "Private key: /home/hexo/.ssh/id_rsa"
    log "Public key: /home/hexo/.ssh/id_rsa.pub"
fi

# Ensure SSH directory has correct ownership
chown -R hexo:hexo /home/hexo/.ssh

# Setup nginx configuration from template
log "Setting up nginx configuration..."
if [ -f /etc/container/templates/nginx.conf.template ]; then
    envsubst < /etc/container/templates/nginx.conf.template > /etc/nginx/nginx.conf
else
    log_warn "Nginx template not found, using default configuration"
fi

# Test nginx configuration
log "Testing nginx configuration..."
nginx -t || {
    log_error "Nginx configuration test failed"
    exit 1
}

# Create necessary directories
log "Creating necessary directories..."
mkdir -p /var/run/sshd
mkdir -p /var/log/nginx
mkdir -p /var/log/container

# Setup deployment log with proper permissions and file locking support
log "Setting up deployment log..."

DEPLOYMENT_LOG="/var/log/container/deployment.log"
DEPLOYMENT_LOG_LOCK="/var/log/container/deployment.log.lock"

# Function to safely write to deployment log (thread-safe)
safe_log_write() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local full_message="[$timestamp] $message"
    
    # Use flock for file locking to prevent race conditions
    (
        flock -w 5 200 || {
            echo "Failed to acquire lock for deployment.log" >&2
            return 1
        }
        echo "$full_message" >> "$DEPLOYMENT_LOG"
    ) 200>"$DEPLOYMENT_LOG_LOCK"
}

# Check if deployment.log already exists
if [ -f "$DEPLOYMENT_LOG" ]; then
    log "Deployment log already exists, preserving existing file"
    # Only fix permissions if file exists
    chown hexo:hexo "$DEPLOYMENT_LOG"
    chmod 664 "$DEPLOYMENT_LOG"
    log "Fixed permissions for existing deployment.log"
    
    # Add a restart separator to distinguish new session from old logs
    safe_log_write "========== Container Restart $(date) =========="
else
    # Only create if it doesn't exist
    log "Creating new deployment.log file"
    touch "$DEPLOYMENT_LOG"
    chown hexo:hexo "$DEPLOYMENT_LOG"
    chmod 664 "$DEPLOYMENT_LOG"
    safe_log_write "Container startup - deployment.log initialized"
    log "New deployment.log created with correct ownership"
fi

# Ensure lock file has correct permissions (critical fix for Git Hook access)
log "Setting up deployment log lock file permissions..."
if [ -f "$DEPLOYMENT_LOG_LOCK" ]; then
    log "Lock file exists (pre-created in Dockerfile), verifying permissions"
    # Verify and fix permissions if needed
    current_owner=$(stat -c '%U:%G' "$DEPLOYMENT_LOG_LOCK" 2>/dev/null || echo "unknown:unknown")
    if [ "$current_owner" != "hexo:hexo" ]; then
        log "Fixing lock file ownership from $current_owner to hexo:hexo"
        chown hexo:hexo "$DEPLOYMENT_LOG_LOCK"
    fi
    chmod 664 "$DEPLOYMENT_LOG_LOCK"
    log "Lock file permissions verified and corrected if needed"
else
    log "Lock file not found, creating with correct permissions (fallback)"
    touch "$DEPLOYMENT_LOG_LOCK"
    chown hexo:hexo "$DEPLOYMENT_LOG_LOCK"
    chmod 664 "$DEPLOYMENT_LOG_LOCK"
    log "Lock file created as fallback"
fi

log "Deployment log setup completed"

# Enhanced log rotation with conflict resolution
setup_log_rotation() {
    log "Starting log rotation service..."
    while true; do
        sleep 1800  # 30 minutes
        log "Running scheduled log rotation check..."
        
        # Use flock to prevent conflicts with log monitoring
        (
            flock -w 10 201 || {
                log_warn "Could not acquire rotation lock, skipping this cycle"
                continue
            }
            
            # Run logrotate if the log file exists and is large enough
            if [ -f "$DEPLOYMENT_LOG" ]; then
                LOG_SIZE=$(stat -c%s "$DEPLOYMENT_LOG" 2>/dev/null || echo 0)
                if [ "$LOG_SIZE" -gt 20480 ]; then  # 20KB
                    log "Log file size ($LOG_SIZE bytes) exceeds 20KB, running logrotate..."
                    
                    # Create backup before rotation
                    BACKUP_FILE="${DEPLOYMENT_LOG}.$(date +%Y%m%d_%H%M%S)"
                    cp "$DEPLOYMENT_LOG" "$BACKUP_FILE"
                    
                    # Truncate original file instead of removing it (safer for tail -f)
                    > "$DEPLOYMENT_LOG"
                    chown hexo:hexo "$DEPLOYMENT_LOG"
                    chmod 664 "$DEPLOYMENT_LOG"
                    
                    # Compress backup
                    gzip "$BACKUP_FILE" 2>/dev/null || log_warn "Failed to compress backup"
                    
                    # Keep only last 5 backups
                    ls -t "${DEPLOYMENT_LOG}".*.gz 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
                    
                    safe_log_write "Log rotation completed - file size was $LOG_SIZE bytes"
                    log "Deployment log rotation completed"
                else
                    log "Log file size ($LOG_SIZE bytes) is under 20KB threshold, skipping rotation"
                fi
            else
                log "No deployment.log file found, skipping rotation"
            fi
            
        ) 201>"${DEPLOYMENT_LOG_LOCK}.rotation"
        
        # Check nginx logs
        for logfile in /var/log/nginx/access.log /var/log/nginx/error.log; do
            if [ -f "$logfile" ] && [ $(stat -c%s "$logfile" 2>/dev/null || echo 0) -gt 52428800 ]; then
                log "Rotating $(basename $logfile) (>50MB)"
                mv "$logfile" "$logfile.$(date +%Y%m%d_%H%M%S)"
                touch "$logfile"
                chown hexo:hexo "$logfile"
                chmod 664 "$logfile"
                
                # Reload nginx to reopen log files
                nginx -s reload
                
                # Keep only last 3 rotated logs
                ls -t "$logfile".* 2>/dev/null | tail -n +4 | xargs rm -f 2>/dev/null || true
            fi
        done
    done
}

# Enhanced deployment log monitoring with error recovery and restart-safe mode
setup_deployment_monitor() {
    log "Setting up deployment log monitoring..."
    
    local monitor_pid_file="/var/run/deployment_monitor.pid"
    local position_file="/var/run/deployment_monitor.pos"
    
    # Check if deployment log exists and get current size for restart-safe monitoring
    if [ -f "$DEPLOYMENT_LOG" ]; then
        local current_size=$(stat -c%s "$DEPLOYMENT_LOG" 2>/dev/null || echo 0)
        log "Deployment log exists ($current_size bytes), will monitor only NEW entries to avoid duplicate output"
        # Store current position to skip existing content on container restart
        echo "$current_size" > "$position_file"
    else
        # New deployment log, start monitoring from beginning
        echo "0" > "$position_file"
        log "New deployment log, will monitor all entries"
    fi
    
    while true; do
        # Use tail with --bytes to skip existing content on restart
        if [ -f "$position_file" ]; then
            local start_pos=$(cat "$position_file" 2>/dev/null || echo 0)
            if [ "$start_pos" -gt 0 ]; then
                # Skip existing content by using tail with --bytes=+N to start from position N
                tail -F --bytes=+$((start_pos + 1)) "$DEPLOYMENT_LOG" 2>/dev/null | while IFS= read -r line; do
                    # Add prefix to distinguish deployment logs in container output
                    echo "[DEPLOY] $line"
                done &
            else
                # Start from beginning for new files
                tail -F "$DEPLOYMENT_LOG" 2>/dev/null | while IFS= read -r line; do
                    # Add prefix to distinguish deployment logs in container output
                    echo "[DEPLOY] $line"
                done &
            fi
        else
            # Fallback to normal tail if position file doesn't exist
            tail -F "$DEPLOYMENT_LOG" 2>/dev/null | while IFS= read -r line; do
                # Add prefix to distinguish deployment logs in container output
                echo "[DEPLOY] $line"
            done &
        fi
        
        local tail_pid=$!
        echo $tail_pid > "$monitor_pid_file"
        log "Deployment log monitor started (PID: $tail_pid) - monitoring from position $(cat "$position_file" 2>/dev/null || echo 0)"
        
        # Wait for the tail process
        wait $tail_pid
        
        # If tail exits, log the error and restart after a delay
        local exit_code=$?
        log_warn "Deployment log monitor exited (code: $exit_code), restarting in 5 seconds..."
        sleep 5
    done
}

# Cleanup function for graceful shutdown
cleanup() {
    log "Received shutdown signal, cleaning up..."
    
    # Kill deployment monitor if running
    if [ -f /var/run/deployment_monitor.pid ]; then
        local monitor_pid=$(cat /var/run/deployment_monitor.pid 2>/dev/null)
        if [ -n "$monitor_pid" ] && kill -0 "$monitor_pid" 2>/dev/null; then
            log "Stopping deployment monitor (PID: $monitor_pid)"
            kill "$monitor_pid" 2>/dev/null || true
        fi
        rm -f /var/run/deployment_monitor.pid
        rm -f /var/run/deployment_monitor.pos  # Clean up position file
    fi
    
    # Stop services gracefully
    log "Stopping nginx..."
    nginx -s quit 2>/dev/null || true
    
    log "Stopping SSH daemon..."
    pkill sshd 2>/dev/null || true
    
    # Final log entry
    safe_log_write "Container shutdown completed"
    
    exit 0
}

# Set up signal handlers for graceful shutdown
trap cleanup SIGTERM SIGINT

# Start log rotation in background
setup_log_rotation &
LOG_ROTATION_PID=$!

# Start SSH daemon
log "Starting SSH daemon..."
/usr/sbin/sshd -D &
SSHD_PID=$!

# Start nginx
log "Starting nginx..."
nginx -g "daemon off;" &
NGINX_PID=$!

# Create a simple health check endpoint
cat > /home/www/hexo/health <<EOF
#!/bin/bash
echo "Content-Type: text/plain"
echo ""
echo "OK"
EOF
chmod +x /home/www/hexo/health

# Log initial startup completion
safe_log_write "Container startup completed successfully"

log "Container started successfully!"
log "Services running:"
log "  - SSH daemon (port 22, PID: $SSHD_PID)"
log "  - Nginx web server (port 80, PID: $NGINX_PID)"
log "  - Log rotation (every 30 minutes, PID: $LOG_ROTATION_PID)"
log "  - Health check endpoint: /health"

# Start deployment log monitoring in background
setup_deployment_monitor &
MONITOR_PID=$!

# Enhanced process monitoring with restart capability
monitor_services() {
    while true; do
        # Check if nginx is still running
        if ! kill -0 "$NGINX_PID" 2>/dev/null; then
            log_error "Nginx died, restarting..."
            safe_log_write "Nginx service died, restarting"
            nginx -g "daemon off;" &
            NGINX_PID=$!
            log "Nginx restarted (new PID: $NGINX_PID)"
        fi
        
        # Check if sshd is still running
        if ! kill -0 "$SSHD_PID" 2>/dev/null; then
            log_error "SSH daemon died, restarting..."
            safe_log_write "SSH daemon died, restarting"
            /usr/sbin/sshd -D &
            SSHD_PID=$!
            log "SSH daemon restarted (new PID: $SSHD_PID)"
        fi
        
        # Check if log rotation is still running
        if ! kill -0 "$LOG_ROTATION_PID" 2>/dev/null; then
            log_error "Log rotation died, restarting..."
            safe_log_write "Log rotation service died, restarting"
            setup_log_rotation &
            LOG_ROTATION_PID=$!
            log "Log rotation restarted (new PID: $LOG_ROTATION_PID)"
        fi
        
        # Check if deployment monitor is still running
        if ! kill -0 "$MONITOR_PID" 2>/dev/null; then
            log_error "Deployment monitor died, restarting..."
            safe_log_write "Deployment monitor died, restarting"
            setup_deployment_monitor &
            MONITOR_PID=$!
            log "Deployment monitor restarted (new PID: $MONITOR_PID)"
        fi
        
        sleep 30
    done
}

# Start service monitoring
monitor_services
