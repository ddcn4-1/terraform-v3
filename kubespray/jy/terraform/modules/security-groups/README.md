# Security Groups 모듈

Kubernetes 클러스터 및 관련 인프라를 위한 AWS Security Groups 정의

## 보안 설계 원칙

### 1. 최소 권한 원칙 (Principle of Least Privilege)

- 필요한 포트만 개방
- 특정 소스만 허용 (0.0.0.0/0 최소화)
- Security Group 참조 활용

### 2. 계층별 보안 (Defense in Depth)

```
Internet
   ↓ (80, 443)
  ALB
   ↓ (30000-32767)
Worker Nodes
   ↓ (5432, 6379)
RDS / ElastiCache
```

### 3. Stateful Firewall

- Inbound 허용 시 Outbound 응답 자동 허용
- 명시적 Egress 규칙으로 제어 강화

## Security Groups 목록

### 1. ALB Security Group

**용도:** Application Load Balancer

- **Inbound:** 80, 443 from Internet
- **Outbound:** 30000-32767 to Worker Nodes (Instance Mode)

### 2. Bastion Security Group

**용도:** SSH Jump Server

- **Inbound:** 22 from Admin IPs
- **Outbound:** 22 to Control Plane/Workers, 6443 to Control Plane

### 3. NAT Instance Security Group

**용도:** NAT for Private Subnets

- **Inbound:**
  - 22 from Bastion
  - 80, 443 from Private Subnets
- **Outbound:** 80, 443 to Internet

### 4. Control Plane Security Group

**용도:** Kubernetes Master

- **Inbound:**
  - 22 from Bastion
  - 6443 from Workers, Bastion
  - 2379-2380 from Self (etcd)
  - 10250-10252 from Workers
- **Outbound:** All

### 5. Worker Node Security Group

**용도:** Kubernetes Workers

- **Inbound:**
  - 22 from Bastion
  - 10250 from Control Plane, Self
  - 30000-32767 from ALB
  - All from Self (Pod networking)
- **Outbound:**
  - 6443 to Control Plane
  - 5432 to RDS
  - 6379 to ElastiCache
  - All to Internet

### 6. RDS Security Group

**용도:** PostgreSQL Database

- **Inbound:** 5432 from Worker Nodes

### 7. ElastiCache Security Group

**용도:** Redis Cache

- **Inbound:** 6379 from Worker Nodes

## 사용 예시

```hcl
module "security_groups" {
  source = "./modules/security-groups"

  vpc_id      = module.vpc.vpc_id
  vpc_cidr    = module.vpc.vpc_cidr_block
  environment = "prod"
  name_prefix = "ticketbooking-prod"

  private_subnet_cidrs = [
    "10.0.11.0/24",
    "10.0.12.0/24"
  ]

  allowed_ssh_cidr = "1.2.3.4/32"

  tags = local.common_tags
}
```

## 보안 검증

### Security Group Audit 스크립트

```bash
#!/bin/bash
# security-audit.sh
# 0.0.0.0/0으로 개방된 규칙 찾기

aws ec2 describe-security-groups \
  --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]].[GroupId,GroupName]' \
  --output table
```

## 주의사항

1. **0.0.0.0/0 최소화**
   - ALB만 인터넷 노출
   - Bastion은 특정 IP만 허용

2. **순환 참조 방지**
   - Security Group 간 참조 시 의존성 주의

3. **규칙 수 제한**
   - Security Group당 최대 60개 인바운드, 60개 아웃바운드 규칙

4. **변경 관리**
   - 프로덕션 변경 전 반드시 dev/staging 테스트
