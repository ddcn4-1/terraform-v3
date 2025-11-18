# KubeSpray-hj 폴더 구조 및 테스트 가이드

## env-local

Ticketing 서비스 로컬 Kubernetes(k3d) 환경 구성 가이드

### 0. 사전 준비 사항

kubespray/hj/env-local/k8s/core/config
하단에 core-configMap.yaml, core-secret.yaml 추가

kubespray/hj/env-local/k8s/queue/config
하단에 queue-configMap.yaml, queue-secret.yaml 추가

### 1. 필수 CLI 도구 설치

```
brew install k3d kubectl helm
```

### 2. k3d 로컬 Docker Registry 생성

`k3d registry create local-registry --port 5001`

생성 여부 확인 : `k3d registry list`

### 3. Backend Docker 이미지 빌드 및 레지스트리 Push

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

### 4. Frontend Docker 이미지 빌드 및 Push

[frontend-v3](https://github.com/ddcn4-1/frontend-v3/tree/main) 레포지토리 루트에서 실행

```
docker build -t ticketing-client:latest -f Dockerfile .

docker tag ticketing-client:latest localhost:5001/ticketing-client:latest

docker push localhost:5001/ticketing-client:latest
```

### 5. k3d 클러스터 구성

준비해 둔 스크립트로 k3d 클러스터 및 관련 Helm 리소스를 설치합니다.

> Namespace, Ingress, Loki, Prometheus, Redis, MinIO, PostgreSQL 등을 자동 설치

```
chmod +x setup-ticketing.sh
./setup-ticketing.sh
```

### 6. 어플리케이션 리소스 설치

Backend/Frontend 애플리케이션에 대한 Kubernetes Deployment, Service, Ingress 등을 설치합니다.

```
chmod +x deploy-local.sh
./deploy-local.sh
```
