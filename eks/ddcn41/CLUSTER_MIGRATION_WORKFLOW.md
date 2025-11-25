# Cluster Migration Workflow

Seoul → Tokyo 클러스터 마이그레이션 테스트 워크플로우

## 아키텍처 개요

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         글로벌 리소스 (Seoul에서 생성)                    │
├─────────────────────────────────────────────────────────────────────────┤
│  IAM Roles:                                                             │
│  - ticket-hs-eks-cluster-role     (EKS Cluster)                        │
│  - ticket-hs-eks-node-role        (EKS Node Group)                     │
│  - ticket-hs-velero-irsa-prod     (Velero IRSA)                        │
│  - ticket-hs-aws-backup-role-prod (AWS Backup)                         │
│  - ticket-hs-velero-replication-role (S3 Cross-Region Replication)     │
│                                                                         │
│  PHZ (Private Hosted Zone):                                            │
│  - ticket-hs.internal (Seoul/Tokyo VPC 모두 연결)                       │
│    └─ db.ticket-hs.internal    → 활성 리전 RDS                          │
│    └─ redis.ticket-hs.internal → 활성 리전 Redis                        │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────┐     S3 CRR      ┌─────────────────────────────┐
│       Seoul (Primary)        │ ─────────────► │         Tokyo (DR)           │
├─────────────────────────────┤                 ├─────────────────────────────┤
│ EKS Cluster                 │                 │ EKS Cluster                 │
│ RDS (Primary)               │                 │ RDS (Standby)               │
│ ElastiCache                 │                 │ ElastiCache                 │
│ S3: velero-prod-ap-ne-2     │                 │ S3: velero-prod-ap-ne-1     │
│ VPC (PHZ 연결됨)             │                 │ VPC (PHZ 연결됨)             │
└─────────────────────────────┘                 └─────────────────────────────┘
        │                                                │
        └── terraform_remote_state ◄─────────────────────┘
            (Tokyo가 Seoul State 참조)
```

**핵심 원칙:**
- **IAM Role**: 글로벌 리소스 → Seoul에서 생성, Tokyo에서 재사용 (`terraform_remote_state`)
- **S3 Bucket**: Seoul에서 생성 → Tokyo로 Cross-Region Replication
- **PHZ Zone**: Seoul에서 단일 Zone 생성 → 양쪽 VPC에 연결, DR 시 DNS 레코드만 업데이트
- **Velero Role**: Seoul에서 생성 → Tokyo Velero 설치 시 동일 Role 재사용 (IRSA)

## 사전 준비

### 1. Terraform Apply 완료 확인

**중요: Seoul을 먼저 배포해야 Tokyo가 IAM Role ARN을 참조할 수 있음**

```bash
cd eks/dh/infrastructure

# 1) Seoul 먼저 배포
make seoul-plan
make seoul-apply

# 2) Seoul output 확인 (Tokyo가 참조할 값들)
make seoul-output
# 확인해야 할 항목:
# - eks_cluster_iam_role_arn
# - eks_node_iam_role_arn
# - velero_role_arn
# - backup_role_arn

# 3) Tokyo 배포 (Seoul state 자동 참조)
make tokyo-plan
make tokyo-apply

# 4) Tokyo 인프라 확인
make tokyo-output
```

### 2. Ansible 의존성 설치
```bash
cd eks/dh/ansible
make deps
make check
```

### 3. kubectl 컨텍스트 확인
```bash
# Seoul 클러스터 연결
aws eks update-kubeconfig --region ap-northeast-2 --name ticket-hs-cluster

# 노드 확인
kubectl get nodes
```

<details>
<summary>🔧 사전 준비 트러블슈팅</summary>

#### ❌ Terraform output 실패
```
Error: No outputs found
```
**원인**: Terraform apply가 완료되지 않았거나 state 파일 접근 불가

**해결**:
```bash
# State 파일 확인
aws s3 ls s3://ticketing-terraform-state-guk/multiregion/

# Terraform init 재실행
cd infrastructure/environments/seoul
terraform init -reconfigure

# Apply 상태 확인
terraform show
```

#### ❌ EKS 클러스터 연결 실패
```
error: You must be logged in to the server (Unauthorized)
```
**원인**: AWS 자격 증명 만료 또는 IAM 권한 부족

**해결**:
```bash
# AWS 자격 증명 확인
aws sts get-caller-identity

# SSO 로그인 (SSO 사용 시)
aws sso login --profile <profile-name>

# kubeconfig 재생성
aws eks update-kubeconfig --region ap-northeast-2 --name ticket-hs-cluster --alias seoul

# IAM 권한 확인 (aws-auth ConfigMap)
kubectl -n kube-system get configmap aws-auth -o yaml
```

#### ❌ Ansible 의존성 설치 실패
```
ERROR! couldn't resolve module/action 'kubernetes.core.k8s'
```
**원인**: Ansible collection 미설치

**해결**:
```bash
# Collection 강제 재설치
ansible-galaxy collection install kubernetes.core --force
ansible-galaxy collection install amazon.aws --force

# Python 의존성 확인
pip install kubernetes boto3 botocore

# 설치 확인
ansible-galaxy collection list | grep -E "kubernetes|amazon"
```

#### ❌ Node NotReady 상태
```
NAME                                       STATUS     ROLES    AGE
ip-10-0-1-xxx.ap-northeast-2.compute...   NotReady   <none>   5m
```
**원인**: Node 초기화 미완료, CNI 문제, 또는 리소스 부족

**해결**:
```bash
# Node 상태 상세 확인
kubectl describe node <node-name>

# Node 이벤트 확인
kubectl get events --field-selector involvedObject.kind=Node

# CNI Pod 확인 (AWS VPC CNI)
kubectl -n kube-system get pods -l k8s-app=aws-node

# Node group 스케일링 확인
aws eks describe-nodegroup --cluster-name ticket-hs-cluster --nodegroup-name <nodegroup-name>
```

</details>

---

## 테스트 워크플로우

### Phase 1: Velero 설치 (Seoul & Tokyo 동시)

```bash
cd eks/dh/ansible
make install
```

설치 확인:
```bash
# Seoul
aws eks update-kubeconfig --region ap-northeast-2 --name ticket-hs-cluster
velero version
velero backup-location get

# Tokyo
aws eks update-kubeconfig --region ap-northeast-1 --name ticket-hs-cluster
velero version
velero backup-location get
```

<details>
<summary>🔧 Phase 1 트러블슈팅: Velero 설치</summary>

#### ❌ Helm 설치 실패 - IRSA 오류
```
Error: INSTALLATION FAILED: unable to build kubernetes objects from release manifest
```
**원인**: OIDC Provider 설정 불완전 또는 IAM Role ARN 오류

**참고**: Velero IAM Role은 Seoul에서 생성되며 Tokyo에서도 동일 Role 재사용

**해결**:
```bash
# 현재 리전의 OIDC Provider 확인
aws eks describe-cluster --name ticket-hs-cluster \
  --query "cluster.identity.oidc.issuer" --output text

# IAM OIDC Provider 존재 확인
aws iam list-open-id-connect-providers | grep $(aws eks describe-cluster \
  --name ticket-hs-cluster --query "cluster.identity.oidc.issuer" \
  --output text | sed 's/https:\/\///')

# Velero IAM Role 확인 (글로벌 리소스 - Seoul에서 생성)
aws iam get-role --role-name ticket-hs-velero-irsa-prod

# IAM Role Trust Policy에 양쪽 OIDC Provider가 있는지 확인
aws iam get-role --role-name ticket-hs-velero-irsa-prod \
  --query 'Role.AssumeRolePolicyDocument.Statement[].Principal.Federated'

# Terraform에서 OIDC 재생성 (해당 리전)
cd infrastructure/environments/seoul  # 또는 tokyo
terraform apply -target=module.eks
```

#### ❌ BackupStorageLocation 상태 Unavailable
```
NAME      PHASE         LAST VALIDATED   AGE
default   Unavailable   Unknown          5m
```
**원인**: S3 버킷 접근 불가, KMS 권한 부족, 또는 리전 설정 오류

**해결**:
```bash
# Velero Pod 로그 확인
kubectl -n velero logs deployment/velero -c velero

# S3 버킷 존재 확인
aws s3 ls s3://ticket-hs-velero-prod-ap-northeast-2/

# IRSA ServiceAccount 확인
kubectl -n velero get sa velero -o yaml | grep eks.amazonaws.com

# IAM Role 정책 확인
aws iam list-attached-role-policies --role-name ticket-hs-velero-irsa-prod

# KMS 키 접근 테스트
aws kms describe-key --key-id alias/ticket-hs-velero-prod
```

#### ❌ Velero Pod CrashLoopBackOff
```
NAME                     READY   STATUS             RESTARTS   AGE
velero-xxx-xxx           0/1     CrashLoopBackOff   5          10m
```
**원인**: 리소스 부족, 이미지 풀 실패, 또는 설정 오류

**해결**:
```bash
# Pod 이벤트 확인
kubectl -n velero describe pod -l component=velero

# 이전 로그 확인
kubectl -n velero logs deployment/velero --previous

# 리소스 확인
kubectl -n velero get pod -l component=velero -o yaml | grep -A 10 resources

# Helm values 확인
helm -n velero get values velero
```

#### ❌ Plugin 로드 실패
```
level=error msg="Error getting backup storage location" error="backup storage location \"default\" has invalid configuration: access denied"
```
**원인**: velero-plugin-for-aws 버전 불일치 또는 IAM 권한 부족

**해결**:
```bash
# Plugin 버전 확인
kubectl -n velero get deployment velero -o yaml | grep image

# 권장 버전 조합
# Velero 1.12.x → Plugin 1.8.x
# Velero 1.13.x → Plugin 1.9.x
# Velero 1.14.x → Plugin 1.10.x

# InitContainer 로그 확인 (Plugin 로드)
kubectl -n velero logs deployment/velero -c velero-plugin-for-aws
```

</details>

---

### Phase 2: 테스트 앱 배포 (Seoul)

```bash
# Seoul 클러스터로 전환
aws eks update-kubeconfig --region ap-northeast-2 --name ticket-hs-cluster

# 테스트 네임스페이스 생성
kubectl create namespace test-app

# nginx 배포
kubectl -n test-app create deployment nginx --image=nginx:latest --replicas=2
kubectl -n test-app expose deployment nginx --port=80

# ConfigMap 생성 (PHZ DNS 사용)
kubectl -n test-app create configmap app-config \
  --from-literal=DATABASE_HOST=db.ticket-hs.internal \
  --from-literal=REDIS_HOST=redis.ticket-hs.internal

# 배포 확인
kubectl -n test-app get all
kubectl -n test-app get configmap app-config -o yaml
```

<details>
<summary>🔧 Phase 2 트러블슈팅: 앱 배포</summary>

#### ❌ Pod ImagePullBackOff
```
NAME                     READY   STATUS             RESTARTS   AGE
nginx-xxx-xxx            0/1     ImagePullBackOff   0          5m
```
**원인**: ECR 인증 실패, 이미지 태그 오류, 또는 네트워크 문제

**해결**:
```bash
# 이벤트 상세 확인
kubectl -n test-app describe pod -l app=nginx

# Docker Hub rate limit 확인 (public image 사용 시)
kubectl -n test-app get events --sort-by='.lastTimestamp'

# ECR 이미지 사용 시 - 인증 확인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin <account>.dkr.ecr.ap-northeast-2.amazonaws.com

# NAT Gateway 확인 (private subnet에서 외부 접근)
kubectl run test-curl --rm -it --image=curlimages/curl -- curl -I https://hub.docker.com
```

#### ❌ Pod Pending - Insufficient Resources
```
NAME                     READY   STATUS    RESTARTS   AGE
nginx-xxx-xxx            0/1     Pending   0          10m
```
**원인**: 노드 리소스 부족 또는 스케줄링 제약

**해결**:
```bash
# Pod 이벤트 확인
kubectl -n test-app describe pod -l app=nginx | grep -A 10 Events

# 노드 리소스 확인
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# Node group 스케일 업
aws eks update-nodegroup-config \
  --cluster-name ticket-hs-cluster \
  --nodegroup-name <nodegroup-name> \
  --scaling-config desiredSize=3,minSize=2,maxSize=5
```

#### ❌ Service Endpoint 없음
```
NAME    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
nginx   ClusterIP   172.20.xxx.xxx  <none>        80/TCP    5m

$ kubectl -n test-app get endpoints nginx
NAME    ENDPOINTS   AGE
nginx   <none>      5m
```
**원인**: Pod selector 불일치 또는 Pod가 Ready 상태가 아님

**해결**:
```bash
# Service selector 확인
kubectl -n test-app get svc nginx -o yaml | grep -A 3 selector

# Pod labels 확인
kubectl -n test-app get pods --show-labels

# Pod Ready 상태 확인
kubectl -n test-app get pods -o wide

# Readiness Probe 확인
kubectl -n test-app describe pod -l app=nginx | grep -A 5 Readiness
```

#### ❌ PHZ DNS 해석 실패
```bash
$ kubectl -n test-app exec -it nginx-xxx -- nslookup db.ticket-hs.internal
;; connection timed out; no servers could be reached
```
**원인**: VPC DNS 설정 문제 또는 PHZ가 VPC에 연결되지 않음

**해결**:
```bash
# VPC DNS 설정 확인
VPC_ID=$(aws eks describe-cluster --name ticket-hs-cluster \
  --query "cluster.resourcesVpcConfig.vpcId" --output text)

aws ec2 describe-vpc-attribute --vpc-id $VPC_ID --attribute enableDnsSupport
aws ec2 describe-vpc-attribute --vpc-id $VPC_ID --attribute enableDnsHostnames

# PHZ-VPC 연결 확인
PHZ_ZONE_ID=$(terraform -chdir=infrastructure/environments/seoul output -raw phz_zone_id)
aws route53 get-hosted-zone --id $PHZ_ZONE_ID | grep -A 10 VPCs

# CoreDNS 상태 확인
kubectl -n kube-system get pods -l k8s-app=kube-dns
kubectl -n kube-system logs -l k8s-app=kube-dns
```

</details>

---

### Phase 3: 백업 생성 (Seoul)

```bash
cd eks/dh/ansible

# 백업 생성
make seoul-backup NAME=migration-test

# 또는 특정 네임스페이스만
velero backup create migration-test \
  --include-namespaces test-app \
  --wait

# 백업 상태 확인
velero backup describe migration-test
velero backup logs migration-test
```

<details>
<summary>🔧 Phase 3 트러블슈팅: 백업 생성</summary>

#### ❌ 백업 상태 PartiallyFailed
```
Phase:  PartiallyFailed

Errors:
  Velero:     <none>
  Cluster:    <none>
  Namespaces:
    test-app:  error backing up item: pods/test-app/nginx-xxx
```
**원인**: 특정 리소스 백업 실패 (권한, 리소스 상태, 또는 hook 실패)

**해결**:
```bash
# 백업 로그 상세 확인
velero backup logs migration-test | grep -i error

# 특정 리소스 제외하고 재시도
velero backup create migration-test-v2 \
  --include-namespaces test-app \
  --exclude-resources pods \
  --wait

# 실패한 리소스 상태 확인
kubectl -n test-app describe pod nginx-xxx
```

#### ❌ 백업 상태 Failed - S3 업로드 실패
```
Phase: Failed
Errors:
  Velero: error uploading backup to object storage: AccessDenied
```
**원인**: S3 버킷 권한 부족 또는 KMS 암호화 권한 없음

**해결**:
```bash
# IRSA 토큰 확인
kubectl -n velero exec deployment/velero -- \
  cat /var/run/secrets/eks.amazonaws.com/serviceaccount/token | \
  cut -d. -f2 | base64 -d | jq .

# S3 직접 접근 테스트 (Velero Pod 내에서)
kubectl -n velero exec deployment/velero -- \
  aws s3 ls s3://ticket-hs-velero-prod-ap-northeast-2/

# IAM 정책 확인
aws iam get-role-policy --role-name ticket-hs-velero-irsa-prod \
  --policy-name velero-s3-policy
```

#### ❌ 백업이 매우 느림 (30분 이상)
**원인**: 대용량 PV, 많은 리소스, 또는 네트워크 병목

**해결**:
```bash
# 백업 진행 상황 확인
velero backup describe migration-test --details

# PV 크기 확인
kubectl get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage

# 대용량 PV 제외 (필요 시)
velero backup create migration-test-fast \
  --include-namespaces test-app \
  --snapshot-volumes=false \
  --wait

# 병렬 업로드 설정 확인
kubectl -n velero get deployment velero -o yaml | grep -i parallel
```

#### ❌ Snapshot 생성 실패 (EBS)
```
Errors:
  Velero: error creating snapshot: VolumeSnapshotLocation "default" is unavailable
```
**원인**: VolumeSnapshotLocation 미설정 또는 CSI 드라이버 문제

**해결**:
```bash
# VolumeSnapshotLocation 확인
velero snapshot-location get

# EBS CSI Driver 확인
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver

# VolumeSnapshotClass 확인
kubectl get volumesnapshotclass

# Snapshot 없이 백업 (리소스만)
velero backup create migration-test-nosnapshot \
  --include-namespaces test-app \
  --snapshot-volumes=false \
  --wait
```

</details>

---

### Phase 4: S3 복제 확인

```bash
# S3 복제 상태 확인 (약 1-5분 소요)
aws s3 ls s3://ticket-hs-velero-prod-ap-northeast-2/backups/
aws s3 ls s3://ticket-hs-velero-prod-ap-northeast-1/backups/

# 백업 파일 비교
aws s3 ls s3://ticket-hs-velero-prod-ap-northeast-2/backups/migration-test/ --recursive
aws s3 ls s3://ticket-hs-velero-prod-ap-northeast-1/backups/migration-test/ --recursive
```

<details>
<summary>🔧 Phase 4 트러블슈팅: S3 복제</summary>

#### ❌ 복제가 시작되지 않음
```bash
# Seoul 버킷에는 있지만 Tokyo 버킷에 없음
$ aws s3 ls s3://ticket-hs-velero-prod-ap-northeast-1/backups/migration-test/
# (아무것도 출력 안됨)
```
**원인**: S3 복제 규칙 미설정 또는 버전 관리 비활성화

**해결**:
```bash
# 복제 규칙 확인
aws s3api get-bucket-replication \
  --bucket ticket-hs-velero-prod-ap-northeast-2

# 버전 관리 상태 확인 (복제에 필수)
aws s3api get-bucket-versioning \
  --bucket ticket-hs-velero-prod-ap-northeast-2
aws s3api get-bucket-versioning \
  --bucket ticket-hs-velero-prod-ap-northeast-1

# 복제 IAM Role 확인
aws iam get-role --role-name ticket-hs-velero-replication-role

# Terraform에서 복제 재설정
cd infrastructure/environments/seoul
terraform apply -target=module.velero
```

#### ❌ 복제 지연 (15분 이상)
**원인**: 대용량 파일, S3 복제 백로그, 또는 리전 간 지연

**해결**:
```bash
# 복제 메트릭 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name ReplicationLatency \
  --dimensions Name=SourceBucket,Value=ticket-hs-velero-prod-ap-northeast-2 \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Average

# 개별 객체 복제 상태 확인
aws s3api head-object \
  --bucket ticket-hs-velero-prod-ap-northeast-2 \
  --key backups/migration-test/velero-backup.json \
  --query 'ReplicationStatus'

# 긴급 시 수동 복사
aws s3 sync \
  s3://ticket-hs-velero-prod-ap-northeast-2/backups/migration-test/ \
  s3://ticket-hs-velero-prod-ap-northeast-1/backups/migration-test/ \
  --source-region ap-northeast-2 \
  --region ap-northeast-1
```

#### ❌ 복제 실패 - KMS 암호화 오류
```
ReplicationStatus: FAILED
```
**원인**: 대상 리전 KMS 키 권한 부족 또는 키 미존재

**해결**:
```bash
# 소스 버킷 암호화 설정 확인
aws s3api get-bucket-encryption \
  --bucket ticket-hs-velero-prod-ap-northeast-2

# 대상 리전 KMS 키 확인
aws kms describe-key \
  --key-id alias/ticket-hs-velero-prod \
  --region ap-northeast-1

# 복제 역할의 KMS 권한 확인
aws iam get-role-policy \
  --role-name ticket-hs-velero-replication-role \
  --policy-name ticket-hs-velero-replication-policy
```

#### ❌ 일부 파일만 복제됨
**원인**: 복제 규칙 필터, 파일 크기 제한, 또는 타이밍 이슈

**해결**:
```bash
# 복제 규칙 필터 확인
aws s3api get-bucket-replication \
  --bucket ticket-hs-velero-prod-ap-northeast-2 \
  --query 'ReplicationConfiguration.Rules[].Filter'

# 소스와 대상 파일 수 비교
echo "Source:"
aws s3 ls s3://ticket-hs-velero-prod-ap-northeast-2/backups/migration-test/ --recursive | wc -l

echo "Destination:"
aws s3 ls s3://ticket-hs-velero-prod-ap-northeast-1/backups/migration-test/ --recursive | wc -l

# 누락된 파일 확인
diff <(aws s3 ls s3://ticket-hs-velero-prod-ap-northeast-2/backups/migration-test/ --recursive | awk '{print $4}' | sort) \
     <(aws s3 ls s3://ticket-hs-velero-prod-ap-northeast-1/backups/migration-test/ --recursive | awk '{print $4}' | sort)
```

</details>

---

### Phase 5: Tokyo에서 복구

```bash
# Tokyo 클러스터로 전환
aws eks update-kubeconfig --region ap-northeast-1 --name ticket-hs-cluster

# 백업 목록 확인 (복제된 백업이 보여야 함)
velero backup get

# 복구 실행
make tokyo-restore BACKUP=migration-test

# 또는 직접 실행
velero restore create migration-test-restore \
  --from-backup migration-test \
  --wait

# 복구 상태 확인
velero restore describe migration-test-restore
velero restore logs migration-test-restore
```

<details>
<summary>🔧 Phase 5 트러블슈팅: 복구</summary>

#### ❌ 백업이 Tokyo에서 안 보임
```
$ velero backup get
NAME   STATUS   ERRORS   WARNINGS   CREATED   EXPIRES   STORAGE LOCATION
(empty)
```
**원인**: S3 복제 미완료, BackupStorageLocation 설정 오류, 또는 버킷 경로 불일치

**해결**:
```bash
# BackupStorageLocation 확인
velero backup-location get

# BSL이 올바른 버킷을 가리키는지 확인
kubectl -n velero get backupstoragelocation default -o yaml | grep bucket

# Velero가 버킷을 스캔하도록 강제
kubectl -n velero annotate backupstoragelocation default \
  "velero.io/last-synced-time=$(date -u +%Y-%m-%dT%H:%M:%SZ)" --overwrite

# 로그 확인
kubectl -n velero logs deployment/velero | grep -i "backup" | tail -20
```

#### ❌ 복구 상태 PartiallyFailed
```
Phase: PartiallyFailed
Errors:
  Namespaces:
    test-app: error restoring configmaps/test-app/app-config: already exists
```
**원인**: 리소스가 이미 존재하거나 충돌

**해결**:
```bash
# 기존 네임스페이스 삭제 후 재시도
kubectl delete namespace test-app
velero restore create migration-test-restore-v2 \
  --from-backup migration-test \
  --wait

# 또는 기존 리소스 덮어쓰기 옵션 사용
velero restore create migration-test-restore-v2 \
  --from-backup migration-test \
  --existing-resource-policy update \
  --wait
```

#### ❌ 복구 실패 - PVC 바인딩 실패
```
Warnings:
  Velero: persistentvolumeclaims "data-pvc" not found
```
**원인**: StorageClass 불일치 또는 PV 프로비저닝 실패

**해결**:
```bash
# StorageClass 확인
kubectl get storageclass

# Seoul과 Tokyo StorageClass 이름 비교
# Seoul
kubectl --context seoul get storageclass
# Tokyo
kubectl --context tokyo get storageclass

# StorageClass 매핑으로 복구
velero restore create migration-test-restore-v2 \
  --from-backup migration-test \
  --storage-class-mappings gp2:gp3 \
  --wait

# PVC 없이 복구 (stateless 앱만)
velero restore create migration-test-restore-v2 \
  --from-backup migration-test \
  --exclude-resources persistentvolumeclaims,persistentvolumes \
  --wait
```

#### ❌ 복구 후 Pod ImagePullBackOff (ECR)
```
Failed to pull image "123456789.dkr.ecr.ap-northeast-2.amazonaws.com/app:v1"
```
**원인**: Seoul ECR 이미지를 Tokyo에서 접근 시도 (ECR은 리전별)

**해결**:
```bash
# ECR 복제 확인
aws ecr describe-repositories --region ap-northeast-1

# 이미지 존재 확인
aws ecr describe-images \
  --repository-name ticket-hs/app \
  --region ap-northeast-1

# 이미지 URL 치환이 필요한 경우 - Resource Modifier 사용
# velero ConfigMap에 추가
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: restore-resource-modifiers
  namespace: velero
data:
  ecr-region-modifier.yaml: |
    version: v1
    resourceModifierRules:
    - conditions:
        groupKind: apps/Deployment
      patches:
      - operation: replace
        path: "/spec/template/spec/containers/0/image"
        value: "\${current_value/ap-northeast-2/ap-northeast-1}"
EOF

# Resource Modifier 적용하여 복구
velero restore create migration-test-restore-v2 \
  --from-backup migration-test \
  --resource-modifier-configmap restore-resource-modifiers \
  --wait
```

#### ❌ 복구 시간 초과
```
Phase: InProgress (stuck for 30+ minutes)
```
**원인**: 대용량 데이터, 네트워크 병목, 또는 리소스 생성 지연

**해결**:
```bash
# 복구 진행 상황 확인
velero restore describe migration-test-restore --details

# 어떤 리소스에서 지연되는지 확인
kubectl -n velero logs deployment/velero | grep -i "restore" | tail -50

# 부분 복구 시도 (namespace별)
velero restore create test-app-restore \
  --from-backup migration-test \
  --include-namespaces test-app \
  --wait
```

</details>

---

### Phase 6: 복구 검증

```bash
# Tokyo 클러스터에서 확인
kubectl -n test-app get all
kubectl -n test-app get configmap app-config -o yaml

# Pod 상태 확인
kubectl -n test-app get pods

# ConfigMap의 PHZ DNS 확인
kubectl -n test-app get configmap app-config -o jsonpath='{.data.DATABASE_HOST}'
# 출력: db.ticket-hs.internal
```

<details>
<summary>🔧 Phase 6 트러블슈팅: 검증</summary>

#### ❌ 복구된 Pod가 CrashLoopBackOff
```
NAME                     READY   STATUS             RESTARTS   AGE
nginx-xxx-xxx            0/1     CrashLoopBackOff   5          10m
```
**원인**: ConfigMap/Secret 누락, 환경 차이, 또는 의존성 실패

**해결**:
```bash
# Pod 로그 확인
kubectl -n test-app logs nginx-xxx-xxx --previous

# 환경 변수 확인
kubectl -n test-app exec nginx-xxx-xxx -- env | sort

# ConfigMap/Secret 존재 확인
kubectl -n test-app get configmap,secret

# 의존 서비스 연결 테스트
kubectl -n test-app exec nginx-xxx-xxx -- nslookup db.ticket-hs.internal
kubectl -n test-app exec nginx-xxx-xxx -- nc -zv db.ticket-hs.internal 5432
```

#### ❌ Service LoadBalancer Pending
```
NAME    TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
nginx   LoadBalancer   172.20.xxx.xxx  <pending>     80:31234/TCP   10m
```
**원인**: ALB/NLB 프로비저닝 실패 또는 서브넷 태그 누락

**해결**:
```bash
# Service 이벤트 확인
kubectl -n test-app describe svc nginx

# AWS Load Balancer Controller 로그
kubectl -n kube-system logs -l app.kubernetes.io/name=aws-load-balancer-controller

# 서브넷 태그 확인
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'Subnets[*].[SubnetId,Tags[?Key==`kubernetes.io/role/elb`].Value]'
```

#### ❌ 데이터베이스 연결 실패
```
Error: connection refused to db.ticket-hs.internal:5432
```
**원인**: RDS 보안 그룹 규칙 누락 또는 PHZ 설정 오류

**해결**:
```bash
# PHZ 레코드 확인
aws route53 list-resource-record-sets \
  --hosted-zone-id $(terraform output -raw phz_zone_id) \
  --query "ResourceRecordSets[?Name=='db.ticket-hs.internal.']"

# RDS 보안 그룹 확인
RDS_SG=$(aws rds describe-db-instances \
  --db-instance-identifier ticket-hs-db \
  --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
  --output text --region ap-northeast-1)

aws ec2 describe-security-groups --group-ids $RDS_SG \
  --query 'SecurityGroups[0].IpPermissions'

# EKS 노드 보안 그룹에서 RDS 접근 허용 확인
EKS_SG=$(aws eks describe-cluster --name ticket-hs-cluster \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' \
  --output text --region ap-northeast-1)
```

#### ❌ 복구된 데이터 불일치
**원인**: 백업 시점과 현재 데이터 차이, 또는 부분 복구

**해결**:
```bash
# 백업 시점 확인
velero backup describe migration-test | grep "Started\|Completed"

# 복구된 리소스 수 확인
velero restore describe migration-test-restore | grep -A 20 "Phase:"

# 원본과 복구 비교
# Seoul
kubectl --context seoul -n test-app get all -o yaml > seoul-resources.yaml
# Tokyo
kubectl --context tokyo -n test-app get all -o yaml > tokyo-resources.yaml
diff seoul-resources.yaml tokyo-resources.yaml
```

</details>

---

### Phase 7: PHZ DNS 상태 확인

```bash
cd eks/dh/ansible

# 현재 PHZ 레코드 확인
make phz-verify

# 또는 직접 확인 (PHZ Zone은 Seoul에서 생성됨)
PHZ_ZONE_ID=$(terraform -chdir=../infrastructure/environments/seoul output -raw phz_zone_id)
aws route53 list-resource-record-sets --hosted-zone-id $PHZ_ZONE_ID
```

**PHZ 아키텍처:**
- **단일 Zone**: Seoul에서 `ticket-hs.internal` PHZ 생성
- **VPC 연결**: Seoul VPC와 Tokyo VPC 모두 동일 PHZ에 연결
- **DNS 레코드**: 현재 활성 리전의 RDS/Redis endpoint를 가리킴

**DR 전환 시:**
- `make phz-tokyo`: DNS 레코드를 Tokyo RDS/Redis로 업데이트
- `make phz-seoul`: DNS 레코드를 Seoul RDS/Redis로 롤백

앱은 `db.ticket-hs.internal`, `redis.ticket-hs.internal` 사용 → DNS 레코드 변경만으로 리전 전환 완료

<details>
<summary>🔧 Phase 7 트러블슈팅: PHZ</summary>

#### ❌ PHZ Zone ID 조회 실패
```
Error: No outputs found for phz_zone_id
```
**원인**: Seoul Terraform state 접근 불가 또는 PHZ 모듈 미적용

**참고**: PHZ Zone ID는 Seoul에서 생성되므로 항상 Seoul output에서 조회

**해결**:
```bash
# Seoul Terraform state 확인 (PHZ는 Seoul에서만 생성)
terraform -chdir=infrastructure/environments/seoul state list | grep phz

# PHZ 직접 검색
aws route53 list-hosted-zones-by-name \
  --dns-name ticket-hs.internal \
  --query 'HostedZones[?Config.PrivateZone==`true`]'
```

#### ❌ PHZ 레코드가 잘못된 endpoint를 가리킴
```
db.ticket-hs.internal -> seoul-rds.xxx.ap-northeast-2.rds.amazonaws.com (Tokyo에서 복구 후)
```
**원인**: PHZ 업데이트 미실행 (DR failover 시 PHZ 업데이트 필수)

**해결**:
```bash
# PHZ Zone ID 확인 (Seoul에서 생성됨)
PHZ_ZONE_ID=$(terraform -chdir=infrastructure/environments/seoul output -raw phz_zone_id)

# 현재 레코드 확인
aws route53 list-resource-record-sets \
  --hosted-zone-id $PHZ_ZONE_ID \
  --query "ResourceRecordSets[?Type=='CNAME']"

# Tokyo RDS endpoint 확인
TOKYO_RDS=$(terraform -chdir=infrastructure/environments/tokyo output -raw rds_endpoint)
echo "Expected: $TOKYO_RDS"

# Ansible로 PHZ를 Tokyo endpoint로 업데이트
make phz-tokyo-auto
```

#### ❌ DNS 캐시로 인한 지연
```
# Pod 내에서 아직 이전 endpoint로 해석됨
```
**원인**: DNS TTL 캐시 (기본 300초)

**해결**:
```bash
# TTL 확인
aws route53 list-resource-record-sets \
  --hosted-zone-id $PHZ_ZONE_ID \
  --query "ResourceRecordSets[?Name=='db.ticket-hs.internal.'].TTL"

# Pod 재시작으로 DNS 캐시 초기화
kubectl -n test-app rollout restart deployment nginx

# CoreDNS 캐시 비우기 (모든 Pod에 영향)
kubectl -n kube-system rollout restart deployment coredns

# 또는 새 Pod로 테스트
kubectl run dns-test --rm -it --image=busybox -- nslookup db.ticket-hs.internal
```

#### ❌ 여러 VPC에서 동일 PHZ 접근 필요
**원인**: PHZ는 연결된 VPC에서만 접근 가능

**해결**:
```bash
# PHZ에 VPC 연결 추가
aws route53 associate-vpc-with-hosted-zone \
  --hosted-zone-id $PHZ_ZONE_ID \
  --vpc VPCRegion=ap-northeast-1,VPCId=<vpc-id>

# 연결된 VPC 목록 확인
aws route53 get-hosted-zone --id $PHZ_ZONE_ID \
  --query 'VPCs'
```

</details>

---

## 전체 DR Failover 테스트

자동화된 전체 DR 테스트:
```bash
cd eks/dh/ansible
make dr-test
```

이 명령은 자동으로:
1. Seoul에 테스트 앱 배포
2. Velero 백업 생성
3. S3 복제 대기
4. Tokyo에서 복구
5. 검증
6. 정리

<details>
<summary>🔧 DR 테스트 트러블슈팅</summary>

#### ❌ dr-test 실패 - 중간 단계에서 멈춤
```
TASK [Wait for S3 replication] *******
(stuck)
```
**해결**:
```bash
# Ctrl+C로 중단 후 상태 확인
velero backup get
velero restore get

# 수동으로 각 단계 실행
make seoul-backup NAME=dr-test-manual
# S3 복제 대기
make tokyo-restore BACKUP=dr-test-manual

# 정리
kubectl delete namespace dr-test
velero backup delete dr-test-manual --confirm
```

#### ❌ 자동 정리 실패
**해결**:
```bash
# 수동 정리
kubectl delete namespace dr-test --context seoul
kubectl delete namespace dr-test --context tokyo
velero backup delete dr-test-* --confirm
```

</details>

---

## 정리

### 테스트 앱 정리
```bash
# Seoul
aws eks update-kubeconfig --region ap-northeast-2 --name ticket-hs-cluster
kubectl delete namespace test-app

# Tokyo
aws eks update-kubeconfig --region ap-northeast-1 --name ticket-hs-cluster
kubectl delete namespace test-app
```

### Velero 백업 정리
```bash
velero backup delete migration-test --confirm
```

### Velero 완전 삭제
```bash
cd eks/dh/ansible
make uninstall
```

---

## 명령어 Quick Reference

| 작업 | 명령어 |
|------|--------|
| Velero 동시 설치 | `make install` |
| Seoul 백업 | `make seoul-backup NAME=xxx` |
| Tokyo 복구 | `make tokyo-restore BACKUP=xxx` |
| DR Failover | `make dr-failover BACKUP=xxx` |
| PHZ 확인 | `make phz-verify` |
| PHZ Tokyo 전환 | `make phz-tokyo` |
| PHZ Seoul 롤백 | `make phz-seoul` |
| 전체 DR 테스트 | `make dr-test` |
| Velero 삭제 | `make uninstall` |

---

## 긴급 상황 체크리스트

### 🚨 Seoul 리전 완전 장애 시

1. **Tokyo 클러스터 확인**
   ```bash
   aws eks update-kubeconfig --region ap-northeast-1 --name ticket-hs-cluster
   kubectl get nodes
   ```

2. **최신 백업 확인**
   ```bash
   velero backup get --sort-by=created
   ```

3. **DR Failover 실행**
   ```bash
   make dr-failover-auto BACKUP=<latest-backup-name>
   ```

4. **애플리케이션 상태 확인**
   ```bash
   kubectl get pods -A | grep -v Running
   ```

5. **외부 DNS 업데이트** (Route53 Public Zone 등)
   - Tokyo ALB/NLB endpoint로 변경

6. **모니터링 알림 업데이트**
   - Tokyo 클러스터 대상으로 변경

### 🔄 Seoul 복구 후 롤백

1. **Seoul 클러스터 상태 확인**
2. **Tokyo에서 Seoul로 역방향 백업/복구**
3. **PHZ를 Seoul로 롤백**
   ```bash
   make phz-seoul
   ```
4. **외부 DNS 원복**
