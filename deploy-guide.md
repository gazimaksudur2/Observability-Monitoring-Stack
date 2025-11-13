# Deployment Guide - Observability Stack

This guide will walk you through deploying and testing the complete observability stack.

## Prerequisites

- Docker and Docker Compose installed
- Git (for version control)
- curl (for API testing)
- jq (for JSON processing in alert dispatcher)

### Windows Users
- Use PowerShell or WSL2
- For bash scripts, use Git Bash or WSL2

## Step-by-Step Deployment

### 1. Start the Complete Stack

```bash
# Clone or navigate to the project directory
cd /path/to/TeleverseCUET_preli

# Start all services
docker-compose up -d

# Check all services are running
docker-compose ps
```

Expected output should show all services as "Up":
- demo-app (port 8080)
- prometheus (port 9090)
- grafana (port 3000)
- node-exporter (port 9100)
- alertmanager (port 9093)

### 2. Verify Service Endpoints

Test each service individually:

```bash
# Demo App
curl http://localhost:8080
curl http://localhost:8080/health
curl http://localhost:8080/metrics

# Prometheus
curl http://localhost:9090/api/v1/query?query=up

# Node Exporter
curl http://localhost:9100/metrics

# Grafana (should redirect to login)
curl -I http://localhost:3000
```

### 3. Access Grafana Dashboard

1. Open browser: http://localhost:3000
2. Login: admin / admin
3. Navigate to Dashboards > Browse > "Observability & Monitoring Dashboard"
4. You should see all metrics being collected

### 4. Test Alert Dispatcher

```bash
# Test connectivity (Windows: use Git Bash or WSL)
bash alert_dispatcher.sh --test

# Run once to check for alerts
bash alert_dispatcher.sh --once

# Run continuously (Ctrl+C to stop)
bash alert_dispatcher.sh --verbose
```

### 5. Trigger Test Alerts

Generate some load and alerts:

```bash
# Generate load to increase response times
for i in {1..10}; do curl "http://localhost:8080/load/2000" & done

# Check metrics are updating
curl http://localhost:8080/metrics | grep cpu_usage_percent
```

### 6. View Alerts in Prometheus

1. Open: http://localhost:9090/alerts
2. Check alert rules are loaded
3. Wait for alerts to trigger (may take 2-5 minutes)

## Troubleshooting

### Services Not Starting
```bash
# Check logs
docker-compose logs demo-app
docker-compose logs prometheus
docker-compose logs grafana

# Rebuild if needed
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Grafana Dashboard Not Loading
```bash
# Check Grafana logs
docker-compose logs grafana

# Manually import dashboard
# 1. Copy content from grafana/dashboards/monitoring-dashboard.json
# 2. In Grafana: Dashboards > Import > Paste JSON
```

### Alerts Not Firing
```bash
# Check Prometheus targets
# Open http://localhost:9090/targets
# All targets should be "UP"

# Check alert rules
# Open http://localhost:9090/rules
# Rules should be loaded without errors
```

### Alert Dispatcher Issues
```bash
# Check Prometheus API
curl http://localhost:9090/api/v1/alerts

# Test with verbose logging
bash alert_dispatcher.sh --verbose --once

# Check log file
cat alerts.log
```

## Production Considerations

1. **Security**: Change default passwords, use HTTPS
2. **Persistence**: Configure volume mounts for data persistence
3. **Monitoring**: Monitor the monitoring stack itself
4. **Alerting**: Configure proper alert channels (email, Slack, etc.)
5. **Resource Limits**: Set appropriate CPU/memory limits
6. **Backup**: Regular backup of Grafana dashboards and Prometheus data

## Customization

### Adding More Metrics
Edit `app/server.js` to add custom metrics:
```javascript
const customMetric = new client.Gauge({
  name: 'custom_metric_name',
  help: 'Description of metric'
});
```

### Custom Alert Rules
Edit `alert.rules.yml` to add new alerts:
```yaml
- alert: CustomAlert
  expr: custom_metric > threshold
  for: 1m
  labels:
    severity: warning
  annotations:
    summary: "Custom alert triggered"
```

### Grafana Dashboard
1. Modify `grafana/dashboards/monitoring-dashboard.json`
2. Or create new panels in Grafana UI and export JSON

## Screenshots Checklist

For hackathon submission, capture:
1. ✅ Grafana dashboard showing all panels with data
2. ✅ Prometheus targets page (all UP)
3. ✅ Prometheus alerts page (with active alerts)
4. ✅ Alert dispatcher console output
5. ✅ Docker compose services running
6. ✅ Demo app metrics endpoint
