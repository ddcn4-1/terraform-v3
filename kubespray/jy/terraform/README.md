# 임시 Terraform README.md

## 간단 적용 방법

### 0. 기초 설정

1. state 관리를 위한 s3 생성

- ddcn41-pjy-terraform-state 라는 이름의 S3 생성
- backend.tf 참고하여 생성

2. 필요 변수 주입

- `cp terraform.tfvars.example terraform.tfvars` 후 값 작성

### 1. Terraform 초기화

`terraform init`

### 2. 모듈 다운로드 확인

`ls .terraform/modules/`

### 3. Validation

`terraform validate`

### 4. Plan 확인

`terraform plan`

### 5. 특정 모듈만 Plan

`terraform plan -target=module.vpc`

### 6. Apply (VPC만)

`terraform apply -target=module.vpc`

### 7. Output 확인

`terraform output`

### VPC ID 확인

`terraform output -json | jq '.vpc_id'`

### 8. AWS Console에서 확인

1. VPC → Your VPCs → 생성된 VPC 확인

2. Subnets → 4개의 Subnet 확인

3. Route Tables → Public/Private RT 확인

4. Internet Gateways → IGW 확인
