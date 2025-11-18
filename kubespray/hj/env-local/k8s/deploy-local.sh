#!/usr/bin/env bash
set -euo pipefail

# === 기본 설정 ===
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

CORE_NS="core"
QUEUE_NS="queue"
TLS_CERT="$BASE_DIR/k8s/tls/local.ddcn41.com.pem"       # 개인의 환경에 맞게 설정
TLS_KEY="$BASE_DIR/k8s/tls/local.ddcn41.com-key.pem"    # 개인의 환경에 맞게 설정
TLS_SECRET_NAME="ddcn41-tls"

echo "[+] Using BASE_DIR=$BASE_DIR"

# === 네임스페이스 생성 ===
echo "[+] Create namespaces if not exists"
kubectl get ns "$CORE_NS" >/dev/null 2>&1 || kubectl create ns "$CORE_NS"
kubectl get ns "$QUEUE_NS" >/dev/null 2>&1 || kubectl create ns "$QUEUE_NS"

# === TLS Secret 생성/업데이트 (core, queue 둘 다) ===
echo "[+] Create/Update TLS secret in namespaces (core, queue)"
for ns in "$CORE_NS" "$QUEUE_NS"; do
  kubectl create secret tls "$TLS_SECRET_NAME" \
    -n "$ns" \
    --cert="$TLS_CERT" \
    --key="$TLS_KEY" \
    --dry-run=client -o yaml | kubectl apply -f -
done

# === core: Config / Secret ===
echo "[+] Apply core config & secrets"
kubectl apply -f "$BASE_DIR/k8s/core/config/"

# === queue: Config / Secret ===
echo "[+] Apply queue config & secrets"
kubectl apply -f "$BASE_DIR/k8s/queue/config/"

# === core: Backend (core-api, admin-api + Ingress) ===
echo "[+] Apply core backend (api + admin + ingress)"
kubectl apply -f "$BASE_DIR/k8s/core/backend/"

# === queue: Backend (queue-api + Ingress) ===
echo "[+] Apply queue backend (queue-api + ingress)"
kubectl apply -f "$BASE_DIR/k8s/queue/backend/"

# === core: Frontend (client/admin/accounts + ingress) ===
echo "[+] Apply frontend (client/admin/accounts + ingresses)"
kubectl apply -f "$BASE_DIR/k8s/core/frontend/"

echo "[✔] All manifests applied."
echo "    - Namespaces: $CORE_NS, $QUEUE_NS"
echo "    - TLS Secret: $TLS_SECRET_NAME (core, queue)"
echo
echo "상태 확인:"
echo "  kubectl get pods -n core"
echo "  kubectl get pods -n queue"
echo "  kubectl get ingress -A"
