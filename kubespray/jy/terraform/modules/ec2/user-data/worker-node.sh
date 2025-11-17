#!/bin/bash
# Kubernetes Worker Node 사전 설정

set -e

echo "=========================================="
echo "Worker Node Pre-configuration Starting..."
echo "=========================================="

LOG_FILE="/var/log/worker-node-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# 환경 변수
HOSTNAME="${hostname}"
NODE_INDEX="${node_index}"

# 1. 호스트네임 설정
echo "[1/6] Setting hostname..."
hostnamectl set-hostname $HOSTNAME
echo "127.0.0.1 $HOSTNAME" >> /etc/hosts

# 2. 시스템 업데이트
echo "[2/6] System update..."
apt-get update
apt-get upgrade -y

# 3. 필수 패키지 설치
echo "[3/6] Installing essential packages..."
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  software-properties-common \
  python3 \
  python3-pip

# 4. Swap 비활성화
echo "[4/6] Disabling swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# 5. 커널 모듈 로드
echo "[5/6] Loading kernel modules..."
cat > /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# 6. 네트워크 설정
echo "[6/6] Configuring network settings..."
cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# 완료 표시
touch /tmp/worker-node-setup-complete

echo "=========================================="
echo "✅ Worker Node Pre-configuration Complete!"
echo "Hostname: $HOSTNAME"
echo "Node Index: $NODE_INDEX"
echo "=========================================="