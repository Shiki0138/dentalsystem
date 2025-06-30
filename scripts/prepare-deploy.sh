#!/bin/bash

# Dental System Deployment Preparation Script
# This script prepares the application for production deployment

set -e  # Exit on any error

echo "🚀 Preparing Dental System for Production Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓ $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗ ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ $1${NC}"
}

# Check Ruby version
check_ruby_version() {
    log "Checking Ruby version..."
    
    REQUIRED_RUBY="3.3.8"
    CURRENT_RUBY=$(ruby -v | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    
    if [ "$CURRENT_RUBY" != "$REQUIRED_RUBY" ]; then
        error "Ruby version mismatch. Required: $REQUIRED_RUBY, Current: $CURRENT_RUBY"
    fi
    
    log "Ruby version OK: $CURRENT_RUBY"
}

# Install dependencies
install_dependencies() {
    log "Installing Ruby dependencies..."
    
    # Check if bundler is installed
    if ! gem list bundler -i > /dev/null 2>&1; then
        info "Installing bundler..."
        gem install bundler
    fi
    
    # Install gems
    bundle config set --local path 'vendor/bundle'
    bundle install --without development test
    
    log "Dependencies installed successfully"
}

# Create production environment file
create_env_file() {
    log "Creating production environment file..."
    
    if [ -f ".env.production" ]; then
        warn ".env.production already exists. Backing up..."
        cp .env.production .env.production.backup.$(date +%Y%m%d_%H%M%S)
    fi
    
    # Copy from example if .env.production doesn't exist
    if [ ! -f ".env.production" ]; then
        if [ -f ".env.production.example" ]; then
            cp .env.production.example .env.production
            info "Created .env.production from example. Please update with actual values."
        else
            error ".env.production.example not found!"
        fi
    fi
    
    log "Environment file ready"
}

# Generate secret key base
generate_secret_key() {
    log "Generating secret key base..."
    
    if [ -f ".env.production" ] && grep -q "SECRET_KEY_BASE=your" .env.production; then
        SECRET_KEY=$(openssl rand -hex 64)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s/SECRET_KEY_BASE=.*/SECRET_KEY_BASE=$SECRET_KEY/" .env.production
        else
            # Linux
            sed -i "s/SECRET_KEY_BASE=.*/SECRET_KEY_BASE=$SECRET_KEY/" .env.production
        fi
        info "Generated new SECRET_KEY_BASE"
    fi
    
    log "Secret key configuration complete"
}

# Check required environment variables
check_env_vars() {
    log "Checking required environment variables..."
    
    MISSING_VARS=()
    
    # Load .env.production
    if [ -f ".env.production" ]; then
        set -a
        source .env.production
        set +a
    fi
    
    # Check critical variables
    REQUIRED_VARS=(
        "SECRET_KEY_BASE"
        "DATABASE_URL"
        "REDIS_URL"
        "RAILS_ENV"
    )
    
    for var in "${REQUIRED_VARS[@]}"; do
        if [ -z "${!var}" ] || [[ "${!var}" == *"your"* ]] || [[ "${!var}" == *"example"* ]]; then
            MISSING_VARS+=("$var")
        fi
    done
    
    if [ ${#MISSING_VARS[@]} -gt 0 ]; then
        warn "Missing or invalid environment variables:"
        for var in "${MISSING_VARS[@]}"; do
            echo "  - $var"
        done
        echo ""
        info "Please update .env.production with actual values before deployment."
    else
        log "All required environment variables are set"
    fi
}

# Compile assets
compile_assets() {
    log "Compiling assets for production..."
    
    # Set production environment
    export RAILS_ENV=production
    export NODE_ENV=production
    
    # Precompile assets
    bundle exec rails assets:precompile
    
    log "Assets compiled successfully"
}

# Database setup check
check_database() {
    log "Checking database configuration..."
    
    if [ -f ".env.production" ]; then
        source .env.production
    fi
    
    if [ -z "$DATABASE_URL" ] || [[ "$DATABASE_URL" == *"example"* ]]; then
        warn "DATABASE_URL not configured. Please set up PostgreSQL and update .env.production"
        echo ""
        info "Example DATABASE_URL format:"
        echo "  postgresql://username:password@localhost:5432/dentalsystem_production"
    else
        log "Database configuration found"
    fi
}

# Create deployment package
create_deployment_package() {
    log "Creating deployment package..."
    
    DEPLOY_DIR="deployment_package"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    PACKAGE_NAME="dentalsystem_deploy_${TIMESTAMP}.tar.gz"
    
    # Create deployment directory
    mkdir -p $DEPLOY_DIR
    
    # Copy necessary files
    rsync -av --exclude-from='.gitignore' \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='tmp/*' \
        --exclude='log/*' \
        --exclude='storage/*' \
        --exclude='vendor/bundle' \
        --exclude='.env*' \
        --exclude='deployment_package' \
        --exclude='*.tar.gz' \
        . $DEPLOY_DIR/
    
    # Copy production environment file
    if [ -f ".env.production" ]; then
        cp .env.production $DEPLOY_DIR/.env
    fi
    
    # Create deployment archive
    tar -czf $PACKAGE_NAME -C $DEPLOY_DIR .
    
    # Cleanup
    rm -rf $DEPLOY_DIR
    
    log "Deployment package created: $PACKAGE_NAME"
    info "Package size: $(du -h $PACKAGE_NAME | cut -f1)"
}

# Generate deployment checklist
generate_checklist() {
    log "Generating deployment checklist..."
    
    cat > deployment_checklist.md << 'EOF'
# Dental System Production Deployment Checklist

## Pre-deployment

- [ ] Ruby 3.3.8 installed on production server
- [ ] PostgreSQL database server running
- [ ] Redis server running
- [ ] Nginx configured
- [ ] SSL certificate installed
- [ ] Domain name configured

## Environment Variables

Update `.env.production` with actual values:

- [ ] SECRET_KEY_BASE (generated automatically)
- [ ] DATABASE_URL
- [ ] REDIS_URL
- [ ] SMTP settings for email
- [ ] LINE API credentials (if using)
- [ ] AWS credentials (for backups)

## Server Setup

1. [ ] Create deployment user
2. [ ] Set up SSH keys
3. [ ] Configure firewall
4. [ ] Install system dependencies
5. [ ] Set up systemd services

## Deployment Steps

1. [ ] Upload deployment package
2. [ ] Extract files
3. [ ] Install Ruby gems
4. [ ] Run database migrations
5. [ ] Compile assets
6. [ ] Start application services
7. [ ] Configure Nginx
8. [ ] Test application

## Post-deployment

- [ ] Verify all services running
- [ ] Test user registration
- [ ] Test appointment booking
- [ ] Set up monitoring
- [ ] Configure backups
- [ ] Update DNS records

## Security

- [ ] Change default passwords
- [ ] Enable firewall rules
- [ ] Set up fail2ban
- [ ] Configure SSL/TLS
- [ ] Review security headers

EOF
    
    log "Deployment checklist created: deployment_checklist.md"
}

# Main preparation process
main() {
    echo ""
    echo "==================================="
    echo "Dental System Deployment Preparation"
    echo "==================================="
    echo ""
    
    # Ruby environment check
    if command -v rbenv >/dev/null 2>&1; then
        info "Using rbenv Ruby environment"
        eval "$(rbenv init -)"
        rbenv local 3.3.8
    fi
    
    check_ruby_version
    install_dependencies
    create_env_file
    generate_secret_key
    check_env_vars
    check_database
    
    # Ask before compiling assets
    echo ""
    read -p "Compile assets for production? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        compile_assets
    fi
    
    # Ask before creating package
    echo ""
    read -p "Create deployment package? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_deployment_package
    fi
    
    generate_checklist
    
    echo ""
    echo "==================================="
    log "🎉 Deployment preparation complete!"
    echo "==================================="
    echo ""
    info "Next steps:"
    echo "1. Review and update .env.production with actual values"
    echo "2. Review deployment_checklist.md"
    echo "3. Set up production server"
    echo "4. Run deployment script: ./scripts/deploy.sh"
    echo ""
}

# Run main function
main "$@"