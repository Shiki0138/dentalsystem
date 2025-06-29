#!/bin/bash

# Dental System Production Deployment Script
# This script deploys the application to AWS Lightsail

set -e  # Exit on any error

echo "🚀 Starting deployment to production..."

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

# Check required environment variables
check_env_vars() {
    log "Checking environment variables..."
    
    required_vars=(
        "LIGHTSAIL_INSTANCE_NAME"
        "AWS_ACCESS_KEY_ID"
        "AWS_SECRET_ACCESS_KEY"
        "AWS_REGION"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            error "Required environment variable $var is not set"
        fi
    done
    
    log "Environment variables check passed"
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

# Create application backup
create_backup() {
    log "Creating application backup..."
    
    ssh $SSH_OPTS $SSH_KEY_ARG $DEPLOY_USER@$INSTANCE_IP << 'EOF'
        sudo mkdir -p /var/backups/dentalsystem
        BACKUP_FILE="/var/backups/dentalsystem/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        
        if [ -d "/var/www/dentalsystem" ]; then
            sudo tar -czf "$BACKUP_FILE" -C /var/www dentalsystem/ || true
            echo "Backup created: $BACKUP_FILE"
        else
            echo "No existing application found, skipping backup"
        fi
        
        # Keep only last 5 backups
        sudo find /var/backups/dentalsystem -name "backup_*.tar.gz" -type f | sort -r | tail -n +6 | sudo xargs rm -f || true
EOF
    
    log "Backup completed"
}

# Deploy application code
deploy_code() {
    log "Deploying application code..."
    
    # Create deployment archive
    tar -czf /tmp/dentalsystem.tar.gz \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='tmp' \
        --exclude='log' \
        --exclude='coverage' \
        --exclude='.env*' \
        .
    
    # Copy to server
    scp $SSH_OPTS $SSH_KEY_ARG /tmp/dentalsystem.tar.gz $DEPLOY_USER@$INSTANCE_IP:/tmp/
    
    # Extract and setup on server
    ssh $SSH_OPTS $SSH_KEY_ARG $DEPLOY_USER@$INSTANCE_IP << 'EOF'
        # Create application directory
        sudo mkdir -p /var/www/dentalsystem
        
        # Extract new code
        cd /tmp
        sudo tar -xzf dentalsystem.tar.gz -C /var/www/
        sudo chown -R ubuntu:ubuntu /var/www/dentalsystem
        
        # Set permissions
        sudo chmod +x /var/www/dentalsystem/bin/*
        
        echo "Code deployment completed"
EOF
    
    log "Code deployment completed"
}

# Setup production environment
setup_environment() {
    log "Setting up production environment..."
    
    # Create production environment file
    cat > /tmp/production.env << EOF
RAILS_ENV=production
SECRET_KEY_BASE=${SECRET_KEY_BASE}
DATABASE_URL=${DATABASE_URL}
REDIS_URL=${REDIS_URL}
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true
EOF
    
    # Copy environment file to server
    scp $SSH_OPTS $SSH_KEY_ARG /tmp/production.env $DEPLOY_USER@$INSTANCE_IP:/tmp/
    
    ssh $SSH_OPTS $SSH_KEY_ARG $DEPLOY_USER@$INSTANCE_IP << 'EOF'
        cd /var/www/dentalsystem
        
        # Setup environment file
        sudo cp /tmp/production.env .env
        sudo chown ubuntu:ubuntu .env
        sudo chmod 600 .env
        
        echo "Environment setup completed"
EOF
    
    log "Environment setup completed"
}

# Install dependencies and setup database
setup_application() {
    log "Setting up application dependencies and database..."
    
    ssh $SSH_OPTS $SSH_KEY_ARG $DEPLOY_USER@$INSTANCE_IP << 'EOF'
        cd /var/www/dentalsystem
        
        # Load environment
        source .env
        
        # Install Ruby dependencies
        if command -v bundle >/dev/null 2>&1; then
            echo "Installing Ruby gems..."
            bundle install --deployment --without development test
        else
            echo "Bundler not found, installing..."
            gem install bundler
            bundle install --deployment --without development test
        fi
        
        # Install Node.js dependencies if package.json exists
        if [ -f "package.json" ]; then
            echo "Installing Node.js dependencies..."
            npm ci --production
        fi
        
        # Setup database
        echo "Setting up database..."
        bundle exec rails db:migrate RAILS_ENV=production
        
        # Precompile assets
        echo "Precompiling assets..."
        bundle exec rails assets:precompile RAILS_ENV=production
        
        echo "Application setup completed"
EOF
    
    log "Application setup completed"
}

# Setup system services
setup_services() {
    log "Setting up system services..."
    
    # Create systemd service file
    cat > /tmp/dentalsystem.service << 'EOF'
[Unit]
Description=Dental System Rails Application
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/var/www/dentalsystem
Environment=RAILS_ENV=production
EnvironmentFile=/var/www/dentalsystem/.env
ExecStart=/usr/local/bin/bundle exec puma -C config/puma.rb
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Create nginx configuration
    cat > /tmp/dentalsystem.nginx << 'EOF'
upstream dentalsystem {
    server 127.0.0.1:3000;
}

server {
    listen 80;
    server_name _;
    
    root /var/www/dentalsystem/public;
    
    location / {
        try_files $uri $uri/index.html $uri.html @dentalsystem;
    }
    
    location @dentalsystem {
        proxy_pass http://dentalsystem;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location ~ ^/(assets|packs)/ {
        expires 1y;
        add_header Cache-Control public;
        add_header ETag "";
        break;
    }
}
EOF
    
    # Copy and setup services
    scp $SSH_OPTS $SSH_KEY_ARG /tmp/dentalsystem.service $DEPLOY_USER@$INSTANCE_IP:/tmp/
    scp $SSH_OPTS $SSH_KEY_ARG /tmp/dentalsystem.nginx $DEPLOY_USER@$INSTANCE_IP:/tmp/
    
    ssh $SSH_OPTS $SSH_KEY_ARG $DEPLOY_USER@$INSTANCE_IP << 'EOF'
        # Setup systemd service
        sudo cp /tmp/dentalsystem.service /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl enable dentalsystem
        
        # Setup nginx
        sudo cp /tmp/dentalsystem.nginx /etc/nginx/sites-available/dentalsystem
        sudo ln -sf /etc/nginx/sites-available/dentalsystem /etc/nginx/sites-enabled/
        sudo rm -f /etc/nginx/sites-enabled/default
        
        # Test nginx configuration
        sudo nginx -t
        
        echo "Services setup completed"
EOF
    
    log "Services setup completed"
}

# Start services
start_services() {
    log "Starting services..."
    
    ssh $SSH_OPTS $SSH_KEY_ARG $DEPLOY_USER@$INSTANCE_IP << 'EOF'
        # Start application
        sudo systemctl restart dentalsystem
        sudo systemctl restart nginx
        
        # Check service status
        sleep 5
        
        if sudo systemctl is-active --quiet dentalsystem; then
            echo "✅ Dental System service is running"
        else
            echo "❌ Dental System service failed to start"
            sudo systemctl status dentalsystem
            exit 1
        fi
        
        if sudo systemctl is-active --quiet nginx; then
            echo "✅ Nginx service is running"
        else
            echo "❌ Nginx service failed to start"
            sudo systemctl status nginx
            exit 1
        fi
EOF
    
    log "Services started successfully"
}

# Health check
health_check() {
    log "Performing health check..."
    
    # Wait for application to start
    sleep 30
    
    # Check if application responds
    if curl -f -s "http://$INSTANCE_IP/health" >/dev/null; then
        log "✅ Health check passed"
    else
        warn "Health check endpoint not responding, checking basic connectivity..."
        
        if curl -f -s "http://$INSTANCE_IP/" >/dev/null; then
            log "✅ Application is responding"
        else
            error "❌ Application is not responding"
        fi
    fi
}

# Cleanup
cleanup() {
    log "Cleaning up..."
    
    # Remove temporary files
    rm -f /tmp/deploy_key
    rm -f /tmp/dentalsystem.tar.gz
    rm -f /tmp/production.env
    rm -f /tmp/dentalsystem.service
    rm -f /tmp/dentalsystem.nginx
    
    log "Cleanup completed"
}

# Main deployment process
main() {
    log "Starting Dental System deployment to production"
    
    check_env_vars
    get_instance_ip
    setup_ssh
    create_backup
    deploy_code
    setup_environment
    setup_application
    setup_services
    start_services
    health_check
    cleanup
    
    log "🎉 Deployment completed successfully!"
    log "Application is available at: http://$INSTANCE_IP"
}

# Trap to cleanup on script exit
trap cleanup EXIT

# Run main function
main "$@"