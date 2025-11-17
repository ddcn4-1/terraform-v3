#!/bin/bash
# Bastion Host 초기 설정 및 Kubespray 설치

set -e

echo "=========================================="
echo "Bastion Host Setup Starting..."
echo "=========================================="

LOG_FILE="/var/log/bastion-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# 환경 변수
KUBESPRAY_VERSION="release-${kubespray_version}"
K8S_VERSION="${k8s_version}"

# 1. 시스템 업데이트
echo "[1/6] System update..."
yum update -y

# 2. 필수 패키지 설치
echo "[2/6] Installing essential packages..."
yum install -y \
  git \
  python3.11 \
  sshpass

# 3. Python 가상 환경 설정
echo "[3/6] Installing Python venv..."
export VENV_DIR=kubespray-venv
export KUBESPRAY_DIR=kubespray
python3.11 -m venv $VENV_DIR
source $VENV_DIR/bin/activate

# 4. Kubespray 다운로드
echo "[4/6] Downloading Kubespray..."
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray
git checkout $KUBESPRAY_VERSION

# 5. Kubespray 의존성 설치
echo "[5/6] Installing Kubespray requirements..."
pip install -r requirements.txt

# 6. Inventory 디렉토리 준비
echo "[6/6] Preparing inventory directory..."
cp -rfp inventory/sample inventory/mycluster

# SSH 설정 (StrictHostKeyChecking 비활성화)
mkdir -p /home/ec2-user/.ssh
cat >> /home/ec2-user/.ssh/config << EOF
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
EOF
chown -R ec2-user:ec2-user /home/ec2-user/.ssh
chmod 600 /home/ec2-user/.ssh/config

# 완료 표시
touch /tmp/bastion-setup-complete

echo "=========================================="
echo "✅ Bastion Host Setup Complete!"
echo ""
echo "Installed versions:"
echo "- Ansible: $(ansible --version | head -n1)"
echo "- Kubespray: $KUBESPRAY_VERSION"
echo "- kubectl: $(kubectl version --client --short 2>/dev/null || echo 'N/A')"
echo "=========================================="