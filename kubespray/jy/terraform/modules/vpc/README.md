# VPC 모듈

Kubernetes 클러스터를 위한 AWS VPC 및 네트워킹 구성 모듈

## 기능

- ✅ VPC 생성 (Custom CIDR)
- ✅ Multi-AZ Public/Private Subnet
- ✅ Internet Gateway
- ✅ NAT Gateway 또는 NAT Instance 지원
- ✅ Kubernetes AWS Load Balancer Controller 태그 지원

## 아키텍처

```
VPC (10.0.0.0/16)
├── Public Subnet A (10.0.1.0/24)  [AZ-A]
├── Public Subnet B (10.0.2.0/24)  [AZ-B]
├── Private Subnet A (10.0.11.0/24) [AZ-A]
└── Private Subnet B (10.0.12.0/24) [AZ-B]

Internet Gateway
├── Public Route Table → 0.0.0.0/0
└── Private Route Tables → NAT Gateway/Instance
```

## 사용 예시

```hcl
module "vpc" {
  source = "./modules/vpc"

  vpc_name    = "ticketbooking"
  vpc_cidr    = "10.0.0.0/16"
  environment = "prod"

  azs = {
    a = "ap-northeast-2a"
    b = "ap-northeast-2b"
  }

  public_subnet_cidrs = {
    a = "10.0.1.0/24"
    b = "10.0.2.0/24"
  }

  private_subnet_cidrs = {
    a = "10.0.11.0/24"
    b = "10.0.12.0/24"
  }

  enable_nat_gateway = false

  tags = local.common_tags
}
```

## 입력 변수

| 변수 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| vpc_name | string | 필수 | VPC 이름 |
| vpc_cidr | string | 필수 | VPC CIDR 블록 |
| environment | string | 필수 | 환경 (dev/staging/prod) |
| enable_nat_gateway | bool | false | NAT Gateway 사용 여부 |

## 출력값

| 출력 | 설명 |
|------|------|
| vpc_id | VPC ID |
| public_subnet_ids | Public Subnet ID 목록 |
| private_subnet_ids | Private Subnet ID 목록 |
| nat_gateway_id | NAT Gateway ID |

## 주의사항

1. **NAT Gateway vs NAT Instance**
   - NAT Gateway: 관리형, 고가용성, 비용 높음 (~$32/월)
   - NAT Instance: 직접 관리, 비용 저렴 (~$10/월)
   - 교육 목적: NAT Instance 권장
