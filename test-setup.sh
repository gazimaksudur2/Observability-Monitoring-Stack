#!/bin/bash

# Test Script for Observability Stack
# Verifies all components are working correctly

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print test results
print_test() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    if [[ "$result" == "PASS" ]]; then
        echo -e "${GREEN}✓${NC} $test_name: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name: $message"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Function to test HTTP endpoint
test_endpoint() {
    local name="$1"
    local url="$2"
    local expected_code="${3:-200}"
    
    echo -n "Testing $name... "
    
    if response=$(curl -s -w "%{http_code}" -o /dev/null --connect-timeout 10 "$url" 2>/dev/null); then
        if [[ "$response" == "$expected_code" ]]; then
            print_test "$name" "PASS" "HTTP $response"
        else
            print_test "$name" "FAIL" "Expected HTTP $expected_code, got $response"
        fi
    else
        print_test "$name" "FAIL" "Connection failed"
    fi
}

# Function to test if service is running in docker
test_docker_service() {
    local service_name="$1"
    
    echo -n "Testing Docker service $service_name... "
    
    if docker-compose ps "$service_name" | grep -q "Up"; then
        print_test "Docker $service_name" "PASS" "Service is running"
    else
        print_test "Docker $service_name" "FAIL" "Service not running"
    fi
}

# Function to test Prometheus metrics
test_prometheus_metrics() {
    local metric_name="$1"
    local url="http://localhost:9090/api/v1/query?query=$metric_name"
    
    echo -n "Testing Prometheus metric $metric_name... "
    
    if response=$(curl -s "$url" 2>/dev/null); then
        if echo "$response" | jq -e '.status == "success"' > /dev/null 2>&1; then
            local result_count=$(echo "$response" | jq -r '.data.result | length')
            if [[ "$result_count" -gt 0 ]]; then
                print_test "Metric $metric_name" "PASS" "$result_count result(s) found"
            else
                print_test "Metric $metric_name" "FAIL" "No data found"
            fi
        else
            print_test "Metric $metric_name" "FAIL" "Query failed"
        fi
    else
        print_test "Metric $metric_name" "FAIL" "Connection failed"
    fi
}

echo -e "${BLUE}=== Observability Stack Test Suite ===${NC}"
echo

echo -e "${YELLOW}Testing Docker Services...${NC}"
test_docker_service "demo-app"
test_docker_service "prometheus"
test_docker_service "grafana"
test_docker_service "node-exporter"
test_docker_service "alertmanager"
echo

echo -e "${YELLOW}Testing HTTP Endpoints...${NC}"
test_endpoint "Demo App" "http://localhost:8080"
test_endpoint "Demo App Health" "http://localhost:8080/health"
test_endpoint "Demo App Metrics" "http://localhost:8080/metrics"
test_endpoint "Prometheus" "http://localhost:9090"
test_endpoint "Grafana" "http://localhost:3000" "302"
test_endpoint "Node Exporter" "http://localhost:9100/metrics"
test_endpoint "AlertManager" "http://localhost:9093"
echo

echo -e "${YELLOW}Testing Prometheus API...${NC}"
test_endpoint "Prometheus API" "http://localhost:9090/api/v1/query?query=up"
test_endpoint "Prometheus Targets" "http://localhost:9090/api/v1/targets"
test_endpoint "Prometheus Alerts" "http://localhost:9090/api/v1/alerts"
echo

echo -e "${YELLOW}Testing Prometheus Metrics...${NC}"
test_prometheus_metrics "up"
test_prometheus_metrics "cpu_usage_percent"
test_prometheus_metrics "memory_usage_bytes"
test_prometheus_metrics "app_health_status"
test_prometheus_metrics "http_requests_total"
test_prometheus_metrics "node_memory_MemTotal_bytes"
echo

echo -e "${YELLOW}Testing Alert Rules...${NC}"
echo -n "Testing Prometheus rules... "
if rules_response=$(curl -s "http://localhost:9090/api/v1/rules" 2>/dev/null); then
    if echo "$rules_response" | jq -e '.status == "success"' > /dev/null 2>&1; then
        local rule_count=$(echo "$rules_response" | jq -r '.data.groups | length')
        if [[ "$rule_count" -gt 0 ]]; then
            print_test "Alert Rules" "PASS" "$rule_count rule group(s) loaded"
        else
            print_test "Alert Rules" "FAIL" "No rule groups found"
        fi
    else
        print_test "Alert Rules" "FAIL" "API error"
    fi
else
    print_test "Alert Rules" "FAIL" "Connection failed"
fi
echo

echo -e "${YELLOW}Testing Alert Dispatcher...${NC}"
if [[ -f "alert_dispatcher.sh" ]]; then
    if bash alert_dispatcher.sh --test > /dev/null 2>&1; then
        print_test "Alert Dispatcher" "PASS" "Connectivity test passed"
    else
        print_test "Alert Dispatcher" "FAIL" "Connectivity test failed"
    fi
else
    print_test "Alert Dispatcher" "FAIL" "Script not found"
fi
echo

# Generate some test load
echo -e "${YELLOW}Generating Test Load...${NC}"
echo "Generating HTTP requests to create metrics..."
for i in {1..5}; do
    curl -s "http://localhost:8080/" > /dev/null &
    curl -s "http://localhost:8080/load/$(($RANDOM % 1000))" > /dev/null &
done
wait
print_test "Load Generation" "PASS" "Test requests completed"
echo

# Final summary
echo -e "${BLUE}=== Test Results Summary ===${NC}"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo -e "Total Tests: $(($TESTS_PASSED + $TESTS_FAILED))"
echo

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}🎉 All tests passed! Your observability stack is working correctly.${NC}"
    echo
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Open Grafana: http://localhost:3000 (admin/admin)"
    echo "2. View the monitoring dashboard to see your metrics"
    echo "3. Check Prometheus alerts: http://localhost:9090/alerts"
    echo "4. Run alert dispatcher: bash alert_dispatcher.sh --verbose"
    echo
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Please check the logs and troubleshoot.${NC}"
    echo
    echo -e "${BLUE}Troubleshooting:${NC}"
    echo "1. Check Docker services: docker-compose ps"
    echo "2. View logs: docker-compose logs [service-name]"
    echo "3. Restart services: docker-compose restart"
    echo
    exit 1
fi
