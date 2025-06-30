#!/bin/bash

# Ruby Environment Fix Script for Dental System
# This script helps fix Ruby version issues and install Rails

set -e

echo "🔧 Fixing Ruby Environment for Dental System..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓ $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗ $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ $1${NC}"
}

# Check current Ruby setup
check_current_setup() {
    echo ""
    info "Current Ruby Setup:"
    echo "-------------------"
    echo "Ruby version: $(ruby -v 2>/dev/null || echo 'Ruby not found')"
    echo "Gem version: $(gem -v 2>/dev/null || echo 'Gem not found')"
    echo "Bundler: $(bundle -v 2>/dev/null || echo 'Bundler not found')"
    echo "Rails: $(rails -v 2>/dev/null || echo 'Rails not found')"
    echo ""
}

# Setup rbenv
setup_rbenv() {
    log "Setting up rbenv environment..."
    
    # Check if rbenv is installed
    if ! command -v rbenv >/dev/null 2>&1; then
        error "rbenv not found. Please install rbenv first:"
        echo "  brew install rbenv ruby-build"
        exit 1
    fi
    
    # Initialize rbenv
    eval "$(rbenv init -)"
    
    # Check if Ruby 3.3.8 is installed
    if ! rbenv versions | grep -q "3.3.8"; then
        warn "Ruby 3.3.8 not installed. Installing..."
        rbenv install 3.3.8
    fi
    
    # Set local Ruby version
    rbenv local 3.3.8
    rbenv rehash
    
    log "rbenv configured for Ruby 3.3.8"
}

# Fix shell configuration
fix_shell_config() {
    log "Updating shell configuration..."
    
    SHELL_CONFIG=""
    if [ -f "$HOME/.zshrc" ]; then
        SHELL_CONFIG="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        SHELL_CONFIG="$HOME/.bashrc"
    else
        warn "No shell configuration file found"
        return
    fi
    
    # Check if rbenv init is already in shell config
    if ! grep -q "rbenv init" "$SHELL_CONFIG"; then
        echo "" >> "$SHELL_CONFIG"
        echo "# rbenv configuration" >> "$SHELL_CONFIG"
        echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> "$SHELL_CONFIG"
        echo 'eval "$(rbenv init -)"' >> "$SHELL_CONFIG"
        info "Added rbenv to $SHELL_CONFIG"
    fi
    
    # Source the configuration
    source "$SHELL_CONFIG"
    
    log "Shell configuration updated"
}

# Install Ruby gems
install_gems() {
    log "Installing Ruby gems..."
    
    # Use rbenv exec to ensure correct Ruby version
    rbenv exec gem install bundler
    
    # Configure bundler
    rbenv exec bundle config set --local path 'vendor/bundle'
    
    # Install gems (continue even if some fail)
    rbenv exec bundle install || warn "Some gems failed to install"
    
    log "Gem installation complete"
}

# Create Gemfile.lock if missing
create_gemfile_lock() {
    if [ ! -f "Gemfile.lock" ]; then
        log "Creating Gemfile.lock..."
        rbenv exec bundle lock --add-platform ruby
        rbenv exec bundle lock --add-platform x86_64-darwin
        rbenv exec bundle lock --add-platform x86_64-linux
    fi
}

# Quick environment test
test_environment() {
    log "Testing Ruby environment..."
    
    echo ""
    info "Environment Test Results:"
    echo "------------------------"
    
    # Test Ruby
    if rbenv exec ruby -v | grep -q "3.3.8"; then
        echo "✓ Ruby 3.3.8 is active"
    else
        error "✗ Ruby version mismatch"
    fi
    
    # Test bundler
    if rbenv exec bundle -v >/dev/null 2>&1; then
        echo "✓ Bundler is installed"
    else
        error "✗ Bundler not found"
    fi
    
    # Test Rails
    if rbenv exec bundle exec rails -v 2>/dev/null | grep -q "Rails"; then
        echo "✓ Rails is available"
    else
        warn "✗ Rails not available (run 'bundle install')"
    fi
    
    echo ""
}

# Generate quick start guide
generate_quickstart() {
    cat > RUBY_ENV_FIXED.md << 'EOF'
# Ruby Environment Fixed! 🎉

Your Ruby environment has been configured for the Dental System project.

## Quick Start Commands

```bash
# Always use these commands in the project directory:

# Run bundle commands
rbenv exec bundle install
rbenv exec bundle exec rails server

# Or source your shell first
source ~/.zshrc  # or ~/.bashrc
bundle install
bundle exec rails server
```

## Verify Setup

```bash
# Check Ruby version
ruby -v  # Should show 3.3.8

# Check Rails
bundle exec rails -v  # Should show Rails 7.2.x
```

## Next Steps

1. Install remaining dependencies:
   ```bash
   rbenv exec bundle install
   ```

2. Set up the database:
   ```bash
   rbenv exec bundle exec rails db:create
   rbenv exec bundle exec rails db:migrate
   ```

3. Start the development server:
   ```bash
   rbenv exec bundle exec rails server
   ```

## Troubleshooting

If you still see Ruby 2.6.10:
1. Close and reopen your terminal
2. Run: `source ~/.zshrc`
3. Navigate back to the project directory
4. Run: `rbenv local 3.3.8`

EOF
    
    log "Created RUBY_ENV_FIXED.md with instructions"
}

# Main process
main() {
    echo ""
    echo "===================================="
    echo "Ruby Environment Fix for Dental System"
    echo "===================================="
    
    check_current_setup
    setup_rbenv
    fix_shell_config
    
    # Re-source to apply changes
    eval "$(rbenv init -)"
    
    create_gemfile_lock
    install_gems
    test_environment
    generate_quickstart
    
    echo ""
    echo "===================================="
    log "🎉 Ruby environment fix complete!"
    echo "===================================="
    echo ""
    info "IMPORTANT: Run these commands now:"
    echo ""
    echo "1. source ~/.zshrc  # or source ~/.bashrc"
    echo "2. cd $(pwd)"
    echo "3. ruby -v  # Should show 3.3.8"
    echo "4. bundle install  # Install remaining gems"
    echo ""
    info "See RUBY_ENV_FIXED.md for detailed instructions"
    echo ""
}

# Check if we're in the right directory
if [ ! -f "Gemfile" ]; then
    error "Gemfile not found. Please run this script from the Dental System project root."
    exit 1
fi

# Run main
main "$@"