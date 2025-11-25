# Infrastructure Changes: dh → ddcn41

## 개요

`eks/dh` (단일 리전) 프로젝트를 `eks/ddcn41` (멀티 리전 DR) 프로젝트로 확장하면서 발생한 변경사항과 그 이유를 정리한 문서입니다.

---

## 1. 디렉토리 구조 비교

### eks/dh (기존 - 단일 리전)
```
dh/
├── TEAM_GUIDE.md
├── ansible/
├── infrastructure/
│   ├── environments/
│   │   └── dev/                 # 개발 환경만 존재
│   ├── modules/
│   │   ├── alb/
│   │   ├── eks/
│   │   ├── rds/
│   │   ├── redis/
│   │   └── vpc/
│   └── shared/
└── ticketing-chart/
```

### eks/ddcn41 (신규 - 멀티 리전 DR)
```
ddcn41/
├── CLUSTER_MIGRATION_WORKFLOW.md    # 신규: DR 워크플로우 문서
├── DR_RECOVERY_LOG.md               # 신규: DR 복구 로그
├── TEAM_GUIDE.md
├── ansible/                         # 대폭 확장: DR 자동화
├── infrastructure/
│   ├── environments/
│   │   ├── dev/
│   │   ├── seoul/               # 신규: Primary 리전
│   │   └── tokyo/               # 신규: DR 리전
│   ├── modules/
│   │   ├── alb/
│   │   ├── aws-backup/          # 신규: AWS Backup 모듈
│   │   ├── ecr/                 # 신규: ECR 크로스 리전 복제
│   │   ├── eks/                 # 수정: 멀티 리전 IAM 지원
│   │   ├── phz/                 # 신규: Private Hosted Zone
│   │   ├── rds/
│   │   ├── redis/
│   │   ├── velero/              # 신규: Velero 백업/복구
│   │   └── vpc/
│   └── shared/
└── ticketing-chart/
```

---

## 2. 신규 추가된 Terraform 모듈

### 2.1 Velero 모듈 (`modules/velero/`)

**추가 이유**: Kubernetes 클러스터 간 워크로드 마이그레이션 및 DR 복구 지원

**주요 기능**:
- S3 버킷 (백업 저장소) + KMS 암호화
- Cross-Region Replication (Seoul → Tokyo 자동 복제)
- IRSA (IAM Roles for Service Accounts) 기반 권한 관리
- 멀티 리전 OIDC Provider 지원 (양쪽 클러스터에서 동일 Role 사용)

```hcl
# 멀티 리전 IRSA 핵심 로직
locals {
  all_oidc_providers = concat([var.eks_oidc_provider_arn], var.additional_oidc_providers)
}

# Tokyo 클러스터도 Seoul의 Velero IAM Role 사용 가능
dynamic "statement" {
  for_each = local.all_oidc_providers
  content {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [statement.value]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    # ...
  }
}
```

**참고 문서**:
- [Velero AWS Plugin 공식 문서](https://velero.io/docs/main/contributions/ibm-config/)
- [AWS S3 Cross-Region Replication](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html)

---

### 2.2 PHZ 모듈 (`modules/phz/`)

**추가 이유**: DR 전환 시 애플리케이션 코드 변경 없이 DB/Redis 엔드포인트 전환

**아키텍처**:
```
┌─────────────────────────────────────────────────────────────┐
│                   PHZ: ddcn41.internal                      │
├─────────────────────────────────────────────────────────────┤
│  db.ddcn41.internal    → Seoul RDS (정상) / Tokyo RDS (DR)  │
│  redis.ddcn41.internal → Seoul Redis (정상) / Tokyo Redis (DR)│
└─────────────────────────────────────────────────────────────┘
       ↑                                    ↑
   Seoul VPC 연결                      Tokyo VPC 연결
```

**변경이 필요했던 이유**:
- 애플리케이션이 `DATABASE_HOST=db.ddcn41.internal` 환경변수 사용
- DR 전환 시 DNS 레코드만 변경하면 됨 (앱 재배포 불필요)
- TTL 300초로 설정하여 빠른 DNS 전파

---

### 2.3 AWS Backup 모듈 (`modules/aws-backup/`)

**추가 이유**: RDS, EBS 등 AWS 관리형 리소스의 자동화된 백업

**주요 기능**:
- 일간/주간/월간 백업 스케줄
- Cross-Region 백업 복사 (Tokyo로 자동 복제)
- KMS 암호화

---

### 2.4 ECR 모듈 (`modules/ecr/`)

**추가 이유**: 컨테이너 이미지 멀티 리전 복제

**주요 기능**:
- ECR 리포지토리 생성
- Cross-Region Replication (Seoul → Tokyo)
- 취약점 스캔 자동화

---

## 3. 수정된 기존 모듈

### 3.1 EKS 모듈 변경사항

**변경 이유**: IAM Role은 글로벌 리소스이므로 Seoul에서만 생성하고 Tokyo에서 재사용

#### 3.1.1 조건부 IAM Role 생성

**기존 (dh)**:
```hcl
resource "aws_iam_role" "cluster" {
  name = "${var.project_name}-eks-cluster-role"
  # ...
}
```

**변경 (ddcn41)**:
```hcl
locals {
  cluster_role_arn  = var.create_iam_roles ? aws_iam_role.cluster[0].arn : var.existing_cluster_role_arn
  node_role_arn     = var.create_iam_roles ? aws_iam_role.node[0].arn : var.existing_node_role_arn
}

resource "aws_iam_role" "cluster" {
  count = var.create_iam_roles ? 1 : 0  # 조건부 생성
  name  = "${var.project_name}-eks-cluster-role"
  # ...
}
```

#### 3.1.2 OIDC Provider 추가

**변경 이유**: IRSA 지원을 위해 EKS 모듈에서 OIDC Provider 자동 생성

```hcl
# 신규 추가
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}
```

#### 3.1.3 새로운 변수

```hcl
variable "create_iam_roles" {
  description = "Whether to create IAM roles (set to false in DR region)"
  type        = bool
  default     = true
}

variable "existing_cluster_role_arn" {
  description = "ARN of existing EKS cluster IAM role"
  type        = string
  default     = null
}

variable "existing_node_role_arn" {
  description = "ARN of existing EKS node IAM role"
  type        = string
  default     = null
}
```

---

## 4. 환경 구성 변경

### 4.1 Seoul (Primary) 환경

**역할**: 글로벌 리소스 생성 + 로컬 리소스

```hcl
# environments/seoul/main.tf

# 글로벌 리소스 (Seoul에서만 생성)
module "velero" {
  create_iam_role = true              # IAM Role 생성
  create_bucket   = true              # S3 버킷 생성
  enable_cross_region_replication = true

  # Tokyo OIDC를 Trust Policy에 추가
  additional_oidc_providers = var.tokyo_cluster_exists ? [
    data.aws_iam_openid_connect_provider.tokyo[0].arn
  ] : []
}

module "phz" {
  # PHZ는 Seoul에서만 생성, 양쪽 VPC에 연결
}
```

### 4.2 Tokyo (DR) 환경

**역할**: 로컬 리소스만 생성, 글로벌 리소스는 Seoul 참조

```hcl
# environments/tokyo/main.tf

# Seoul State 참조
data "terraform_remote_state" "seoul" {
  backend = "s3"
  config = {
    bucket = "ticketing-terraform-state-guk"
    key    = "multiregion/seoul/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

module "eks" {
  create_iam_roles = false  # IAM Role 생성 안함
  existing_cluster_role_arn = data.terraform_remote_state.seoul.outputs.eks_cluster_iam_role_arn
  existing_node_role_arn    = data.terraform_remote_state.seoul.outputs.eks_node_iam_role_arn
}

module "velero" {
  create_iam_role = false
  create_bucket   = false
  existing_velero_role_arn = data.terraform_remote_state.seoul.outputs.velero_role_arn
  existing_bucket_arn      = data.terraform_remote_state.seoul.outputs.velero_replica_bucket_arn
}
```

---

## 5. Makefile 협업 루틴

### 5.1 Infrastructure Makefile

**위치**: `infrastructure/Makefile`

**주요 타겟**:

| 카테고리 | 명령어 | 설명 |
|---------|--------|------|
| **개발** | `make dev-plan/apply` | Dev 환경 관리 |
| **Seoul** | `make seoul-plan/apply` | Primary 환경 (Production) |
| **Tokyo** | `make tokyo-plan/apply` | DR 환경 |
| **Velero** | `make velero-install REGION=seoul` | Velero 설치 |
| **DR** | `make dr-failover` | DR 전환 |
| **컨텍스트** | `make use-seoul/tokyo` | kubectl 컨텍스트 전환 |

**협업 시 주의사항**:
```bash
# Seoul을 먼저 배포해야 Tokyo가 remote_state 참조 가능
make seoul-init && make seoul-plan && make seoul-apply
make tokyo-init && make tokyo-plan && make tokyo-apply
```

### 5.2 Ansible Makefile

**위치**: `ansible/Makefile`

**주요 타겟**:

| 카테고리 | 명령어 | 설명 |
|---------|--------|------|
| **설치** | `make install` | Seoul & Tokyo 동시 Velero 설치 |
| **백업** | `make seoul-backup NS=ticketing` | 특정 네임스페이스 백업 |
| **백업** | `make seoul-backup-full NAME=full` | 전체 클러스터 백업 |
| **복구** | `make tokyo-restore-full BACKUP=name` | 복구 + PHZ DNS 전환 |
| **PHZ** | `make phz-tokyo` | DNS를 Tokyo로 전환 |
| **PHZ** | `make phz-seoul` | DNS를 Seoul로 롤백 |

---

## 6. 변경이 필요했던 이유

### 6.1 IAM Role 글로벌 특성

AWS IAM Role은 리전에 종속되지 않는 글로벌 리소스입니다.

**문제**:
- Seoul과 Tokyo에서 각각 동일 이름 Role 생성 시 충돌
- IRSA를 사용하려면 양쪽 OIDC Provider가 Trust Policy에 있어야 함

**해결**:
- Seoul에서만 IAM Role 생성 (`create_iam_roles = true`)
- Tokyo는 Seoul Role 참조 (`create_iam_roles = false`)
- Velero Role의 Trust Policy에 양쪽 OIDC Provider 추가

### 6.2 S3 Cross-Region Replication

**요구사항**: Seoul 백업이 Tokyo에서도 접근 가능해야 함

**구현**:
```hcl
resource "aws_s3_bucket_replication_configuration" "velero" {
  bucket = local.bucket_id
  role   = aws_iam_role.replication[0].arn

  rule {
    status = "Enabled"

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }

    destination {
      bucket        = aws_s3_bucket.velero_replica[0].arn
      encryption_configuration {
        replica_kms_key_id = aws_kms_key.velero_replica[0].arn
      }
    }
  }
}
```

### 6.3 terraform_remote_state 의존성

**문제**: Tokyo가 Seoul 리소스를 참조해야 하지만 순환 의존성 방지 필요

**해결**: Seoul → Tokyo 단방향 참조만 허용

```
Seoul State (source of truth)
    │
    ├── IAM Roles (글로벌)
    ├── Velero S3/KMS (글로벌)
    ├── PHZ Zone ID
    │
    ▼
Tokyo State (remote_state로 Seoul 참조)
    │
    └── 로컬 리소스만 생성
        - VPC, EKS, RDS, Redis (Tokyo 리전)
```

---

## 7. 베스트 프랙티스 및 참고 자료

### 7.1 Multi-Region Terraform 패턴

- **Provider Alias**: 리전별 provider 정의
  ```hcl
  provider "aws" { region = "ap-northeast-2" }
  provider "aws" { alias = "tokyo"; region = "ap-northeast-1" }
  ```

- **Remote State**: 리전 간 리소스 참조
  ```hcl
  data "terraform_remote_state" "seoul" {
    backend = "s3"
    config = { ... }
  }
  ```

- **Conditional Resources**: count/for_each로 리전별 리소스 제어
  ```hcl
  resource "aws_iam_role" "example" {
    count = var.create_iam_roles ? 1 : 0
  }
  ```

### 7.2 참고 문서

**Terraform**:
- [Terraform Multi-Region Deployment](https://developer.hashicorp.com/terraform/tutorials/aws/aws-multi-region)
- [AWS Provider - Multiple Region Configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#alias-usage)
- [S3 Replication Configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_replication_configuration)

**Velero**:
- [Velero Disaster Recovery](https://velero.io/docs/main/disaster-case/)
- [Velero AWS Plugin](https://github.com/vmware-tanzu/velero-plugin-for-aws)
- [IRSA for Velero](https://velero.io/docs/main/contributions/ibm-config/)

**AWS**:
- [EKS IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Route53 Private Hosted Zone](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-private.html)
- [S3 Cross-Region Replication](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html)
- [AWS Backup Cross-Region](https://docs.aws.amazon.com/aws-backup/latest/devguide/cross-region-backup.html)

---

## 8. 협업 워크플로우

### 8.1 초기 배포 순서

```bash
# 1. Seoul 먼저 (글로벌 리소스 생성)
cd infrastructure
make seoul-init
make seoul-plan
make seoul-apply

# 2. Tokyo 배포 (Seoul State 참조)
make tokyo-init
make tokyo-plan
make tokyo-apply

# 3. Velero 설치 (양쪽 클러스터)
cd ../ansible
make install

# 4. 초기 백업 생성
make seoul-backup-full NAME=initial-backup
```

### 8.2 일상 운영

```bash
# 백업 생성
make seoul-backup NS=ticketing NAME=daily-$(date +%Y%m%d)

# 백업 상태 확인
velero backup get

# DR 테스트
make dr-test
```

### 8.3 DR 전환

```bash
# 1. Tokyo로 복구
make tokyo-restore-full BACKUP=latest-backup

# 2. PHZ DNS 전환
make phz-tokyo

# 3. (선택) 외부 DNS 업데이트
```

---

## 9. 주의사항

### 9.1 State Lock

Terraform은 DynamoDB로 State Lock을 관리합니다. 동시 작업 시:

```bash
# Lock이 걸렸을 때
terraform force-unlock <LOCK_ID>
```

### 9.2 IRSA 권한 문제

Tokyo BSL이 "Unavailable"이면:

```bash
# Seoul에서 Tokyo OIDC 추가
cd infrastructure/environments/seoul
terraform apply -var="tokyo_cluster_exists=true"

# Tokyo Velero 재시작
kubectl -n velero rollout restart deployment velero
```

### 9.3 PHZ DNS 캐시

DNS TTL (300초) 동안 이전 엔드포인트 캐시될 수 있음:

```bash
# Pod 재시작으로 DNS 캐시 초기화
kubectl rollout restart deployment -n ticketing
```
