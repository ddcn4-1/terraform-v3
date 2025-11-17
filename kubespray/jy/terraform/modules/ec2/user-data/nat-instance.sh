#!/bin/bash
# NAT Instance 초기 설정 스크립트

set -e  # 오류 발생 시 즉시 종료

echo "=========================================="
echo "NAT Instance Setup Starting..."
echo "=========================================="

# 로그 파일 설정
LOG_FILE="/var/log/nat-instance-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# 1. 시스템 업데이트 및 iptables 설치
echo "[1/4] System update..."
yum update -y
yum install iptables-services -y

systemctl enable iptables --now

# 2. IP Forwarding 활성화 (영구 설정)
echo "[2/4] Enabling IP forwarding..."
cat >> /etc/sysctl.d/custom-ip-forwarding.conf << EOF
net.ipv4.ip_forward = 1
EOF
sysctl -p /etc/sysctl.d/custom-ip-forwarding.conf

# 3. NAT 설정 (iptables)
echo "[3/4] Configuring NAT with iptables..."

# 외부 인터페이스 확인
EXTERNAL_IF=$(ip route | grep default | awk '{print $5}')
echo "External interface: $EXTERNAL_IF"

# NAT 규칙 추가
iptables -t nat -A POSTROUTING -o $EXTERNAL_IF -j MASQUERADE
iptables -F FORWARD

# iptables 규칙 저장 (재부팅 시 유지)
service iptables save

# 4. CloudWatch Agent 설치 (선택적)
echo "[4/4] Installing CloudWatch Agent..."
yum install amazon-cloudwatch-agent -y
# wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
# rpm -U ./amazon-cloudwatch-agent.rpm

# 완료 표시
touch /tmp/nat-instance-setup-complete

echo "=========================================="
echo "✅ NAT Instance Setup Complete!"
echo "=========================================="