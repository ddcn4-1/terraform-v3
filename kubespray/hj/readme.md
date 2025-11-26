# K3d 기반 로컬 테스트 환경 구축 문서

## 0. 문서 메타 정보
- 문서명: K3d 기반 로컬 Kubernetes 테스트 환경 구성
- 버전 / 작성일: v1 / 2025.11.27
- 작성자: 윤효정
- 목차
    1. Overview
    2. 아키텍처 & Flow
    3. Requirements
    4. 소스 코드 / 레포지토리 구조
    5. Setup & Installation
    6. Troubleshooting
    7. Appendix

## 1. Overview (개요)
### 목표
- K3d를 활용하여 로컬 개발 환경에서 실제 프로덕션과 유사한 Kubernetes 환경을 구성
- Backend/Frontend 애플리케이션을 로컬 Kubernetes에서 테스트
- Core/Queue 두 개의 네임스페이스 기반 멀티 모듈 서비스 로컬 실행
- AWS 클라우드 의존성(Cognito, S3 등)을 로컬 ConfigMap/Secret으로 대체하여 독립적인 개발 환경 제공
- TLS 및 Ingress 기반 도메인 라우팅(local.ddcn41.com) 재현
- Docker Local Registry + K3d 조합으로 build → push → deploy 흐름을 빠르게 검증

### 실사용 영상
추가 예정

## 2. 아키텍처 & Flow
### 파이프라인 흐름
1. 개발자가 Backend/Frontend 코드를 수정하여 Docker 이미지를 로컬에서 빌드
2. 로컬 Docker Registry(localhost:5001)에 push
3. K3d 클러스터가 해당 Registry를 imagePullSource로 사용
4. Helm/Kustomize로 Core/Queue 네임스페이스 기반 서비스 배포
5. Ingress Controller를 통해 local.ddcn41.com으로 접근
6. 실제 프로덕션과 거의 동일한 환경에서 기능 테스트 수행 가능

### 아키텍처 다이어그램
k3d cluster + local registry 구조
backend/frontend 이미지 build → tag → push → deploy 구조
Core / Queue 네임스페이스 구조도
ingress(local.ddcn41.com) → TLS termination 흐름

## 3. Requirements (사전 준비 사항)
### 1) 로컬 ConfigMap/Secret 구성
- v2 기준으로 Cognito, S3, Redis, PostgreSQL 등 외부 리소스와 연결되어 있음
- 그러므로 로컬 테스트 환경에서는 K3d 내부에서 이를 대체하기 위해 ConfigMap/Secret을 별도로 구성해야 한다.


위치 :
```
kubespray/hj/env-local/k8s/core/config
kubespray/hj/env-local/k8s/queue/config
```

- queue 네임스페이스 구성
    - core와 동일한 설정을 사용하되 namespace만 queue로 변경한다.

core-configMap.yaml (예)
```
apiVersion: v1
kind: ConfigMap
metadata:
    name: ticketing-auth-config
    namespace: core
data:
    COGNITO_USER_POOL_ID: <로컬 환경 테스트용 값>
    COGNITO_CLIENT_ID: <로컬 환경 테스트용 값>
    COGNITO_REGION: <로컬 값>
    AWS_REGION: <로컬 값>
    S3_BUCKET: <로컬 값>
```

core-secret.yaml (예)
```
apiVersion: v1
kind: Secret
metadata:
    name: ticketing-db-redis
    namespace: core
type: Opaque
stringData:
    DB_URL: jdbc:postgresql://postgresql.core.svc.cluster.local:5432/ticket
    DB_USERNAME: ticket
    DB_PASSWORD: ticketpass
    REDIS_HOST: redis-master.redis.svc.cluster.local
    REDIS_PORT: "6379"

```

### 2) 필요 도구 설치

```
brew install k3d kubectl helm
```
- k3d는 lightweight Kubernetes이며 Docker daemon 위에서 클러스터를 구성한다.
- 로컬 Registry를 함께 구성하면 이미지 push 후 즉시 K3d가 pull할 수 있어 로컬 개발 속도가 크게 향상된다.

## 4. 소스 코드 / 레포지토리 구조

### 레포지토리 구조
```
└── k8s
    ├── core
    │   ├── backend
    │   │   ├── core-admin-deployment.yaml
    │   │   ├── core-admin-service.yaml
    │   │   ├── core-deployment.yaml
    │   │   ├── core-ingress.yaml
    │   │   └── core-service.yaml
    │   ├── config
    │   │   ├── core-configMap.yaml
    │   │   └── core-secret.yaml
    │   └── frontend
    ├── deploy-local.sh
    ├── queue
    │   ├── backend
    │   └── config
    └── tls
```
- core/backend, queue/backend
    - Backend 서비스 Deployment/Service/Ingress 정의
- core/frontend
    - Frontend 서비스 Deployment 및 Ingress 정의
- config/
    - Cognito, DB, Redis 등 runtime 환경 변수 제공
- deploy-local.sh
    - 모든 core/queue/backend/frontend 리소스를 한번에 K3d 클러스터로 배포
- tls/
    - local.ddcn41.com 도메인용 self-signed TLS 인증서
    - K3d Ingress Controller에 TLS 적용 시 필요

## 5. Setup & Installation

### Step 1. Local Docker Registry 생성
```
k3d registry create local-registry --port 5001
```

생성 여부 확인 : `k3d registry list`


### Step 2. Backend Docker 이미지 빌드 및 Push
[backend-v3](https://github.com/ddcn4-1/backend-v3) 레포지토리 루트에서 아래 명령 수행

(1) Gradle 빌드 (테스트 제외)
`./gradlew build -x test`

(2) Docker 이미지 빌드

```
    docker build -t ticketing-api:latest -f module-api/Dockerfile .
    docker build -t ticketing-admin:latest -f module-api-admin/Dockerfile .
    docker build -t ticketing-queue:latest -f module-queue/Dockerfile .
```

(3) 로컬 레지스트리에 태깅 및 Push

```
    docker tag ticketing-api:latest localhost:5001/ticketing-api:latest
    docker tag ticketing-admin:latest localhost:5001/ticketing-admin:latest
    docker tag ticketing-queue:latest localhost:5001/ticketing-queue:latest

    docker push localhost:5001/ticketing-api:latest
    docker push localhost:5001/ticketing-admin:latest
    docker push localhost:5001/ticketing-queue:latest
```

### Step 3. Frontend 이미지 빌드 및 Push

[frontend-v3](https://github.com/ddcn4-1/frontend-v3/tree/main) 레포지토리 루트에서 실행

```
docker build -t ticketing-client:latest -f Dockerfile .

docker tag ticketing-client:latest localhost:5001/ticketing-client:latest

docker push localhost:5001/ticketing-client:latest
```

### Step 4. k3d 클러스터 구성

준비해 둔 스크립트로 k3d 클러스터 및 관련 Helm 리소스를 설치

> Namespace, Ingress, Loki, Prometheus, Redis, MinIO, PostgreSQL 등을 자동 설치

```
chmod +x setup-ticketing.sh
./setup-ticketing.sh
```


### Step 5. 애플리케이션 리소스 설치
Backend/Frontend 애플리케이션에 대한 Kubernetes Deployment, Service, Ingress 등을 설치합니다.
```
chmod +x deploy-local.sh
./deploy-local.sh
```


## 6. Troubleshooting
### 1) 이미지 Pull 실패 (ImagePullBackOff)

확인: 
- 이미지 태그가 local registry와 일치하는가?
- K3d cluster가 registry를 trust하도록 설정했는가?

### 2) DNS/Ingress 접근 불가
확인:
- local.ddcn41.com이 /etc/hosts에 등록되어 있는가?
- 127.0.0.1   local.ddcn41.com
- TLS 설정이 k3d ingress controller에 적용되었는가?

### 3) Backend 애플리케이션 DB 연결 실패
확인:
- DB_URL, DB_PASSWORD 등의 Secret 값이 올바른가?
- PostgreSQL/Redis가 k3d 내부에서 정상 실행 중인지?

### 4) ConfigMap 변경이 반영되지 않음
- 원인: Deployment가 자동으로 재시작되지 않기 때문
- 해결: kubectl rollout restart deployment <name> -n core

## 7. Appendix
### 관련 링크
- K3d 공식 문서: https://k3d.io
- Kubernetes 공식 문서
- Helm 공식 문서
- Kustomize 공식 문서

### 용어 설명
- K3d: Docker 위에서 실행되는 경량 Kubernetes 클러스터
- Local Registry: 로컬 PC에서 Docker 이미지를 저장하는 private registry
- Ingress: 외부에서 서비스로 트래픽을 라우팅하는 Kubernetes 리소스
- TLS: HTTPS 트래픽을 위한 인증서 기반 보안
