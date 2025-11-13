#!/bin/bash

# Alert Dispatcher Script
# Fetches alerts from Prometheus API and logs them locally
# Usage: ./alert_dispatcher.sh [OPTIONS]

set -euo pipefail

# Configuration
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
LOG_FILE="${LOG_FILE:-alerts.log}"
CHECK_INTERVAL="${CHECK_INTERVAL:-30}"
MAX_LOG_SIZE="${MAX_LOG_SIZE:-10485760}" # 10MB
WEBHOOK_URL="${WEBHOOK_URL:-}"
VERBOSE="${VERBOSE:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log messages
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} ${timestamp} - $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} ${timestamp} - $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} ${timestamp} - $message"
            ;;
        "DEBUG")
            if [[ "$VERBOSE" == "true" ]]; then
                echo -e "${BLUE}[DEBUG]${NC} ${timestamp} - $message"
            fi
            ;;
    esac
    
    # Also log to file
    echo "[$level] $timestamp - $message" >> "$LOG_FILE"
}

# Function to rotate log if it gets too large
rotate_log() {
    if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt $MAX_LOG_SIZE ]]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"
        touch "$LOG_FILE"
        log "INFO" "Log file rotated due to size limit"
    fi
}

# Function to check if Prometheus is accessible
check_prometheus() {
    if ! curl -s --connect-timeout 5 "$PROMETHEUS_URL/api/v1/query?query=up" > /dev/null; then
        log "ERROR" "Cannot connect to Prometheus at $PROMETHEUS_URL"
        return 1
    fi
    return 0
}

# Function to fetch alerts from Prometheus
fetch_alerts() {
    local url="$PROMETHEUS_URL/api/v1/alerts"
    local response
    
    log "DEBUG" "Fetching alerts from $url"
    
    if ! response=$(curl -s --connect-timeout 10 "$url"); then
        log "ERROR" "Failed to fetch alerts from Prometheus API"
        return 1
    fi
    
    echo "$response"
}

# Function to process and log alerts
process_alerts() {
    local alerts_json="$1"
    local alert_count=0
    local firing_count=0
    local pending_count=0
    local resolved_count=0
    
    # Check if we have a valid JSON response
    if ! echo "$alerts_json" | jq . > /dev/null 2>&1; then
        log "ERROR" "Invalid JSON response from Prometheus API"
        return 1
    fi
    
    # Extract status from response
    local status=$(echo "$alerts_json" | jq -r '.status // "error"')
    if [[ "$status" != "success" ]]; then
        log "ERROR" "Prometheus API returned error status: $status"
        return 1
    fi
    
    # Process each alert
    while IFS= read -r alert; do
        if [[ -z "$alert" || "$alert" == "null" ]]; then
            continue
        fi
        
        alert_count=$((alert_count + 1))
        
        local alertname=$(echo "$alert" | jq -r '.labels.alertname // "Unknown"')
        local severity=$(echo "$alert" | jq -r '.labels.severity // "unknown"')
        local instance=$(echo "$alert" | jq -r '.labels.instance // "unknown"')
        local state=$(echo "$alert" | jq -r '.state // "unknown"')
        local active_at=$(echo "$alert" | jq -r '.activeAt // ""')
        local summary=$(echo "$alert" | jq -r '.annotations.summary // ""')
        local description=$(echo "$alert" | jq -r '.annotations.description // ""')
        
        # Count alerts by state
        case "$state" in
            "firing")
                firing_count=$((firing_count + 1))
                ;;
            "pending")
                pending_count=$((pending_count + 1))
                ;;
            "inactive")
                resolved_count=$((resolved_count + 1))
                ;;
        esac
        
        # Log alert details
        local alert_msg="ALERT: $alertname | State: $state | Severity: $severity | Instance: $instance"
        if [[ -n "$summary" ]]; then
            alert_msg="$alert_msg | Summary: $summary"
        fi
        if [[ -n "$description" ]]; then
            alert_msg="$alert_msg | Description: $description"
        fi
        if [[ -n "$active_at" ]]; then
            alert_msg="$alert_msg | Active Since: $active_at"
        fi
        
        case "$state" in
            "firing")
                log "ERROR" "$alert_msg"
                ;;
            "pending")
                log "WARN" "$alert_msg"
                ;;
            *)
                log "INFO" "$alert_msg"
                ;;
        esac
        
        # Send webhook if configured and alert is firing
        if [[ -n "$WEBHOOK_URL" && "$state" == "firing" ]]; then
            send_webhook "$alert"
        fi
        
    done < <(echo "$alerts_json" | jq -c '.data.alerts[]? // empty')
    
    # Summary log
    if [[ $alert_count -eq 0 ]]; then
        log "INFO" "No alerts found"
    else
        log "INFO" "Processed $alert_count alert(s): $firing_count firing, $pending_count pending, $resolved_count resolved"
    fi
    
    return 0
}

# Function to send webhook notification
send_webhook() {
    local alert="$1"
    local webhook_payload
    
    webhook_payload=$(cat <<EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "alert": $alert,
    "source": "alert_dispatcher"
}
EOF
)
    
    if curl -s -X POST -H "Content-Type: application/json" -d "$webhook_payload" "$WEBHOOK_URL" > /dev/null; then
        log "DEBUG" "Webhook sent successfully"
    else
        log "WARN" "Failed to send webhook to $WEBHOOK_URL"
    fi
}

# Function to show usage
usage() {
    cat << EOF
Alert Dispatcher - Prometheus Alert Monitoring Tool

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -u, --url URL           Prometheus URL (default: http://localhost:9090)
    -l, --log-file FILE     Log file path (default: alerts.log)
    -i, --interval SECONDS  Check interval in seconds (default: 30)
    -w, --webhook URL       Webhook URL for notifications
    -v, --verbose           Enable verbose logging
    --once                  Run once and exit (don't loop)
    --test                  Test connectivity and exit

ENVIRONMENT VARIABLES:
    PROMETHEUS_URL          Prometheus server URL
    LOG_FILE               Path to log file
    CHECK_INTERVAL         Check interval in seconds
    WEBHOOK_URL            Webhook URL for notifications
    VERBOSE                Enable verbose logging (true/false)

EXAMPLES:
    # Run with default settings
    $0

    # Run once and exit
    $0 --once

    # Run with custom Prometheus URL and webhook
    $0 -u http://prometheus:9090 -w http://webhook-service/alerts

    # Run with verbose logging
    $0 --verbose

    # Test connectivity
    $0 --test
EOF
}

# Function to handle signals
cleanup() {
    log "INFO" "Alert dispatcher shutting down..."
    exit 0
}

# Main function
main() {
    local run_once=false
    local test_mode=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -u|--url)
                PROMETHEUS_URL="$2"
                shift 2
                ;;
            -l|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -i|--interval)
                CHECK_INTERVAL="$2"
                shift 2
                ;;
            -w|--webhook)
                WEBHOOK_URL="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --once)
                run_once=true
                shift
                ;;
            --test)
                test_mode=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Create log file if it doesn't exist
    touch "$LOG_FILE"
    
    log "INFO" "Alert Dispatcher starting..."
    log "INFO" "Prometheus URL: $PROMETHEUS_URL"
    log "INFO" "Log file: $LOG_FILE"
    log "INFO" "Check interval: ${CHECK_INTERVAL}s"
    if [[ -n "$WEBHOOK_URL" ]]; then
        log "INFO" "Webhook URL: $WEBHOOK_URL"
    fi
    
    # Test mode - just check connectivity and exit
    if [[ "$test_mode" == "true" ]]; then
        if check_prometheus; then
            log "INFO" "Prometheus connectivity test: PASSED"
            exit 0
        else
            log "ERROR" "Prometheus connectivity test: FAILED"
            exit 1
        fi
    fi
    
    # Initial connectivity check
    if ! check_prometheus; then
        log "ERROR" "Initial connectivity check failed. Exiting."
        exit 1
    fi
    
    log "INFO" "Successfully connected to Prometheus"
    
    # Set up signal handlers
    trap cleanup SIGINT SIGTERM
    
    # Main loop
    while true; do
        rotate_log
        
        log "DEBUG" "Checking for alerts..."
        
        if alerts_json=$(fetch_alerts); then
            process_alerts "$alerts_json"
        else
            log "ERROR" "Failed to fetch alerts"
        fi
        
        if [[ "$run_once" == "true" ]]; then
            log "INFO" "Single run completed. Exiting."
            break
        fi
        
        log "DEBUG" "Sleeping for ${CHECK_INTERVAL} seconds..."
        sleep "$CHECK_INTERVAL"
    done
}

# Check if script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
