#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_failure() {
    echo -e "${RED}[✗]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Test if pod is running
test_pod_running() {
    local pod_label=$1
    local pod_name=$2
    local namespace=$3

    print_info "Testing if $pod_name is running in $namespace..."

    if kubectl get pods -n "$namespace" -l "$pod_label" | grep -q "Running"; then
        print_success "$pod_name is running"
        return 0
    else
        print_failure "$pod_name is not running"
        return 1
    fi
}

# Test if service is accessible
test_service_accessible() {
    local service_name=$1
    local port=$2
    local namespace=$3

    print_info "Testing if $service_name is accessible in $namespace..."

    if kubectl get svc -n "$namespace" "$service_name" &> /dev/null; then
        print_success "$service_name exists"
        return 0
    else
        print_failure "$service_name does not exist"
        return 1
    fi
}

# Test HTTP endpoint
test_http_endpoint() {
    local endpoint=$1
    local expected_status=$2
    local description=$3
    local service_name=$4
    local namespace=$5

    print_info "Testing $description..."

    # Port forward in background
    local port
    local pf_pid
    local status_code
    local retry_count=0
    local max_retries=5

    # Extract port using sed (macOS compatible)
    port=$(echo "$endpoint" | sed -n 's/.*:\([0-9]\+\).*/\1/p')

    # Start port forward
    kubectl port-forward -n "$namespace" "svc/$service_name" "$port:$port" &> /dev/null &
    pf_pid=$!

    # Wait for port forward to be ready with retry
    sleep 3

    # Make request with retry
    while [ $retry_count -lt $max_retries ]; do
        status_code=$(curl -s -o /dev/null -w "%{http_code}" "$endpoint" 2>/dev/null)
        if [ -n "$status_code" ] && [ "$status_code" != "000" ]; then
            break
        fi
        retry_count=$((retry_count + 1))
        sleep 1
    done

    # Kill port forward
    kill $pf_pid 2>/dev/null || true
    wait $pf_pid 2>/dev/null || true

    if [ "$status_code" = "$expected_status" ]; then
        print_success "$description - HTTP $status_code"
        return 0
    else
        print_failure "$description - Expected HTTP $expected_status, got $status_code"
        return 1
    fi
}

# Test database connectivity
test_database_connectivity() {
    print_info "Testing PostgreSQL connectivity..."

    local pg_pod
    pg_pod=$(kubectl get pods -n mini-msa-data -l app=postgres -o jsonpath='{.items[0].metadata.name}')

    if [ -z "$pg_pod" ]; then
        print_failure "PostgreSQL pod not found"
        return 1
    fi

    if kubectl exec -n mini-msa-data "$pg_pod" -- pg_isready -U admin -d mini_msa &> /dev/null; then
        print_success "PostgreSQL is accepting connections"
        return 0
    else
        print_failure "PostgreSQL is not accepting connections"
        return 1
    fi
}

# Test Redis connectivity
test_redis_connectivity() {
    print_info "Testing Redis connectivity..."

    local redis_pod
    redis_pod=$(kubectl get pods -n mini-msa-data -l app=redis -o jsonpath='{.items[0].metadata.name}')

    if [ -z "$redis_pod" ]; then
        print_failure "Redis pod not found"
        return 1
    fi

    if kubectl exec -n mini-msa-data "$redis_pod" -- redis-cli --raw incr ping &> /dev/null; then
        print_success "Redis is responding"
        return 0
    else
        print_failure "Redis is not responding"
        return 1
    fi
}

# Test HTTP endpoint internally (via kubectl exec)
test_http_endpoint_internal() {
    local service_name=$1
    local namespace=$2
    local path=$3

    print_info "Testing $service_name HTTP endpoint ($path)..."

    local pod
    pod=$(kubectl get pods -n "$namespace" -l "app=$service_name" -o jsonpath='{.items[0].metadata.name}')

    if [ -z "$pod" ]; then
        print_failure "$service_name pod not found"
        return 1
    fi

    # Get service port
    local port
    if [ "$service_name" = "core-service" ]; then
        port=3002
    elif [ "$service_name" = "queue-service" ]; then
        port=3001
    else
        port=3000
    fi

    # Test HTTP endpoint using wget from within the pod with explicit timeout
    local response
    response=$(kubectl exec -n "$namespace" "$pod" -- wget -T 5 -q -O- "http://127.0.0.1:$port$path" 2>&1)
    local exit_code=$?

    if [ $exit_code -eq 0 ] && [ -n "$response" ]; then
        print_success "$service_name HTTP endpoint is responding"
        return 0
    else
        print_failure "$service_name HTTP endpoint failed (exit code: $exit_code)"
        return 1
    fi
}

# Test service-to-service communication
test_service_communication() {
    print_info "Testing service-to-service communication..."

    local core_pod
    core_pod=$(kubectl get pods -n mini-msa-app -l app=core-service -o jsonpath='{.items[0].metadata.name}')

    if [ -z "$core_pod" ]; then
        print_failure "Core service pod not found"
        return 1
    fi

    # Test if core-service can reach queue-service (same namespace)
    if kubectl exec -n mini-msa-app "$core_pod" -- wget -q -O- http://queue-service.mini-msa-app.svc.cluster.local:3001/health &> /dev/null; then
        print_success "Core service can communicate with Queue service"
        return 0
    else
        print_failure "Core service cannot communicate with Queue service"
        return 1
    fi
}

# Test cross-namespace communication
test_cross_namespace_communication() {
    print_info "Testing cross-namespace communication (app -> data)..."

    local queue_pod
    queue_pod=$(kubectl get pods -n mini-msa-app -l app=queue-service -o jsonpath='{.items[0].metadata.name}')

    if [ -z "$queue_pod" ]; then
        print_failure "Queue service pod not found"
        return 1
    fi

    # Test if queue-service can reach postgres (cross-namespace)
    if kubectl exec -n mini-msa-app "$queue_pod" -- nc -z postgres-service.mini-msa-data.svc.cluster.local 5432 &> /dev/null; then
        print_success "Queue service can communicate with PostgreSQL (cross-namespace)"
        return 0
    else
        print_failure "Queue service cannot communicate with PostgreSQL (cross-namespace)"
        return 1
    fi
}

# Check resource usage
check_resource_usage() {
    print_info "Checking resource usage..."

    echo ""
    echo "=== Application Namespace (mini-msa-app) ==="
    kubectl top pods -n mini-msa-app 2>/dev/null || print_warning "Metrics server not available"
    echo ""
    echo "=== Data Namespace (mini-msa-data) ==="
    kubectl top pods -n mini-msa-data 2>/dev/null || print_warning "Metrics server not available"
    echo ""
}

# Main test suite
main() {
    echo ""
    print_info "=========================================="
    print_info "Mini MSA Kubernetes Test Suite"
    print_info "=========================================="
    echo ""

    # Check if namespaces exist
    if ! kubectl get namespace mini-msa-app &> /dev/null; then
        print_failure "Namespace 'mini-msa-app' does not exist. Please run k8s-setup.sh first."
        exit 1
    fi
    if ! kubectl get namespace mini-msa-data &> /dev/null; then
        print_failure "Namespace 'mini-msa-data' does not exist. Please run k8s-setup.sh first."
        exit 1
    fi

    # Test pod status
    print_info "=== Testing Pod Status ==="
    test_pod_running "app=postgres" "PostgreSQL" "mini-msa-data"
    test_pod_running "app=redis" "Redis" "mini-msa-data"
    test_pod_running "app=queue-service" "Queue Service" "mini-msa-app"
    test_pod_running "app=core-service" "Core Service" "mini-msa-app"
    echo ""

    # Test service existence
    print_info "=== Testing Service Existence ==="
    test_service_accessible "postgres-service" "5432" "mini-msa-data"
    test_service_accessible "redis-service" "6379" "mini-msa-data"
    test_service_accessible "queue-service" "3001" "mini-msa-app"
    test_service_accessible "core-service" "3002" "mini-msa-app"
    echo ""

    # Test database connectivity
    print_info "=== Testing Database Connectivity ==="
    test_database_connectivity
    test_redis_connectivity
    echo ""

    # Test service communication
    print_info "=== Testing Service Communication ==="
    test_service_communication
    test_cross_namespace_communication
    echo ""

    # Test HTTP endpoints (using kubectl exec instead of port-forward)
    print_info "=== Testing HTTP Endpoints ==="
    test_http_endpoint_internal "core-service" "mini-msa-app" "/health"
    test_http_endpoint_internal "queue-service" "mini-msa-app" "/health"
    echo ""

    # Check resource usage
    check_resource_usage

    # Print summary
    echo ""
    print_info "=========================================="
    print_info "Test Summary"
    print_info "=========================================="
    echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        print_success "All tests passed!"
        echo ""
        print_info "You can now access the application:"
        echo "  # Core Service"
        echo "  kubectl port-forward -n mini-msa-app svc/core-service 3002:3002"
        echo "  curl http://localhost:3002/health"
        echo ""
        echo "  # Queue Service"
        echo "  kubectl port-forward -n mini-msa-app svc/queue-service 3001:3001"
        echo "  curl http://localhost:3001/health"
        exit 0
    else
        print_failure "Some tests failed. Please check the logs:"
        echo "  # Application logs"
        echo "  kubectl logs -f -l app=core-service -n mini-msa-app"
        echo "  kubectl logs -f -l app=queue-service -n mini-msa-app"
        echo ""
        echo "  # Data logs"
        echo "  kubectl logs -f -l app=postgres -n mini-msa-data"
        echo "  kubectl logs -f -l app=redis -n mini-msa-data"
        echo ""
        echo "  # Describe pods"
        echo "  kubectl describe pods -n mini-msa-app"
        echo "  kubectl describe pods -n mini-msa-data"
        exit 1
    fi
}

# Run main function
main
