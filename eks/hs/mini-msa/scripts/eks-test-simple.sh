#!/usr/bin/env bash
#
# Simple EKS Integration Test Script
# Quick smoke test for EKS deployment via ALB
#

set -euo pipefail

# Configuration
APP_NAMESPACE="${APP_NAMESPACE:-mini-msa-app}"
INGRESS_NAME="${INGRESS_NAME:-mini-msa-unified}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0

ok()   { echo -e "${GREEN}[✓]${NC} $1"; PASSED=$((PASSED+1)); }
fail() { echo -e "${RED}[✗]${NC} $1"; FAILED=$((FAILED+1)); }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# Get ALB DNS
info "Getting ALB DNS..."
ALB_DNS=$(kubectl get ingress -n "$APP_NAMESPACE" "$INGRESS_NAME" \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -z "$ALB_DNS" ]; then
  fail "ALB DNS not found"
  exit 1
fi

ok "ALB DNS: $ALB_DNS"
echo ""

# Test endpoints
BASE_URL="http://$ALB_DNS"

info "Testing endpoints..."
echo ""

# Core Service Health
if curl -sf --max-time 10 "$BASE_URL/health" >/dev/null 2>&1; then
  ok "Core Service: GET /health"
else
  fail "Core Service: GET /health"
fi

# Core Service Metrics
if curl -sf --max-time 10 "$BASE_URL/metrics" >/dev/null 2>&1; then
  ok "Core Service: GET /metrics"
else
  fail "Core Service: GET /metrics"
fi

# Queue Service
if curl -sf --max-time 10 "$BASE_URL/api/queue" >/dev/null 2>&1; then
  ok "Queue Service: GET /api/queue"
else
  fail "Queue Service: GET /api/queue"
fi

# Summary
echo ""
info "===================="
info "Test Summary"
info "===================="
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ "$FAILED" -eq 0 ]; then
  ok "All tests passed!"
  echo ""
  info "ALB Endpoint: http://$ALB_DNS"
  exit 0
else
  fail "Some tests failed"
  exit 1
fi
