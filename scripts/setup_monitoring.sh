#!/bin/bash
# Setup monitoring for Dental System Production

set -e

echo "Setting up monitoring for Dental System..."

# Variables
DOMAIN="dental-system.example.com"
UPTIME_ROBOT_API_KEY="${UPTIME_ROBOT_API_KEY}"
GRAFANA_CLOUD_API_KEY="${GRAFANA_CLOUD_API_KEY}"

# Function to setup UptimeRobot monitoring
setup_uptime_robot() {
    echo "Setting up UptimeRobot monitoring..."
    
    # Create HTTP monitor
    curl -X POST "https://api.uptimerobot.com/v2/newMonitor" \
        -d "api_key=${UPTIME_ROBOT_API_KEY}" \
        -d "format=json" \
        -d "type=1" \
        -d "url=https://${DOMAIN}/up" \
        -d "friendly_name=Dental System - Main Site" \
        -d "interval=300" \
        -d "timeout=30" \
        -d "alert_contacts=email:admin@example.com"

    # Create SSL monitor
    curl -X POST "https://api.uptimerobot.com/v2/newMonitor" \
        -d "api_key=${UPTIME_ROBOT_API_KEY}" \
        -d "format=json" \
        -d "type=4" \
        -d "url=${DOMAIN}" \
        -d "friendly_name=Dental System - SSL Certificate" \
        -d "interval=86400" \
        -d "alert_contacts=email:admin@example.com"

    echo "UptimeRobot monitors created successfully"
}

# Function to setup Grafana Cloud logging
setup_grafana_logging() {
    echo "Setting up Grafana Cloud logging..."

    # Install Grafana Agent
    if ! command -v grafana-agent &> /dev/null; then
        echo "Installing Grafana Agent..."
        wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
        echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
        sudo apt-get update
        sudo apt-get install -y grafana-agent
    fi

    # Create Grafana Agent configuration
    cat > /tmp/grafana-agent.yml << 'EOF'
server:
  http_listen_port: 12345

logs:
  configs:
  - name: dental-system-logs
    clients:
    - url: https://logs-prod-us-central1.grafana.net/loki/api/v1/push
      basic_auth:
        username: "${GRAFANA_CLOUD_LOGS_USERNAME}"
        password: "${GRAFANA_CLOUD_API_KEY}"
    scrape_configs:
    - job_name: nginx
      static_configs:
      - targets:
        - localhost
        labels:
          job: nginx
          __path__: /var/log/nginx/*.log
    - job_name: rails
      static_configs:
      - targets:
        - localhost
        labels:
          job: rails
          __path__: /var/www/dental_system/shared/log/*.log
    - job_name: docker
      docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
      relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)'
        target_label: 'container_name'
      - source_labels: ['__meta_docker_container_log_stream']
        target_label: 'stream'

metrics:
  configs:
  - name: dental-system-metrics
    remote_write:
    - url: https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push
      basic_auth:
        username: "${GRAFANA_CLOUD_PROMETHEUS_USERNAME}"
        password: "${GRAFANA_CLOUD_API_KEY}"
    scrape_configs:
    - job_name: 'nginx'
      static_configs:
      - targets: ['localhost:9113']
    - job_name: 'rails'
      static_configs:
      - targets: ['localhost:3000']
      metrics_path: '/metrics'
    - job_name: 'postgresql'
      static_configs:
      - targets: ['localhost:9187']
    - job_name: 'redis'
      static_configs:
      - targets: ['localhost:9121']
EOF

    sudo mv /tmp/grafana-agent.yml /etc/grafana-agent.yml
    sudo systemctl enable grafana-agent
    sudo systemctl start grafana-agent

    echo "Grafana Cloud logging configured successfully"
}

# Function to setup health checks
setup_health_checks() {
    echo "Setting up health checks..."

    # Create health check script
    cat > /usr/local/bin/health_check.sh << 'EOF'
#!/bin/bash
# Health check script for Dental System

# Check if web service is responding
if ! curl -f -s http://localhost:3000/up > /dev/null; then
    echo "ERROR: Web service is not responding"
    exit 1
fi

# Check if database is accessible
if ! docker compose exec -T db pg_isready -U postgres > /dev/null; then
    echo "ERROR: Database is not accessible"
    exit 1
fi

# Check if Redis is accessible
if ! docker compose exec -T redis redis-cli ping > /dev/null; then
    echo "ERROR: Redis is not accessible"
    exit 1
fi

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 85 ]; then
    echo "WARNING: Disk usage is ${DISK_USAGE}%"
fi

# Check memory usage
MEM_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
if [ "$MEM_USAGE" -gt 90 ]; then
    echo "WARNING: Memory usage is ${MEM_USAGE}%"
fi

echo "Health check passed"
EOF

    chmod +x /usr/local/bin/health_check.sh

    # Setup cron job for health checks
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/health_check.sh >> /var/log/health_check.log 2>&1") | crontab -

    echo "Health checks configured successfully"
}

# Function to setup backup monitoring
setup_backup_monitoring() {
    echo "Setting up backup monitoring..."

    # Create backup verification script
    cat > /usr/local/bin/verify_backups.sh << 'EOF'
#!/bin/bash
# Backup verification script

BACKUP_DIR="/var/backups"
CURRENT_DATE=$(date +%Y%m%d)

# Check if today's backup exists
if [ ! -f "${BACKUP_DIR}/dental_system_${CURRENT_DATE}*.sql" ]; then
    echo "ERROR: No backup found for today"
    # Send alert to monitoring service
    curl -X POST "https://api.uptimerobot.com/v2/newHeartbeat" \
        -d "api_key=${UPTIME_ROBOT_API_KEY}" \
        -d "id=backup_monitor_id" \
        -d "status=0"
    exit 1
fi

# Verify backup integrity
LATEST_BACKUP=$(ls -t ${BACKUP_DIR}/dental_system_*.sql | head -n1)
if ! pg_restore --list "$LATEST_BACKUP" > /dev/null 2>&1; then
    echo "ERROR: Backup integrity check failed"
    exit 1
fi

echo "Backup verification passed"
# Send success heartbeat
curl -X POST "https://api.uptimerobot.com/v2/newHeartbeat" \
    -d "api_key=${UPTIME_ROBOT_API_KEY}" \
    -d "id=backup_monitor_id" \
    -d "status=1"
EOF

    chmod +x /usr/local/bin/verify_backups.sh

    # Setup daily backup verification
    (crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/verify_backups.sh >> /var/log/backup_verify.log 2>&1") | crontab -

    echo "Backup monitoring configured successfully"
}

# Main execution
main() {
    echo "Starting monitoring setup..."

    if [ -z "$UPTIME_ROBOT_API_KEY" ]; then
        echo "WARNING: UPTIME_ROBOT_API_KEY not set, skipping UptimeRobot setup"
    else
        setup_uptime_robot
    fi

    if [ -z "$GRAFANA_CLOUD_API_KEY" ]; then
        echo "WARNING: GRAFANA_CLOUD_API_KEY not set, skipping Grafana setup"
    else
        setup_grafana_logging
    fi

    setup_health_checks
    setup_backup_monitoring

    echo "Monitoring setup completed successfully!"
    echo "Please verify the following:"
    echo "1. Check UptimeRobot dashboard for new monitors"
    echo "2. Verify Grafana Cloud is receiving logs and metrics"
    echo "3. Test health check: /usr/local/bin/health_check.sh"
    echo "4. Check backup verification: /usr/local/bin/verify_backups.sh"
}

# Run main function
main "$@"