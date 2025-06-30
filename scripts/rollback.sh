#!/bin/bash

# Dental System Production Rollback Script
# This script rolls back the application to the previous version

set -e  # Exit on any error

echo "🔄 Starting rollback to previous version..."

# Configuration
INSTANCE_NAME="${LIGHTSAIL_INSTANCE_NAME}"
DEPLOY_USER="ubuntu"
APP_DIR="/var/www/dentalsystem"
BACKUP_DIR="/var/backups/dentalsystem"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Get Lightsail instance IP
get_instance_ip() {
    log "Getting Lightsail instance IP..."
    
    INSTANCE_IP=$(aws lightsail get-instance \
        --instance-name "$INSTANCE_NAME" \
        --query 'instance.publicIpAddress' \
        --output text 2>/dev/null)
    
    if [ "$INSTANCE_IP" = "None" ] || [ -z "$INSTANCE_IP" ]; then
        error "Could not get IP address for instance $INSTANCE_NAME"
    fi
    
    log "Instance IP: $INSTANCE_IP"
}

# Setup SSH connection
setup_ssh() {
    log "Setting up SSH connection..."
    
    # Create SSH key from environment variable if provided
    if [ -n "$DEPLOY_KEY" ]; then
        echo "$DEPLOY_KEY" | base64 -d > /tmp/deploy_key
        chmod 600 /tmp/deploy_key
        SSH_KEY_ARG="-i /tmp/deploy_key"
    else
        SSH_KEY_ARG=""
    fi
    
    # SSH options for automation
    SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
    
    # Test SSH connection
    if ! ssh $SSH_OPTS $SSH_KEY_ARG $DEPLOY_USER@$INSTANCE_IP "echo 'SSH connection successful'" >/dev/null 2>&1; then
        error "Cannot establish SSH connection to $INSTANCE_IP"
    fi
    
    log "SSH connection established"
}

# Perform rollback
perform_rollback() {
    log "Performing rollback..."
    
    ssh $SSH_OPTS $SSH_KEY_ARG $DEPLOY_USER@$INSTANCE_IP << 'EOF'
        # Stop services
        echo "Stopping services..."
        sudo systemctl stop dentalsystem || true
        
        # Find latest backup
        LATEST_BACKUP=$(sudo find /var/backups/dentalsystem -name "backup_*.tar.gz" -type f | sort -r | head -1)
        
        if [ -z "$LATEST_BACKUP" ]; then
            echo "❌ No backup found to restore"
            exit 1
        fi
        
        echo "Found backup: $LATEST_BACKUP"
        
        # Backup current state before rollback
        ROLLBACK_BACKUP="/var/backups/dentalsystem/pre_rollback_$(date +%Y%m%d_%H%M%S).tar.gz"
        sudo tar -czf "$ROLLBACK_BACKUP" -C /var/www dentalsystem/ || true
        echo "Current state backed up to: $ROLLBACK_BACKUP"
        
        # Remove current application
        sudo rm -rf /var/www/dentalsystem
        
        # Restore from backup
        echo "Restoring from backup..."
        sudo tar -xzf "$LATEST_BACKUP" -C /var/www/
        sudo chown -R ubuntu:ubuntu /var/www/dentalsystem
        
        # Restore database if backup exists
        DB_BACKUP=$(sudo find /var/backups/dentalsystem -name "db_backup_*.sql" -type f | sort -r | head -1)
        if [ -n "$DB_BACKUP" ]; then
            echo "Restoring database from: $DB_BACKUP"
            cd /var/www/dentalsystem
            source .env
            PGPASSWORD=$(echo $DATABASE_URL | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p') \
                psql $DATABASE_URL < "$DB_BACKUP" || true
        fi
        
        # Start services
        echo "Starting services..."
        sudo systemctl start dentalsystem
        sudo systemctl restart nginx
        
        # Check service status
        sleep 10
        
        if sudo systemctl is-active --quiet dentalsystem; then
            echo "✅ Dental System service is running"
        else
            echo "❌ Dental System service failed to start"
            sudo systemctl status dentalsystem
            exit 1
        fi
        
        echo "Rollback completed successfully"
EOF
    
    log "Rollback completed"
}

# Health check
health_check() {
    log "Performing health check..."
    
    # Wait for application to start
    sleep 20
    
    # Check if application responds
    if curl -f -s "http://$INSTANCE_IP/health" >/dev/null; then
        log "✅ Health check passed"
    else
        warn "Health check endpoint not responding, checking basic connectivity..."
        
        if curl -f -s "http://$INSTANCE_IP/" >/dev/null; then
            log "✅ Application is responding"
        else
            error "❌ Application is not responding after rollback"
        fi
    fi
}

# Cleanup
cleanup() {
    log "Cleaning up..."
    rm -f /tmp/deploy_key
    log "Cleanup completed"
}

# Main rollback process
main() {
    log "Starting Dental System rollback"
    
    get_instance_ip
    setup_ssh
    perform_rollback
    health_check
    cleanup
    
    log "🔄 Rollback completed successfully!"
    log "Application has been rolled back at: http://$INSTANCE_IP"
}

# Trap to cleanup on script exit
trap cleanup EXIT

# Run main function
main "$@"