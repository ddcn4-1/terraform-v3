# IAM Roles 및 Policies 모듈

AWS 리소스에 대한 안전한 접근을 위한 IAM Role 및 Policy 정의

## 생성되는 IAM Roles

### 1. EC2 Instance Role

**용도:** EC2 인스턴스 (NAT, Bastion, K8s Nodes)  
**권한:**

- ECR: 이미지 Pull
- CloudWatch: 로그 및 메트릭 전송
- Secrets Manager: 민감 정보 조회
- S3: 백업 및 로그 저장

### 2. GitHub Actions Role (OIDC)

**용도:** GitHub Actions CI/CD 파이프라인  
**권한:**

- ECR: 이미지 Push
- S3: Frontend 파일 업로드
- CloudFront: 캐시 무효화

### 3. AWS Load Balancer Controller Role

**용도:** Kubernetes Ingress → ALB 생성  
**권한:**

- EC2: ALB, Security Group 관리
- ELB: Load Balancer 생성/수정/삭제
- ACM: 인증서 조회

### 4. ExternalDNS Role

**용도:** Kubernetes Ingress → Route 53 레코드 생성  
**권한:**

- Route 53: 레코드 생성/수정/삭제

## 보안 설계 원칙

### 1. 최소 권한 원칙 (Least Privilege)

```
각 Role은 필요한 최소한의 권한만 부여
- EC2 Role: ECR, CloudWatch만
- GitHub Role: S3, CloudFront만
```

### 2. 리소스 제한

```
Resource ARN을 명시적으로 지정
- ❌ Resource = "*"
- ✅ Resource = "arn:aws:s3:::my-bucket/*"
```

### 3. 조건부 접근

```
Condition을 사용한 세밀한 제어
- IP 제한
- 시간 제한
- MFA 요구
```

## GitHub Actions OIDC 설정

### 1. OIDC Provider 생성

자동으로 생성됨 (이 모듈에서)

### 2. GitHub Repository에 Role ARN 설정

```bash
# GitHub Repository Settings → Secrets and variables → Actions
# New repository secret 추가:
AWS_ROLE_ARN: 
```

### 3. 워크플로우 파일 작성

```yaml
# .github/workflows/deploy.yml
permissions:
  id-token: write
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
      aws-region: ap-northeast-2
```

## Kubernetes Service Account 설정

### AWS Load Balancer Controller

```bash
# 1. ServiceAccount 생성
kubectl create serviceaccount aws-load-balancer-controller \
  -n kube-system

# 2. Role ARN Annotation 추가
kubectl annotate serviceaccount aws-load-balancer-controller \
  -n kube-system \
  eks.amazonaws.com/role-arn=

# 3. Helm으로 설치
helm install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName= \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### ExternalDNS

```bash
# 1. ServiceAccount 생성
kubectl create serviceaccount external-dns \
  -n kube-system

# 2. Role ARN Annotation 추가
kubectl annotate serviceaccount external-dns \
  -n kube-system \
  eks.amazonaws.com/role-arn=

# 3. Deployment 생성
kubectl apply -f external-dns-deployment.yaml
```

## 사용 예시

```hcl
module "iam" {
  source = "./modules/iam"

  environment = "prod"
  name_prefix = "ticketbooking-prod"

  # S3 버킷
  s3_bucket_names = [
    "ddcn41-main-frontend",
    "ddcn41-accounts-frontend",
    "ddcn41-admin-frontend"
  ]

  # GitHub Actions
  github_org      = "your-org"
  github_repo     = "your-repo"
  github_branches = ["main", "develop"]

  # Kubernetes
  k8s_cluster_name = "ddcn41-k8s"
  vpc_id           = module.vpc.vpc_id
  route53_zone_id  = module.route53.zone_id

  tags = local.common_tags
}
```

## 주의사항

1. **OIDC Thumbprint**
   - GitHub의 OIDC Thumbprint는 변경될 수 있음
   - 정기적으로 확인 필요
   - 참고: <https://github.blog/changelog/>

2. **권한 감사**
   - 정기적으로 IAM Policy Simulator로 권한 테스트
   - CloudTrail로 실제 사용 권한 모니터링
   - 사용하지 않는 권한 제거

3. **Role 생명주기**
   - Role 삭제 시 연결된 리소스 확인
   - Policy 변경 시 영향 받는 서비스 확인

## 트러블슈팅

### GitHub Actions 인증 실패

```
Error: Not authorized to perform sts:AssumeRoleWithWebIdentity
```

**해결:**

1. OIDC Provider가 생성되었는지 확인
2. Trust Policy의 조건 확인 (org/repo/branch)
3. GitHub Actions 워크플로우의 `permissions` 확인

### EC2에서 권한 오류

```
Error: An error occurred (403) when calling the GetObject operation
```

**해결:**

1. Instance Profile이 EC2에 연결되었는지 확인
2. IAM Role Policy 확인
3. Resource ARN 확인
