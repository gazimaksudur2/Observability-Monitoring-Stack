# Observability & Monitoring Stack

A lightweight observability setup using Prometheus, Node Exporter, and Grafana to monitor a local web service.

## Architecture

- **Demo App**: Simple web service exposing metrics endpoint
- **Prometheus**: Metrics collection and alerting
- **Node Exporter**: System-level metrics (CPU, memory, disk)
- **Grafana**: Metrics visualization and dashboards
- **Alert Dispatcher**: Custom script for alert handling

## Features

- ✅ Monitors CPU, memory, and response time metrics
- ✅ Visualizes metrics in Grafana dashboard
- ✅ Alerts when app is unhealthy or CPU > 70%
- ✅ Custom alert dispatcher via Prometheus API

## Quick Start

```bash
# Start all services
docker-compose up -d

# Access services
# Grafana: http://localhost:3000 (admin/admin)
# Prometheus: http://localhost:9090
# Demo App: http://localhost:8080
# Demo App Metrics: http://localhost:8080/metrics

# Run alert dispatcher
./alert_dispatcher.sh
```

## Project Structure

```
├── app/                    # Demo application source code
├── docker-compose.yml      # Docker services definition
├── prometheus.yml          # Prometheus configuration
├── alert.rules.yml         # Alert rules definition
├── grafana-dashboard.json  # Grafana dashboard export
├── alert_dispatcher.sh     # Alert dispatcher script
└── README.md              # This file
```

## Step-by-Step Usage

1. **Start Services**: `docker-compose up -d`
2. **Run Tests**: `bash test-setup.sh`
3. **Access Grafana**: http://localhost:3000 (admin/admin)
4. **View Alerts**: http://localhost:9090/alerts
5. **Run Alert Dispatcher**: `bash alert_dispatcher.sh --verbose`

## ✅ Requirements Fulfilled

### Core Requirements
- ✅ **docker-compose.yml** — Defines services: app, Prometheus, Node Exporter, Grafana
- ✅ **prometheus.yml** — Prometheus configuration file with scrape targets and alert rules
- ✅ **alert.rules.yml** — Defines CPU-usage and app-availability alerts
- ✅ **grafana-dashboard.json** — Basic dashboard export with 8 visualization panels
- ✅ **app/** — Simple Node.js app exposing /metrics with CPU, memory, response time metrics
- ✅ **alert_dispatcher.sh** — Bash script fetching alerts via Prometheus API and writing logs

### Bonus Features
- ✅ **AlertManager Integration** — Complete alerting pipeline
- ✅ **Comprehensive Testing** — Automated test suite (`test-setup.sh`)
- ✅ **Health Checks** — Application health monitoring
- ✅ **Performance Metrics** — HTTP response times, request rates
- ✅ **System Monitoring** — Node Exporter system metrics
- ✅ **Production Ready** — Docker health checks, log rotation, error handling

## 🎯 Key Features Implemented

1. **Real-time Monitoring**: Live CPU, memory, and application metrics
2. **Smart Alerting**: CPU > 70% and application health alerts
3. **Visual Dashboard**: 8-panel Grafana dashboard with thresholds
4. **Alert Management**: Automated alert dispatching with logging
5. **System Metrics**: Comprehensive node-level monitoring
6. **HTTP Monitoring**: Request rates and response time tracking
7. **Health Checks**: Application availability monitoring
8. **Load Testing**: Built-in load simulation endpoints
