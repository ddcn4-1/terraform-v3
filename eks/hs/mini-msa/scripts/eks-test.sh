#!/usr/bin/env bash
#
# EKS Integration Test Script
# Tests mini-msa application deployed on AWS EKS with ALB Ingress
#
# Usage:
#   ./scripts/eks-test.sh [options]
#
# Options:
#   -n, --namespace NAMESPACE   Kubernetes namespace (default: mini-msa-app)
#   -i, --ingress NAME          Ingress resource name (default: mini-msa-unified)
#   -v, --verbose               Verbose output
#   -h, --help                  Show this help message
#

set -euo pipefail

# Default configuration
APP_NAMESPACE="${APP_NAMESPACE:-mini-msa-app}"
INGRESS_NAME="${INGRESS_NAME:-mini-msa-unified}"
VERBOSE="${VERBOSE:-false}"

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Temporary files
TMP_FILES=()
LAST_RESPONSE_FILE=""

# Cleanup function
cleanup() {
  for file in "${TMP_FILES[@]}"; do
    rm -f "$file" 2>/dev/null || true
  done
}
trap cleanup EXIT

# Print functions
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[✓]${NC} $1"; TESTS_PASSED=$((TESTS_PASSED+1)); }
fail()  { echo -e "${RED}[✗]${NC} $1"; TESTS_FAILED=$((TESTS_FAILED+1)); }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
skip()  { echo -e "${CYAN}[SKIP]${NC} $1"; TESTS_SKIPPED=$((TESTS_SKIPPED+1)); }
debug() { [ "$VERBOSE" = "true" ] && echo -e "${CYAN}[DEBUG]${NC} $1" || true; }

# Show usage
usage() {
  cat << EOF
EKS Integration Test Script

Usage:
  $0 [options]

Options:
  -n, --namespace NAMESPACE   Kubernetes namespace (default: mini-msa-app)
  -i, --ingress NAME          Ingress resource name (default: mini-msa-unified)
  -v, --verbose               Verbose output
  -h, --help                  Show this help message

Examples:
  # Run tests with default settings
  $0

  # Run tests with verbose output
  $0 --verbose

  # Run tests for specific namespace and ingress
  $0 -n my-namespace -i my-ingress

Environment Variables:
  APP_NAMESPACE               Kubernetes namespace
  INGRESS_NAME                Ingress resource name
  VERBOSE                     Enable verbose output (true/false)

EOF
  exit 0
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -n|--namespace)
        APP_NAMESPACE="$2"
        shift 2
        ;;
      -i|--ingress)
        INGRESS_NAME="$2"
        shift 2
        ;;
      -v|--verbose)
        VERBOSE="true"
        shift
        ;;
      -h|--help)
        usage
        ;;
      *)
        echo "Unknown option: $1"
        usage
        ;;
    esac
  done
}

# Check prerequisites
check_prerequisites() {
  info "Checking prerequisites..."

  # Check kubectl
  if ! command -v kubectl &> /dev/null; then
    fail "kubectl is not installed"
    exit 1
  fi
  ok "kubectl is installed"

  # Check curl
  if ! command -v curl &> /dev/null; then
    fail "curl is not installed"
    exit 1
  fi
  ok "curl is installed"

  # Check jq
  if ! command -v jq &> /dev/null; then
    warn "jq is not installed (optional, but recommended for JSON parsing)"
  else
    ok "jq is installed"
  fi

  # Check kubectl context
  local context
  context=$(kubectl config current-context 2>/dev/null || echo "none")
  if [ "$context" = "none" ]; then
    fail "No kubectl context configured"
    exit 1
  fi
  ok "kubectl context: $context"

  # Check namespace exists
  if ! kubectl get namespace "$APP_NAMESPACE" &> /dev/null; then
    fail "Namespace '$APP_NAMESPACE' does not exist"
    exit 1
  fi
  ok "Namespace '$APP_NAMESPACE' exists"
}

# Get ALB DNS from ingress
get_alb_dns() {
  info "Retrieving ALB DNS from Ingress '$INGRESS_NAME'..." >&2

  local alb_dns
  alb_dns=$(kubectl get ingress -n "$APP_NAMESPACE" "$INGRESS_NAME" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

  if [ -z "$alb_dns" ]; then
    fail "ALB DNS not found. Ingress may not be ready yet." >&2
    info "Check ingress status with: kubectl describe ingress -n $APP_NAMESPACE $INGRESS_NAME" >&2
    exit 1
  fi

  ok "ALB DNS: $alb_dns" >&2
  echo "$alb_dns"
}

# Check pod status
check_pod_status() {
  info "Checking pod status in namespace '$APP_NAMESPACE'..."

  local pods_output
  pods_output=$(kubectl get pods -n "$APP_NAMESPACE" 2>&1)

  if [ $? -ne 0 ]; then
    fail "Failed to get pods in namespace '$APP_NAMESPACE'"
    return 1
  fi

  echo "$pods_output" | tail -n +2 | while read -r line; do
    local pod_name status ready
    pod_name=$(echo "$line" | awk '{print $1}')
    ready=$(echo "$line" | awk '{print $2}')
    status=$(echo "$line" | awk '{print $3}')

    if [ "$status" = "Running" ] && [[ "$ready" == *"/"* ]]; then
      local ready_count total_count
      ready_count=$(echo "$ready" | cut -d'/' -f1)
      total_count=$(echo "$ready" | cut -d'/' -f2)

      if [ "$ready_count" = "$total_count" ]; then
        ok "Pod $pod_name is running ($ready)"
      else
        warn "Pod $pod_name is running but not all containers are ready ($ready)"
      fi
    else
      fail "Pod $pod_name is not running (status: $status, ready: $ready)"
    fi
  done
}

# Check service status
check_service_status() {
  info "Checking service status in namespace '$APP_NAMESPACE'..."

  local services
  services=$(kubectl get svc -n "$APP_NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

  if [ -z "$services" ]; then
    fail "No services found in namespace '$APP_NAMESPACE'"
    return 1
  fi

  for svc in $services; do
    local cluster_ip port
    cluster_ip=$(kubectl get svc -n "$APP_NAMESPACE" "$svc" -o jsonpath='{.spec.clusterIP}')
    port=$(kubectl get svc -n "$APP_NAMESPACE" "$svc" -o jsonpath='{.spec.ports[0].port}')
    ok "Service $svc exists ($cluster_ip:$port)"
  done
}

# Check ingress status
check_ingress_status() {
  info "Checking ingress status..."

  local ingress_info
  ingress_info=$(kubectl get ingress -n "$APP_NAMESPACE" "$INGRESS_NAME" 2>&1)

  if [ $? -ne 0 ]; then
    fail "Ingress '$INGRESS_NAME' not found in namespace '$APP_NAMESPACE'"
    return 1
  fi

  ok "Ingress '$INGRESS_NAME' exists"

  # Get ingress details
  local class hosts address
  class=$(kubectl get ingress -n "$APP_NAMESPACE" "$INGRESS_NAME" -o jsonpath='{.spec.ingressClassName}')
  hosts=$(kubectl get ingress -n "$APP_NAMESPACE" "$INGRESS_NAME" -o jsonpath='{.spec.rules[*].host}')
  address=$(kubectl get ingress -n "$APP_NAMESPACE" "$INGRESS_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

  debug "Ingress class: $class"
  debug "Ingress hosts: ${hosts:-*}"
  debug "Ingress address: $address"

  if [ -n "$address" ]; then
    ok "Ingress has ALB address: $address"
  else
    warn "Ingress does not have an ALB address yet"
  fi
}

# HTTP request function
http_request() {
  local method="$1"
  local url="$2"
  local expected_status="$3"
  local description="$4"
  local payload="${5:-}"
  local content_type="${6:-application/json}"

  local tmp
  tmp=$(mktemp)
  TMP_FILES+=("$tmp")
  LAST_RESPONSE_FILE="$tmp"

  local status_code
  local curl_exit_code

  if [ -n "$payload" ]; then
    status_code=$(curl -s -o "$tmp" -w "%{http_code}" \
      -X "$method" \
      -H "Content-Type: $content_type" \
      --data "$payload" \
      --connect-timeout 10 \
      --max-time 30 \
      "$url" 2>/dev/null)
    curl_exit_code=$?
  else
    status_code=$(curl -s -o "$tmp" -w "%{http_code}" \
      -X "$method" \
      --connect-timeout 10 \
      --max-time 30 \
      "$url" 2>/dev/null)
    curl_exit_code=$?
  fi

  # If curl command failed, set status to 000
  if [ $curl_exit_code -ne 0 ]; then
    debug "curl failed with exit code $curl_exit_code for $url"
    status_code="000"
  fi

  # Ensure status_code is numeric (handle any stderr leak)
  if ! [[ "$status_code" =~ ^[0-9]+$ ]]; then
    debug "Invalid status code: $status_code, setting to 000"
    status_code="000"
  fi

  if [ "$status_code" = "$expected_status" ]; then
    ok "$description (HTTP $status_code)"
    if [ "$VERBOSE" = "true" ] && command -v jq &> /dev/null; then
      jq -C '.' "$tmp" 2>/dev/null || cat "$tmp"
    fi
    return 0
  else
    local body
    body=$(cat "$tmp" 2>/dev/null || echo "")
    fail "$description - expected HTTP $expected_status, got $status_code"
    if [ -n "$body" ] && [ "$VERBOSE" = "true" ]; then
      echo "Response body: $body"
    fi
    return 1
  fi
}

# Test core service endpoints
test_core_service() {
  local alb_dns="$1"
  local base_url="http://${alb_dns}"

  info "=========================================="
  info "Testing Core Service Endpoints"
  info "=========================================="

  # Health check
  http_request GET "${base_url}/health" 200 "Core Service: GET /health"

  # Metrics endpoint
  http_request GET "${base_url}/metrics" 200 "Core Service: GET /metrics"

  # Check queue service health (via core)
  http_request GET "${base_url}/api/check-queue" 200 "Core Service: GET /api/check-queue"

  # Get jobs (before creating)
  http_request GET "${base_url}/api/jobs" 200 "Core Service: GET /api/jobs (before creating)"

  # Create a job
  local job_payload='{"type":"eks-test-job","data":{"source":"eks-test-script","timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"},"priority":"normal"}'
  http_request POST "${base_url}/api/jobs" 201 "Core Service: POST /api/jobs" "$job_payload"

  # Verify job was created
  http_request GET "${base_url}/api/jobs" 200 "Core Service: GET /api/jobs (verify job created)"

  # Extract job count from last response if jq is available
  if command -v jq &> /dev/null && [ -f "$LAST_RESPONSE_FILE" ]; then
    local job_count
    job_count=$(jq -r '.data.totalJobs // 0' "$LAST_RESPONSE_FILE" 2>/dev/null || echo "unknown")
    info "Total jobs in queue: $job_count"
  fi

  # Create a user (triggers welcome email job)
  local user_payload='{"name":"EKS Test User","email":"eks-test@example.com"}'
  http_request POST "${base_url}/api/users" 201 "Core Service: POST /api/users" "$user_payload"

  # Process jobs (may return 200 or 404 depending on queue state)
  local process_url="${base_url}/api/jobs/process"
  local tmp
  tmp=$(mktemp)
  TMP_FILES+=("$tmp")

  local process_status
  process_status=$(curl -s -o "$tmp" -w "%{http_code}" -X POST "$process_url" 2>/dev/null || echo "000")

  if [ "$process_status" = "200" ]; then
    ok "Core Service: POST /api/jobs/process (HTTP $process_status - job processed)"
  elif [ "$process_status" = "404" ]; then
    skip "Core Service: POST /api/jobs/process (HTTP $process_status - no jobs in queue)"
  else
    fail "Core Service: POST /api/jobs/process - unexpected status $process_status"
  fi
}

# Test queue service endpoints
test_queue_service() {
  local alb_dns="$1"
  local base_url="http://${alb_dns}"

  info "=========================================="
  info "Testing Queue Service Endpoints"
  info "=========================================="

  # Get queue status
  http_request GET "${base_url}/api/queue" 200 "Queue Service: GET /api/queue"

  # Extract queue info if jq is available
  if command -v jq &> /dev/null && [ -f "$LAST_RESPONSE_FILE" ]; then
    local queue_service total_jobs
    queue_service=$(jq -r '.service // "unknown"' "$LAST_RESPONSE_FILE" 2>/dev/null || echo "unknown")
    total_jobs=$(jq -r '.totalJobs // 0' "$LAST_RESPONSE_FILE" 2>/dev/null || echo "unknown")
    info "Queue service: $queue_service, Total jobs: $total_jobs"
  fi

  # Add job directly to queue
  local queue_payload='{"type":"direct-queue-test","data":{"message":"Direct queue test from EKS test script"},"priority":"high"}'
  http_request POST "${base_url}/api/queue" 201 "Queue Service: POST /api/queue" "$queue_payload"

  # Get queue status again
  http_request GET "${base_url}/api/queue" 200 "Queue Service: GET /api/queue (after adding job)"

  # Process a job
  local process_url="${base_url}/api/queue/process"
  local tmp
  tmp=$(mktemp)
  TMP_FILES+=("$tmp")

  local process_status
  process_status=$(curl -s -o "$tmp" -w "%{http_code}" -X POST "$process_url" 2>/dev/null || echo "000")

  if [ "$process_status" = "200" ]; then
    ok "Queue Service: POST /api/queue/process (HTTP $process_status - job processed)"
    if [ "$VERBOSE" = "true" ] && command -v jq &> /dev/null; then
      jq -C '.' "$tmp" 2>/dev/null || cat "$tmp"
    fi
  elif [ "$process_status" = "404" ]; then
    skip "Queue Service: POST /api/queue/process (HTTP $process_status - no jobs in queue)"
  else
    fail "Queue Service: POST /api/queue/process - unexpected status $process_status"
  fi
}

# Test path-based routing
test_path_routing() {
  local alb_dns="$1"
  local base_url="http://${alb_dns}"

  info "=========================================="
  info "Testing Path-Based Routing"
  info "=========================================="

  # Verify /api/queue/* routes to queue-service
  http_request GET "${base_url}/api/queue" 200 "Path routing: /api/queue -> queue-service"

  # Verify /* routes to core-service
  http_request GET "${base_url}/health" 200 "Path routing: /health -> core-service"
  http_request GET "${base_url}/api/jobs" 200 "Path routing: /api/jobs -> core-service"
}

# Print test summary
print_summary() {
  echo ""
  info "=========================================="
  info "Test Summary"
  info "=========================================="
  echo -e "${GREEN}Tests Passed:  $TESTS_PASSED${NC}"
  echo -e "${RED}Tests Failed:  $TESTS_FAILED${NC}"
  echo -e "${CYAN}Tests Skipped: $TESTS_SKIPPED${NC}"
  echo -e "Total:         $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
  echo ""

  if [ "$TESTS_FAILED" -eq 0 ]; then
    ok "All critical tests passed!"
    echo ""
    info "Application is healthy and responding correctly via ALB"
    info "ALB Endpoint: http://$ALB_DNS"
    echo ""
    info "You can access the services at:"
    echo "  - Core Service:  http://$ALB_DNS/"
    echo "  - Queue Service: http://$ALB_DNS/api/queue"
    return 0
  else
    fail "Some tests failed. Please investigate."
    echo ""
    info "Troubleshooting commands:"
    echo "  # Check pod logs"
    echo "  kubectl logs -l app=core-service -n $APP_NAMESPACE --tail=50"
    echo "  kubectl logs -l app=queue-service -n $APP_NAMESPACE --tail=50"
    echo ""
    echo "  # Check pod status"
    echo "  kubectl get pods -n $APP_NAMESPACE"
    echo ""
    echo "  # Check ingress details"
    echo "  kubectl describe ingress $INGRESS_NAME -n $APP_NAMESPACE"
    echo ""
    echo "  # Check service endpoints"
    echo "  kubectl get endpoints -n $APP_NAMESPACE"
    return 1
  fi
}

# Main function
main() {
  echo ""
  info "=========================================="
  info "EKS Integration Test"
  info "=========================================="
  info "Namespace: $APP_NAMESPACE"
  info "Ingress:   $INGRESS_NAME"
  info "Verbose:   $VERBOSE"
  echo ""

  # Check prerequisites
  check_prerequisites
  echo ""

  # Get ALB DNS
  ALB_DNS=$(get_alb_dns)
  echo ""

  # Check Kubernetes resources
  info "=========================================="
  info "Checking Kubernetes Resources"
  info "=========================================="
  check_pod_status
  echo ""
  check_service_status
  echo ""
  check_ingress_status
  echo ""

  # Run HTTP endpoint tests
  test_core_service "$ALB_DNS"
  echo ""

  test_queue_service "$ALB_DNS"
  echo ""

  test_path_routing "$ALB_DNS"
  echo ""

  # Print summary
  if print_summary; then
    exit 0
  else
    exit 1
  fi
}

# Parse arguments and run main
parse_args "$@"
main
