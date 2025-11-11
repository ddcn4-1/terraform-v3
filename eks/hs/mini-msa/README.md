# Mini MSA 

큐 서비스와 코어 서비스를 포함한 미니 마이크로서비스 아키텍처로, Docker Compose와 Kubernetes(Docker Desktop, EKS) 환경을 고려하여 구성하였습니다.

## 📋 목차

- [아키텍처](#아키텍처)
- [주요 기능](#주요-기능)
- [빠른 시작](#빠른-시작)
  - [Docker Compose로 시작](#docker-compose로-시작)
  - [Kubernetes로 시작](#kubernetes로-시작)
- [프로젝트 구조](#프로젝트-구조)
- [API 엔드포인트](#api-엔드포인트)
- [환경 변수](#환경-변수)
- [데이터베이스 관리](#데이터베이스-관리)
- [Kubernetes 배포](#kubernetes-배포)
- [린팅 및 품질 관리](#린팅-및-품질-관리)
- [보안 관리](#보안-관리)
- [모니터링 및 로깅](#모니터링-및-로깅)
- [문제 해결](#문제-해결)
- [프로덕션 고려사항](#프로덕션-고려사항)
- [참고 자료](#참고-자료)

---

## 아키텍처

### 시스템 구성

```
┌──────────────┐         ┌─────────────┐
│  PostgreSQL  │         │    Redis    │
│    :5432     │         │    :6379    │
└──────┬───────┘         └──────┬──────┘
       │                        │
       ├────────────┬───────────┤
       │            │           │
┌──────▼──────┐    │    ┌──────▼──────┐
│Queue Service│ ◄──┴───►│Core Service │
│    :3001    │         │    :3002    │
└─────────────┘         └─────────────┘
    내부 통신              외부 진입점
```

### 마이크로서비스 패턴

이 프로젝트는 다음의 검증된 마이크로서비스 패턴을 구현합니다:

1. **서비스 간 통신 패턴** (Inter-Service Communication)
   - HTTP REST API 기반 동기 통신
   - [참고: Martin Fowler - Microservices Resource Guide](https://martinfowler.com/microservices/)

2. **작업 큐 패턴** (Job Queue Pattern)
   - 비동기 작업 처리를 위한 데이터베이스 기반 큐
   - 우선순위 기반 작업 스케줄링
   - [참고: Enterprise Integration Patterns - Message Queue](https://www.enterpriseintegrationpatterns.com/patterns/messaging/MessageQueue.html)

3. **데이터베이스 분리 패턴** (Database per Service)
   - 각 서비스가 독립적인 데이터 스키마 소유
   - [참고: Microservices.io - Database per Service](https://microservices.io/patterns/data/database-per-service.html)

4. **헬스 체크 패턴** (Health Check Pattern)
   - 서비스 가용성 모니터링
   - Kubernetes Liveness/Readiness Probe 지원

---

## 주요 기능

### 현재 구현된 기능

-  **마이크로서비스 아키텍처**
    - 서비스 간 HTTP 통신
    - 독립적인 배포 및 확장

- **데이터 지속성**
    - PostgreSQL: 관계형 데이터 저장
    - Redis: 캐싱 및 세션 관리
    - 영구 볼륨을 통한 데이터 보존

- **컨테이너화**
    - Docker 멀티 스테이지 빌드
    - 최적화된 이미지 크기
    - 프로덕션 준비된 Dockerfile

- **오케스트레이션**
    - Docker Compose: 로컬 개발 환경
    - Kubernetes: 프로덕션 배포
    - kubectl 기반 매니페스트 관리

- **린팅 및 코드 품질**
    - 린팅 도구 통합 (yamllint, kube-linter, hadolint, shellcheck)
    - 베스트 프랙티스 검증
    - 헬스 체크 엔드포인트

- **보안**
    - Kubernetes Secrets 관리 (로컬 개발)
    - 네임스페이스 분리를 통한 보안 경계

---

## 빠른 시작

### Docker Compose로 시작

#### 전제 조건
- Docker Desktop 또는 Docker Engine
- Docker Compose v2.x+
- Make (선택사항)

#### 1단계: 프로젝트 클론

```bash
git clone <repository-url>
cd mini-msa
```

#### 2단계: 서비스 시작

```bash
# Makefile 사용 (권장)
make start

# 또는 Docker Compose 직접 사용
docker-compose up --build -d
```

#### 3단계: 헬스 체크

```bash
# Makefile 사용
make health

# 또는 curl 직접 사용
curl http://127.0.0.1:3001/health  # Queue Service
curl http://127.0.0.1:3002/health  # Core Service
```

#### 4단계: 통합 테스트 실행

```bash
make test
```

---

### Kubernetes로 시작

#### 옵션 1: Docker Desktop (권장 - 로컬 개발)

**전제 조건**:
- Docker Desktop with Kubernetes enabled
- kubectl CLI

**설정 단계**:

1. **Kubernetes 활성화**
   ```
   Docker Desktop → Settings → Kubernetes
   ✓ Enable Kubernetes
   → Apply & Restart
   ```

2. **확인**
   ```bash
   kubectl config current-context
   # 출력: docker-desktop

   kubectl get nodes
   # 출력: docker-desktop   Ready    control-plane   ...
   ```

3. **자동 배포**
   ```bash
   cd mini-msa
   make k8s-setup
   ```

4. **접근**
   ```bash
   # NodePort로 접근
   curl http://127.0.0.1:30002/health

   # 또는 Port Forward
   make k8s-port-forward
   # 다른 터미널에서: curl http://127.0.0.1:3002/health
   ```

---


## 프로젝트 구조

```
mini-msa/
├── docker-compose.yml              # Docker Compose 오케스트레이션
├── Makefile                        # 빌드 및 테스트 자동화
├── .env.example                    # 환경 변수 템플릿
│
├── scripts/                        # 자동화 스크립트
│   ├── init-db.sql                 # PostgreSQL 초기화
│   ├── test.sh                     # Docker Compose 통합 테스트
│   ├── k8s-setup.sh                # Kubernetes 자동 설정
│   ├── k8s-test.sh                 # Kubernetes 통합 테스트
│   ├── k8s-cleanup.sh              # Kubernetes 리소스 정리
│   └── lint-all.sh                 # 전체 린팅 실행
│
├── queue-service/                  # Queue 마이크로서비스
│   ├── Dockerfile                  # 멀티 스테이지 빌드
│   ├── package.json                # Node.js 의존성
│   ├── .env                        # 환경 변수
│   └── index.js                    # 서비스 구현
│
├── core-service/                   # Core 마이크로서비스
│   ├── Dockerfile                  # 멀티 스테이지 빌드
│   ├── package.json                # Node.js 의존성
│   ├── .env                        # 환경 변수
│   └── index.js                    # 서비스 구현
│
├── k8s/                            # Kubernetes 매니페스트
│   └── base/                       # 기본 리소스
│       ├── namespace-app.yaml      # 애플리케이션 네임스페이스
│       ├── namespace-data.yaml     # 데이터 네임스페이스
│       ├── shared-secrets.yaml     # 공유 시크릿
│       ├── postgres/               # PostgreSQL StatefulSet
│       ├── redis/                  # Redis StatefulSet
│       ├── queue-service/          # Queue Service Deployment
│       └── core-service/           # Core Service Deployment
│
├── .kube-linter.yaml               # Kubernetes 린팅 설정
└── .yamllint                       # YAML 린팅 설정
```

---

## API 엔드포인트

### Queue Service (내부 - 포트 3001)

| 메서드 | 엔드포인트 | 설명 |
|--------|----------|-------------|
| GET | `/health` | 헬스 체크 (PostgreSQL, Redis 연결 확인) |
| GET | `/api/queue` | 큐의 모든 작업 조회 |
| POST | `/api/queue` | 큐에 작업 추가 |
| POST | `/api/queue/process` | 다음 우선순위 작업 처리 |
| GET | `/api/queue/:id` | ID로 특정 작업 조회 |
| DELETE | `/api/queue` | 모든 작업 삭제 (개발용) |

### Core Service (외부 - 포트 3002)

| 메서드 | 엔드포인트 | 설명 |
|--------|----------|-------------|
| GET | `/health` | 헬스 체크 (Queue Service 연결 확인) |
| GET | `/api/check-queue` | Queue Service 상태 확인 |
| GET | `/api/jobs` | 큐에서 모든 작업 조회 (프록시) |
| POST | `/api/jobs` | 작업 생성 및 큐로 전송 |
| POST | `/api/jobs/process` | 작업 처리 트리거 (프록시) |
| POST | `/api/users` | 사용자 생성 (환영 이메일 작업 자동 생성) |

---

## 환경 변수

### PostgreSQL 설정

```bash
POSTGRES_HOST=postgres          # Docker Compose: postgres, K8s: postgres-service
POSTGRES_PORT=5432
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin123
POSTGRES_DB=mini_msa
```

### Redis 설정

```bash
REDIS_HOST=redis                # Docker Compose: redis, K8s: redis-service
REDIS_PORT=6379
REDIS_PASSWORD=redis123
```

### Queue Service 설정

```bash
PORT=3001
SERVICE_NAME=queue-service
NODE_ENV=development
CORE_SERVICE_URL=http://core-service:3002
```

### Core Service 설정

```bash
PORT=3002
SERVICE_NAME=core-service
NODE_ENV=development
QUEUE_SERVICE_URL=http://queue-service:3001
```

**보안 주의사항**: 프로덕션 환경에서는 `.env` 파일 대신 Kubernetes Secrets 또는 AWS Secrets Manager를 사용하세요.

---

## 데이터베이스 관리

### PostgreSQL 관리

#### 데이터베이스 스키마

프로젝트는 다음 테이블을 자동으로 생성합니다 (`scripts/init-db.sql`):

- **users**: 사용자 정보
  - `id`: Primary Key (SERIAL)
  - `username`: VARCHAR(50) UNIQUE NOT NULL
  - `email`: VARCHAR(100) UNIQUE NOT NULL
  - `created_at`, `updated_at`: TIMESTAMP

- **tasks**: 작업 관리
  - `id`: Primary Key (SERIAL)
  - `user_id`: Foreign Key → users(id)
  - `title`: VARCHAR(200) NOT NULL
  - `description`: TEXT
  - `status`: VARCHAR(20) DEFAULT 'pending'
  - `priority`: VARCHAR(20) DEFAULT 'normal'
  - `created_at`, `updated_at`: TIMESTAMP

- **queue_items**: 큐 처리
  - `id`: Primary Key (SERIAL)
  - `task_id`: Foreign Key → tasks(id)
  - `payload`: JSON NOT NULL
  - `status`: VARCHAR(20) DEFAULT 'pending'
  - `attempts`: INTEGER DEFAULT 0
  - `created_at`, `updated_at`: TIMESTAMP

#### PostgreSQL 접근

```bash
# Docker Compose 환경
docker exec -it postgres psql -U admin -d mini_msa

# Kubernetes 환경
kubectl exec -it -n mini-msa-data postgres-0 -- psql -U admin -d mini_msa

# Makefile 사용 (Kubernetes)
make k8s-shell-postgres
```

#### 일반적인 쿼리

```sql
-- 모든 테이블 조회
\dt

-- 사용자 조회
SELECT * FROM users;

-- 작업 조회 (최근 10개)
SELECT * FROM tasks ORDER BY created_at DESC LIMIT 10;

-- 큐 상태 조회
SELECT status, COUNT(*) FROM queue_items GROUP BY status;
```

### Redis 관리

#### Redis 접근

```bash
# Docker Compose 환경
docker exec -it redis redis-cli -a redis123

# Kubernetes 환경
kubectl exec -it -n mini-msa-data redis-0 -- redis-cli -a redis123

# Makefile 사용 (Kubernetes)
make k8s-shell-redis
```

#### 일반적인 명령어

```bash
# 연결 테스트
PING
# 응답: PONG

# 모든 키 조회
KEYS *

# 특정 키 조회
GET session:user:123

# 키 삭제
DEL session:user:123

# 캐시 플러시 (주의!)
FLUSHALL
```

**참고**: [Redis 공식 문서 - Commands](https://redis.io/commands/)

---

## Kubernetes 배포

### 네임스페이스 구조

프로젝트는 네임스페이스 분리 원칙을 따릅니다:

- **mini-msa-app**: 애플리케이션 서비스 (queue-service, core-service)
- **mini-msa-data**: 데이터 레이어 (postgres, redis)

**이점**:
- 보안 경계 분리
- 리소스 할당량 관리
- RBAC 세분화
- 네트워크 정책 적용 용이

**참고**: [Kubernetes 공식 문서 - Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)

### Makefile 명령어

#### 배포 관련

```bash
make k8s-setup           # 전체 셋업 (최초 1회, NGINX Ingress 포함)
make k8s-deploy          # 애플리케이션 재배포
make k8s-test            # 통합 테스트 실행
make k8s-restart         # Pod 재시작
make k8s-clean           # 모든 리소스 삭제 (확인 포함)
make k8s-clean-force     # 모든 리소스 삭제 (확인 없음)
make k8s-clean-all       # 리소스 + Docker 이미지 삭제
```

#### 모니터링 관련

```bash
make k8s-status          # 모든 리소스 상태 확인
make k8s-logs            # 모든 Pod 로그 조회
make k8s-logs-core       # Core Service 로그 팔로우
make k8s-logs-queue      # Queue Service 로그 팔로우
make k8s-port-forward    # 로컬 포트 포워딩 (3002)
```

#### 디버깅 관련

```bash
make k8s-describe-core   # Core Service Pod 상세 정보
make k8s-describe-queue  # Queue Service Pod 상세 정보
make k8s-shell-core      # Core Service Pod 셸 접근
make k8s-shell-queue     # Queue Service Pod 셸 접근
make k8s-shell-postgres  # PostgreSQL 셸 (psql)
make k8s-shell-redis     # Redis CLI
```

### 리소스 구성

#### StatefulSets

**PostgreSQL**:
- 이미지: `postgres:16-alpine`
- 레플리카: 1
- 스토리지: 10Gi PVC (ReadWriteOnce)
- 리소스: 256Mi-512Mi memory, 250m-500m CPU
- 헬스체크: `pg_isready` 명령

**Redis**:
- 이미지: `redis:7-alpine`
- 레플리카: 1
- 스토리지: 5Gi PVC (ReadWriteOnce)
- 리소스: 128Mi-256Mi memory, 100m-200m CPU
- 헬스체크: `redis-cli ping`
- 지속성: AOF (Append-Only File) 활성화

**참고**: [Kubernetes 공식 문서 - StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)

#### Deployments

**Queue Service & Core Service**:
- 레플리카: 2 (고가용성)
- 리소스: 128Mi-256Mi memory, 100m-200m CPU
- 롤링 업데이트: 25% maxUnavailable, 25% maxSurge
- InitContainers: 의존성 서비스 준비 대기 (busybox + nc)
- 헬스체크:
  - Startup Probe: 120초 타임아웃 (초기 부팅)
  - Liveness Probe: 60초 딜레이, 30초 주기
  - Readiness Probe: 30초 딜레이, 10초 주기

**참고**: [Kubernetes 공식 문서 - Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)

#### Services

| 서비스 | 타입 | 포트 | 설명 |
|--------|------|------|------|
| postgres-service | ClusterIP | 5432 | 내부 PostgreSQL 접근 |
| redis-service | ClusterIP | 6379 | 내부 Redis 접근 |
| queue-service | ClusterIP | 3001 | 내부 Queue 서비스 |
| core-service | NodePort | 3002 (NodePort: 30002) | 외부 접근 가능 |

**참고**: [Kubernetes 공식 문서 - Services](https://kubernetes.io/docs/concepts/services-networking/service/)

#### Ingress

- **호스트**: `mini-msa.local` (로컬), ALB (EKS)
- **Ingress Class**: nginx (로컬), alb (EKS)
- **백엔드**: core-service:3002
- **TLS**: 지원 (인증서 설정 필요)

**참고**: [Kubernetes 공식 문서 - Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)

---

## 린팅 및 품질 관리

### 설치된 린팅 도구

1. **yamllint**: YAML 문법 및 스타일 검사
2. **kube-linter**: Kubernetes 매니페스트 보안 및 베스트 프랙티스 검증
3. **hadolint**: Dockerfile 베스트 프랙티스 검증
4. **shellcheck**: Shell 스크립트 정적 분석
5. **helm lint**: Helm Chart 유효성 검증

### 린팅 실행

```bash
# 전체 린팅 (권장)
make lint
# 또는
./scripts/lint-all.sh

# 개별 도구 실행
make lint-yaml       # YAML 파일 검사
make lint-k8s        # Kubernetes 매니페스트 검사
make lint-docker     # Dockerfile 검사
make lint-shell      # Shell 스크립트 검사
make lint-helm       # Helm Chart 검사
```

### 주요 보안 체크 항목

#### 1. runAsNonRoot (Critical 🔴)
```yaml
containers:
- name: app
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
```

**이유**: root 사용자로 실행 시 컨테이너 탈출 공격에 취약합니다.

**참고**: [CIS Kubernetes Benchmark - 5.2.6 Minimize the admission of root containers](https://www.cisecurity.org/benchmark/kubernetes)

#### 2. readOnlyRootFilesystem (Critical 🔴)
```yaml
containers:
- name: app
  securityContext:
    readOnlyRootFilesystem: true
  volumeMounts:
  - name: tmp
    mountPath: /tmp
volumes:
- name: tmp
  emptyDir: {}
```

**이유**: 파일 시스템 변조 공격을 방지합니다.

**참고**: [OWASP Kubernetes Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html)


---

## 보안 관리

### 로컬 개발 환경

로컬 개발에서는 Kubernetes Secrets를 직접 관리합니다:

```bash
# 시크릿 생성 (base64 인코딩)
kubectl create secret generic postgres-secret \
  --from-literal=POSTGRES_USER=admin \
  --from-literal=POSTGRES_PASSWORD=admin123 \
  --from-literal=POSTGRES_DB=mini_msa \
  -n mini-msa-data
```

### EKS 프로덕션 환경 (향후 구현 예정)

프로덕션 환경에서는 다음의 시크릿 관리 방식을 고려하고 있습니다:

#### 검토 중: External Secrets Operator (ESO) + AWS Secrets Manager

External Secrets Operator는 EKS 환경에서 **업계 표준**입니다:

1.  **AWS 네이티브 통합**: Secrets Manager, Parameter Store 완벽 지원
2.  **IRSA 지원**: IAM Roles for Service Accounts로 인증
3.  **자동 로테이션**: 설정 가능한 동기화 주기 (기본 1시간)
4.  **크로스 네임스페이스**: ClusterSecretStore로 네임스페이스 간 시크릿 공유
5.  **GitOps 친화적**: 선언적 YAML 설정
6.  **감사 추적**: CloudTrail 통합
7.  **비용 효율적**: 일반적인 설정에서 월 $1 미만

**참고**:
- [AWS 공식 가이드 - Use AWS Secrets Manager secrets with Amazon EKS Pods](https://docs.aws.amazon.com/eks/latest/userguide/manage-secrets.html)
- [EKS Workshop - External Secrets Operator](https://www.eksworkshop.com/docs/security/secrets-management/secrets-manager/external-secrets)

자세한 구현 가이드: [k8s/SECRET-MANAGEMENT-EKS.md](k8s/SECRET-MANAGEMENT-EKS.md)

---

## 모니터링 및 로깅

### Prometheus + Grafana 설치

```bash
# Helm 레포지토리 추가
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# kube-prometheus-stack 설치
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Grafana 접근
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# 브라우저: http://localhost:3000
# 기본 계정: admin / prom-operator
```

**참고**:
- [Prometheus Operator Documentation](https://prometheus-operator.dev/)
- [Grafana Kubernetes Monitoring](https://grafana.com/grafana/dashboards/315-kubernetes-cluster-monitoring/)

### ELK Stack (Elasticsearch, Logstash, Kibana) - 향후 구현 예정

```bash
# Elastic Operator 설치 (계획)
kubectl create -f https://download.elastic.co/downloads/eck/2.10.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.10.0/operator.yaml
```

**참고**: [Elastic Cloud on Kubernetes](https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html)

---

## 문제 해결

### Docker Compose 환경

#### 서비스가 시작하지 않는 경우

```bash
# 로그 확인
docker-compose logs queue-service
docker-compose logs core-service

# 컨테이너 상태 확인
docker-compose ps

# 네트워크 확인
docker network inspect mini-msa_msa-network

# 포트 충돌 확인
lsof -i :3001
lsof -i :3002
lsof -i :5432
lsof -i :6379
```

#### 데이터베이스 연결 실패

```bash
# PostgreSQL 연결 확인
docker exec postgres pg_isready -U admin -d mini_msa

# Redis 연결 확인
docker exec redis redis-cli -a redis123 ping

# 네트워크 연결 테스트
docker exec core-service ping postgres
docker exec core-service ping redis
```

### Kubernetes 환경

#### Pod가 시작하지 않는 경우

```bash
# Pod 상태 확인
kubectl get pods -n mini-msa-app
kubectl get pods -n mini-msa-data

# Pod 이벤트 확인
kubectl describe pod <pod-name> -n mini-msa-app

# 로그 확인
kubectl logs <pod-name> -n mini-msa-app

# 이전 로그 (재시작한 경우)
kubectl logs <pod-name> -n mini-msa-app --previous
```

#### 이미지 Pull 실패

```bash
# Docker Desktop의 경우
# 이미지가 로컬 Docker 데몬에 있는지 확인
docker images | grep -E "queue-service|core-service"

# 이미지 재빌드
make k8s-deploy

# imagePullPolicy 확인
kubectl get deployment queue-service -n mini-msa-app -o yaml | grep imagePullPolicy
# IfNotPresent로 설정되어야 함
```

#### PVC Pending 상태

```bash
# PVC 상태 확인
kubectl get pvc -n mini-msa-data

# StorageClass 확인
kubectl get storageclass

# PVC 상세 정보
kubectl describe pvc postgres-data-postgres-0 -n mini-msa-data

# Docker Desktop은 hostpath provisioner 기본 제공
```

#### Ingress 작동 불가

```bash
# Ingress Controller 확인
kubectl get pods -n ingress-nginx

# Ingress 상세 정보
kubectl describe ingress core-service-ingress -n mini-msa-app

# Ingress Controller 로그
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# /etc/hosts 설정 확인
cat /etc/hosts | grep mini-msa.local
```

---

## 프로덕션 고려사항

### 보안

1. **시크릿 관리**
   -  AWS Secrets Manager + External Secrets Operator 사용
   -  IRSA로 IAM 역할 기반 인증
   -  CloudTrail로 접근 감사

2. **컨테이너 보안**
   -  비root 사용자로 실행 (`runAsNonRoot: true`)
   -  읽기 전용 루트 파일시스템 (`readOnlyRootFilesystem: true`)
   -  Capabilities 제거 (`drop: [ALL]`)
   -  Seccomp 프로필 적용 (`type: RuntimeDefault`)

3. **네트워크 보안**
   - ⚠️ NetworkPolicy 구현 (향후)
   - ⚠️ TLS/mTLS 적용 (향후)
   - ⚠️ Istio/Linkerd 서비스 메시 (향후)

**참고**:
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html)

### 고가용성

1. **Pod Disruption Budget (PDB)**
   ```yaml
   apiVersion: policy/v1
   kind: PodDisruptionBudget
   metadata:
     name: core-service-pdb
   spec:
     minAvailable: 1
     selector:
       matchLabels:
         app: core-service
   ```

2. **Pod Anti-Affinity**
   ```yaml
   affinity:
     podAntiAffinity:
       preferredDuringSchedulingIgnoredDuringExecution:
       - weight: 100
         podAffinityTerm:
           labelSelector:
             matchExpressions:
             - key: app
               operator: In
               values:
               - core-service
           topologyKey: kubernetes.io/hostname
   ```

**참고**: [Kubernetes 공식 문서 - Pod Disruption Budget](https://kubernetes.io/docs/tasks/run-application/configure-pdb/)

### 데이터 지속성

1. **PostgreSQL**
   -  StatefulSet으로 안정적인 네트워크 ID
   -  PersistentVolumeClaim으로 데이터 영속성
   - ⚠️ RDS for PostgreSQL 고려 중 (프로덕션)
   - ⚠️ 자동 백업 및 Point-in-Time Recovery (향후)

2. **Redis**
   -  AOF (Append-Only File) 활성화
   -  PersistentVolumeClaim으로 데이터 영속성
   - ⚠️ ElastiCache for Redis 고려 중 (프로덕션)
   - ⚠️ Redis Cluster 모드 (향후)

**참고**:
- [AWS RDS for PostgreSQL](https://aws.amazon.com/rds/postgresql/)
- [AWS ElastiCache for Redis](https://aws.amazon.com/elasticache/redis/)

### 스케일링

1. **Horizontal Pod Autoscaler (HPA)**
   ```yaml
   apiVersion: autoscaling/v2
   kind: HorizontalPodAutoscaler
   metadata:
     name: core-service-hpa
   spec:
     scaleTargetRef:
       apiVersion: apps/v1
       kind: Deployment
       name: core-service
     minReplicas: 2
     maxReplicas: 10
     metrics:
     - type: Resource
       resource:
         name: cpu
         target:
           type: Utilization
           averageUtilization: 70
   ```

2. **Cluster Autoscaler (EKS)**
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
   ```

**참고**:
- [Kubernetes 공식 문서 - HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [AWS EKS - Cluster Autoscaler](https://docs.aws.amazon.com/eks/latest/userguide/autoscaling.html)

### CI/CD

```yaml
# .github/workflows/deploy-eks.yml
name: Deploy to EKS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-northeast-2

      - name: Build and push to ECR
        run: |
          aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_REGISTRY
          docker build -t queue-service:$GITHUB_SHA ./queue-service
          docker tag queue-service:$GITHUB_SHA $ECR_REGISTRY/queue-service:$GITHUB_SHA
          docker push $ECR_REGISTRY/queue-service:$GITHUB_SHA

      - name: Deploy to EKS
        run: |
          aws eks update-kubeconfig --name mini-msa
          kubectl set image deployment/queue-service queue-service=$ECR_REGISTRY/queue-service:$GITHUB_SHA -n mini-msa-app
          kubectl rollout status deployment/queue-service -n mini-msa-app
```

**참고**: [GitHub Actions - Deploying to Amazon EKS](https://docs.github.com/en/actions/deployment/deploying-to-your-cloud-provider/deploying-to-amazon-elastic-kubernetes-service)

---

## 참고 자료

### 공식 문서

- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [Docker 공식 문서](https://docs.docker.com/)
- [AWS EKS 사용자 가이드](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Helm 공식 문서](https://helm.sh/docs/)

### 마이크로서비스 아키텍처

- [Martin Fowler - Microservices Resource Guide](https://martinfowler.com/microservices/)
- [Microservices.io - Pattern Library](https://microservices.io/patterns/)
- [12 Factor App](https://12factor.net/)
- [Building Microservices (Sam Newman)](https://www.oreilly.com/library/view/building-microservices-2nd/9781492034018/)

### 보안 베스트 프랙티스

- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html)
- [AWS EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [NIST Application Container Security Guide](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf)

### 도구 및 유틸리티

- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Docker Compose 문서](https://docs.docker.com/compose/)
- [External Secrets Operator](https://external-secrets.io/)
- [Prometheus Operator](https://prometheus-operator.dev/)

### 추가 프로젝트 문서

- [Docker Desktop 빠른 시작](DOCKER-DESKTOP-SETUP.md)
- [Kubernetes 전체 배포 가이드](README-k8s.md)
- [린팅 및 품질 관리](LINTING.md)
- [EKS Secret Management](k8s/SECRET-MANAGEMENT-EKS.md)

---

## 라이센스

본 프로젝트는 개발 및 학습 목적으로 제공됩니다.

---

## 기여 및 문의

이슈 및 기여는 GitHub repository를 통해 환영합니다.

**작성일**: 2025년 1월
**작성자**: Mini MSA Project Team
**버전**: 1.0.0
