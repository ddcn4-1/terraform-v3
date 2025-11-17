```
# ==========================================
# Terraform 실행
# ==========================================

# 1. 초기화
terraform init

# 2. Plan 확인
terraform plan -target=module.ec2

# 3. EC2만 먼저 생성
terraform apply -target=module.ec2

# ==========================================
# 인스턴스 상태 확인
# ==========================================

# 4. Output 확인
terraform output

# Bastion Public IP
terraform output -raw bastion_public_ip

# 5. AWS Console 확인
# EC2 → Instances → 5개 인스턴스 확인:
# - NAT Instance (Public Subnet A)
# - Bastion Host (Public Subnet B)
# - Control Plane (Private Subnet A)
# - Worker Node 1 (Private Subnet A)
# - Worker Node 2 (Private Subnet B)

# ==========================================
# SSH 접속 테스트
# ==========================================

# 6. Bastion 접속
BASTION_IP=$(terraform output -raw bastion_public_ip)
ssh -i ~/.ssh/ddcn41-key.pem ec2-user@$BASTION_IP

# 7. Bastion에서 Control Plane 접속
ssh ubuntu@<control-plane-private-ip>

# 8. Kubespray 설치 확인 (Bastion에서)
cd /home/ec2-user/kubespray
ls -la
ansible --version

# ==========================================
# User Data 실행 확인
# ==========================================

# 9. 각 인스턴스의 User Data 로그 확인

# NAT Instance
ssh ec2-user@<nat-instance-ip>
cat /var/log/nat-instance-setup.log
cat /tmp/nat-instance-setup-complete  # 있으면 성공

# Bastion
ssh ec2-user@<bastion-ip>
cat /var/log/bastion-setup.log
cat /tmp/bastion-setup-complete

# Control Plane (Bastion 경유)
ssh -J ec2-user@$BASTION_IP ubuntu@<control-plane-ip>
cat /var/log/control-plane-setup.log
hostname  # k8s-control-plane 확인

# Worker Node
ssh -J ec2-user@$BASTION_IP ubuntu@<worker-ip>
hostname  # k8s-worker-1 또는 k8s-worker-2 확인
```
