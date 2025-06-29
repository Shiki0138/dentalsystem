#!/bin/bash

# Health check script for Dental System
# This script monitors the application health and sends alerts if issues are detected

LOG_FILE="/var/log/dental_system/health_check.log"
ERROR_LOG="/var/log/dental_system/health_errors.log"
HEALTH_URL="http://localhost:3000/up"
WEBHOOK_URL="${SLACK_WEBHOOK_URL}"

# Create log directory if it doesn't exist
mkdir -p /var/log/dental_system

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to log errors
log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$ERROR_LOG"
    log_message "ERROR: $1"
}

# Function to send Slack notification
send_alert() {
    local message="$1"
    if [ -n "$WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' \
             --data "{\"text\":\"🚨 Dental System Alert: $message\"}" \
             "$WEBHOOK_URL" 2>/dev/null
    fi
}

# Check application health endpoint
check_app_health() {
    local response=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" 2>/dev/null)
    
    if [ "$response" != "200" ]; then
        log_error "Application health check failed - HTTP $response"
        send_alert "Application is not responding (HTTP $response)"
        return 1
    else
        log_message "Application health check passed"
        return 0
    fi
}

# Check database connectivity
check_database() {
    local db_check=$(docker compose -f docker-compose.production.yml exec -T web bundle exec rails runner "ActiveRecord::Base.connection.execute('SELECT 1')" 2>&1)
    
    if [[ $db_check == *"error"* ]] || [[ $db_check == *"Error"* ]]; then
        log_error "Database connectivity check failed: $db_check"
        send_alert "Database connection error detected"
        return 1
    else
        log_message "Database connectivity check passed"
        return 0
    fi
}

# Check Redis connectivity
check_redis() {
    local redis_check=$(docker compose -f docker-compose.production.yml exec -T redis redis-cli ping 2>&1)
    
    if [ "$redis_check" != "PONG" ]; then
        log_error "Redis connectivity check failed: $redis_check"
        send_alert "Redis connection error detected"
        return 1
    else
        log_message "Redis connectivity check passed"
        return 0
    fi
}

# Check disk space
check_disk_space() {
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$disk_usage" -gt 85 ]; then
        log_error "Disk space critical: ${disk_usage}% used"
        send_alert "Disk space critical: ${disk_usage}% used"
        return 1
    elif [ "$disk_usage" -gt 75 ]; then
        log_message "Disk space warning: ${disk_usage}% used"
        return 0
    else
        log_message "Disk space check passed: ${disk_usage}% used"
        return 0
    fi
}

# Check memory usage
check_memory() {
    local memory_usage=$(free | awk 'NR==2{printf "%.0f", $3/$2*100}')
    
    if [ "$memory_usage" -gt 90 ]; then
        log_error "Memory usage critical: ${memory_usage}%"
        send_alert "Memory usage critical: ${memory_usage}%"
        return 1
    elif [ "$memory_usage" -gt 80 ]; then
        log_message "Memory usage warning: ${memory_usage}%"
        return 0
    else
        log_message "Memory usage check passed: ${memory_usage}%"
        return 0
    fi
}

# Check if containers are running
check_containers() {
    local containers=$(docker compose -f docker-compose.production.yml ps --services | wc -l)
    local running_containers=$(docker compose -f docker-compose.production.yml ps --services --filter "status=running" | wc -l)
    
    if [ "$containers" != "$running_containers" ]; then
        log_error "Not all containers are running: $running_containers/$containers"
        send_alert "Some containers are not running: $running_containers/$containers"
        return 1
    else
        log_message "All containers are running: $running_containers/$containers"
        return 0
    fi
}

# Main health check routine
main() {
    log_message "Starting health check"
    
    local errors=0
    
    # Run all checks
    check_app_health || ((errors++))
    check_database || ((errors++))
    check_redis || ((errors++))
    check_disk_space || ((errors++))
    check_memory || ((errors++))
    check_containers || ((errors++))
    
    if [ $errors -eq 0 ]; then
        log_message "All health checks passed"
        echo "OK"
        exit 0
    else
        log_error "Health check completed with $errors errors"
        echo "ERRORS: $errors"
        exit 1
    fi
}

# Run the health check
main "$@"