#!/usr/bin/env bash

set -euo pipefail

APP_NAMESPACE="${APP_NAMESPACE:-mini-msa-app}"
DATA_NAMESPACE="${DATA_NAMESPACE:-mini-msa-data}"
HELM_RELEASE="${HELM_RELEASE:-mini-msa}"
HELM_TEST_ACCESS_MODE="${HELM_TEST_ACCESS_MODE:-port-forward}" # port-forward|nodeport
CORE_LOCAL_PORT="${CORE_LOCAL_PORT:-33002}"
QUEUE_LOCAL_PORT="${QUEUE_LOCAL_PORT:-33001}"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0
TMP_FILES=()
PORT_FORWARD_PIDS=()
LAST_RESPONSE_FILE=""
LAST_STATUS=""

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; TESTS_PASSED=$((TESTS_PASSED+1)); }
fail() { echo -e "${RED}[✗]${NC} $1"; TESTS_FAILED=$((TESTS_FAILED+1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

cleanup() {
  for pid in "${PORT_FORWARD_PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
  for file in "${TMP_FILES[@]}"; do
    rm -f "$file" 2>/dev/null || true
  done
}
trap cleanup EXIT

require_namespace() {
  local ns="$1"
  if ! kubectl get namespace "$ns" >/dev/null 2>&1; then
    fail "Namespace '$ns' not found"
    exit 1
  fi
}

get_resource_name() {
  local kind="$1" namespace="$2" selector="$3"
  kubectl get "$kind" -n "$namespace" -l "$selector" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
}

get_service_nodeport() {
  local namespace="$1"
  local service="$2"
  kubectl get svc "$service" -n "$namespace" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || true
}

start_port_forward() {
  local namespace="$1"
  local service="$2"
  local local_port="$3"
  local target_port="$4"
  local desc="$5"

  info "Port-forwarding $desc (svc/$service → localhost:$local_port)..."
  kubectl port-forward -n "$namespace" "svc/$service" "${local_port}:${target_port}" >/dev/null 2>&1 &
  local pid=$!
  PORT_FORWARD_PIDS+=("$pid")
  sleep 2
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    fail "Failed to establish port-forward for $desc"
    exit 1
  fi
  ok "$desc port-forward active"
}

http_request() {
  local method="$1"
  local url="$2"
  local expected="$3"
  local description="$4"
  local payload="${5:-}"
  local tmp
  tmp=$(mktemp)
  TMP_FILES+=("$tmp")

  local status
  if [ -n "$payload" ]; then
    status=$(curl -s -o "$tmp" -w "%{http_code}" -X "$method" -H "Content-Type: application/json" --data "$payload" "$url")
  else
    status=$(curl -s -o "$tmp" -w "%{http_code}" -X "$method" "$url")
  fi

  if [ "$status" = "$expected" ]; then
    ok "$description (HTTP $status)"
    LAST_RESPONSE_FILE="$tmp"
    LAST_STATUS="$status"
    return 0
  else
    local body
    body=$(cat "$tmp")
    fail "$description - expected $expected got $status (response: $body)"
    LAST_RESPONSE_FILE="$tmp"
    LAST_STATUS="$status"
    return 1
  fi
}

wait_for_pod() {
  local selector="$1" namespace="$2" label_desc="$3"
  info "Waiting for pod ($label_desc) in $namespace..."
  if ! kubectl get pods -n "$namespace" -l "$selector" --no-headers >/dev/null 2>&1; then
    fail "No pod found with selector '$selector' in $namespace"
    return 1
  fi
  if kubectl wait --namespace "$namespace" --for=condition=Ready pod -l "$selector" --timeout=120s >/dev/null 2>&1; then
    ok "$label_desc pod is Ready"
    return 0
  else
    fail "$label_desc pod failed to become Ready"
    kubectl get pods -n "$namespace" -l "$selector"
    return 1
  fi
}

check_service_exists() {
  local selector="$1" namespace="$2" description="$3"
  info "Checking service ($description) in $namespace..."
  if kubectl get svc -n "$namespace" -l "$selector" --no-headers >/dev/null 2>&1; then
    ok "$description service exists"
    return 0
  fi
  fail "$description service not found"
  return 1
}

test_http_in_pod() {
  local selector="$1" namespace="$2" port="$3" path="$4" desc="$5"
  local pod
  pod=$(get_resource_name pod "$namespace" "$selector")
  if [ -z "$pod" ]; then
    fail "$desc pod not found for HTTP test"
    return 1
  fi
  info "Testing HTTP endpoint for $desc ($path)..."
  if kubectl exec -n "$namespace" "$pod" -- wget -T 5 -q -O- "http://127.0.0.1:${port}${path}" >/dev/null 2>&1; then
    ok "$desc HTTP endpoint healthy"
    return 0
  fi
  fail "$desc HTTP endpoint failed"
  return 1
}

test_core_to_queue() {
  local core_pod queue_svc queue_port
  core_pod=$(get_resource_name pod "$APP_NAMESPACE" "app.kubernetes.io/component=core")
  queue_svc=$(get_resource_name svc "$APP_NAMESPACE" "app.kubernetes.io/component=queue-service")
  if [ -z "$core_pod" ] || [ -z "$queue_svc" ]; then
    fail "Unable to locate core pod or queue service for communication test"
    return 1
  fi
  queue_port=$(kubectl get svc "$queue_svc" -n "$APP_NAMESPACE" -o jsonpath='{.spec.ports[0].port}')
  info "Testing Core -> Queue service call..."
  if kubectl exec -n "$APP_NAMESPACE" "$core_pod" -- wget -T 5 -q -O- "http://${queue_svc}.${APP_NAMESPACE}.svc.cluster.local:${queue_port}/health" >/dev/null 2>&1; then
    ok "Core service can reach Queue service"
    return 0
  fi
  fail "Core service cannot reach Queue service"
  return 1
}

test_queue_to_data() {
  local queue_pod pg_svc redis_svc pg_port redis_port
  queue_pod=$(get_resource_name pod "$APP_NAMESPACE" "app.kubernetes.io/component=queue")
  pg_svc=$(get_resource_name svc "$DATA_NAMESPACE" "app.kubernetes.io/component=postgres-service")
  redis_svc=$(get_resource_name svc "$DATA_NAMESPACE" "app.kubernetes.io/component=redis-service")
  if [ -z "$queue_pod" ] || [ -z "$pg_svc" ] || [ -z "$redis_svc" ]; then
    fail "Missing queue pod or postgres/redis services for connectivity test"
    return 1
  fi
  pg_port=$(kubectl get svc "$pg_svc" -n "$DATA_NAMESPACE" -o jsonpath='{.spec.ports[0].port}')
  redis_port=$(kubectl get svc "$redis_svc" -n "$DATA_NAMESPACE" -o jsonpath='{.spec.ports[0].port}')
  info "Testing Queue -> PostgreSQL connectivity..."
  if kubectl exec -n "$APP_NAMESPACE" "$queue_pod" -- nc -z "${pg_svc}.${DATA_NAMESPACE}.svc.cluster.local" "${pg_port}" >/dev/null 2>&1; then
    ok "Queue service can reach PostgreSQL"
  else
    fail "Queue service cannot reach PostgreSQL"
  fi
  info "Testing Queue -> Redis connectivity..."
  if kubectl exec -n "$APP_NAMESPACE" "$queue_pod" -- nc -z "${redis_svc}.${DATA_NAMESPACE}.svc.cluster.local" "${redis_port}" >/dev/null 2>&1; then
    ok "Queue service can reach Redis"
  else
    fail "Queue service cannot reach Redis"
  fi
}

summarize() {
  echo ""
  info "================= Helm Test Summary ================="
  echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
  echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
  if [ "$TESTS_FAILED" -eq 0 ]; then
    ok "All Helm connectivity checks passed"
    exit 0
  else
    fail "Helm connectivity checks failed"
    exit 1
  fi
}

main() {
  info "Starting Helm connectivity tests (release: ${HELM_RELEASE})"
  require_namespace "$APP_NAMESPACE"
  require_namespace "$DATA_NAMESPACE"

  info "--- Pod readiness ---"
  wait_for_pod "app.kubernetes.io/component=core" "$APP_NAMESPACE" "Core service"
  wait_for_pod "app.kubernetes.io/component=queue" "$APP_NAMESPACE" "Queue service"
  wait_for_pod "app.kubernetes.io/component=postgres" "$DATA_NAMESPACE" "PostgreSQL"
  wait_for_pod "app.kubernetes.io/component=redis" "$DATA_NAMESPACE" "Redis"

  info "--- Services ---"
  check_service_exists "app.kubernetes.io/component=core-service" "$APP_NAMESPACE" "Core service"
  check_service_exists "app.kubernetes.io/component=queue-service" "$APP_NAMESPACE" "Queue service"
  check_service_exists "app.kubernetes.io/component=postgres-service" "$DATA_NAMESPACE" "PostgreSQL"
  check_service_exists "app.kubernetes.io/component=redis-service" "$DATA_NAMESPACE" "Redis"

  info "--- HTTP endpoints ---"
  test_http_in_pod "app.kubernetes.io/component=core" "$APP_NAMESPACE" 3002 "/health" "Core service"
  test_http_in_pod "app.kubernetes.io/component=queue" "$APP_NAMESPACE" 3001 "/health" "Queue service"

  info "--- Service communication ---"
  test_core_to_queue
  test_queue_to_data

  info "--- Full HTTP API tests (Core & Queue) ---"
  local core_service queue_service core_base queue_base
  core_service=$(get_resource_name svc "$APP_NAMESPACE" "app=core-service")
  queue_service=$(get_resource_name svc "$APP_NAMESPACE" "app=queue-service")
  if [ -z "$core_service" ] || [ -z "$queue_service" ]; then
    fail "Unable to determine service names for API testing"
    summarize
  fi

  case "$HELM_TEST_ACCESS_MODE" in
    nodeport)
      local core_node_port queue_node_port
      core_node_port=$(get_service_nodeport "$APP_NAMESPACE" "$core_service")
      queue_node_port=$(get_service_nodeport "$APP_NAMESPACE" "$queue_service")
      if [ -z "$core_node_port" ] || [ -z "$queue_node_port" ]; then
        fail "NodePort not found for services (set HELM_TEST_ACCESS_MODE=port-forward or ensure NodePort type)"
        summarize
      fi
      core_base="http://127.0.0.1:${core_node_port}"
      queue_base="http://127.0.0.1:${queue_node_port}"
      ;;
    port-forward)
      start_port_forward "$APP_NAMESPACE" "$core_service" "$CORE_LOCAL_PORT" 3002 "Core service"
      start_port_forward "$APP_NAMESPACE" "$queue_service" "$QUEUE_LOCAL_PORT" 3001 "Queue service"
      core_base="http://127.0.0.1:${CORE_LOCAL_PORT}"
      queue_base="http://127.0.0.1:${QUEUE_LOCAL_PORT}"
      ;;
    *)
      fail "Unsupported HELM_TEST_ACCESS_MODE='${HELM_TEST_ACCESS_MODE}' (use 'port-forward' or 'nodeport')"
      summarize
      ;;
  esac

  info "Queue service endpoints"
  http_request GET "${queue_base}/health" 200 "Queue GET /health"
  http_request DELETE "${queue_base}/api/queue" 200 "Queue DELETE /api/queue (cleanup)"
  http_request GET "${queue_base}/api/queue" 200 "Queue GET /api/queue"
  local queue_job_payload='{"type":"helm-test","data":{"source":"helm-test"},"priority":"high"}'
  http_request POST "${queue_base}/api/queue" 201 "Queue POST /api/queue" "$queue_job_payload"
  local queue_job_id
  queue_job_id=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["job"]["id"])' "$LAST_RESPONSE_FILE") || queue_job_id=""
  if [ -z "$queue_job_id" ]; then
    fail "Unable to parse job ID from queue response"
  else
    http_request GET "${queue_base}/api/queue/${queue_job_id}" 200 "Queue GET /api/queue/:id"
  fi
  http_request POST "${queue_base}/api/queue/process" 200 "Queue POST /api/queue/process"
  http_request GET "${queue_base}/api/queue" 200 "Queue GET /api/queue (post-process)"
  http_request DELETE "${queue_base}/api/queue" 200 "Queue DELETE /api/queue (final cleanup)"

  info "Core service endpoints"
  http_request GET "${core_base}/health" 200 "Core GET /health"
  http_request GET "${core_base}/api/check-queue" 200 "Core GET /api/check-queue"
  http_request GET "${core_base}/api/jobs" 200 "Core GET /api/jobs"
  local core_job_payload='{"type":"helm-suite","data":{"source":"helm-test"},"priority":"normal"}'
  http_request POST "${core_base}/api/jobs" 201 "Core POST /api/jobs" "$core_job_payload"
  http_request POST "${core_base}/api/jobs/process" 200 "Core POST /api/jobs/process"
  local core_user_payload='{"name":"Helm User","email":"helm@test.local"}'
  http_request POST "${core_base}/api/users" 201 "Core POST /api/users" "$core_user_payload"

  summarize
}

main "$@"
