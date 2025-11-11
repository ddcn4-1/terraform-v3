# Mini MSA 테스트 환경

큐 서비스와 코어 서비스를 포함한 간단한 마이크로서비스 아키텍처로 서비스 간 통신을 테스트합니다.

## 아키텍처

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

## 서비스

### PostgreSQL (포트 5432)
- 주요 관계형 데이터베이스
- 사용자 및 작업 데이터 저장
- 샘플 스키마 사전 구성
- 볼륨을 통한 영구 데이터 저장

### Redis (포트 6379)
- 분산 캐싱 레이어
- 세션 관리
- 실시간 데이터 캐싱
- Pub/Sub 메시징 지원

### Queue Service (포트 3001)
- 메시지 큐 관리
- 작업 처리 및 상태 추적
- 데이터베이스 기반 큐 영속성
- 우선순위 기반 작업 처리

### Core Service (포트 3002)
- 핵심 비즈니스 로직
- 큐 서비스로 작업 전송
- 내부 HTTP 통신
- 사용자 관리 예제

## 프로젝트 구조

```
mini-msa/
├── docker-compose.yml          # Docker 오케스트레이션
├── Makefile                    # 빌드 및 테스트 자동화
├── .env.example                # 환경 변수 예제
├── scripts/
│   ├── init-db.sql             # 데이터베이스 초기화 스크립트
│   └── test.sh                 # 통합 테스트 스크립트
├── queue-service/
│   ├── Dockerfile
│   ├── package.json
│   ├── .env                    # 환경 변수
│   └── index.js                # Queue 서비스 구현
└── core-service/
    ├── Dockerfile
    ├── package.json
    ├── .env                    # 환경 변수
    └── index.js                # Core 서비스 구현
```

## 빠른 시작

### Makefile 사용 (권장)

```bash
cd mini-msa

# 사용 가능한 모든 명령어 보기
make help

# 서비스 빌드 및 시작
make start              # 또는: make build && make up

# 통합 테스트 실행
make test

# 서비스 상태 확인
make health

# 로그 보기
make logs

# 서비스 재시작
make restart

# 서비스 중지
make down

# 모든 것 정리 (컨테이너, 이미지, 볼륨)
make clean

# 전체 재빌드
make rebuild
```

### 사용 가능한 Make 명령어

| 명령어 | 설명 |
|---------|-------------|
| `make help` | 사용 가능한 모든 명령어 표시 |
| `make build` | Docker 이미지 빌드 |
| `make up` | 백그라운드 모드로 서비스 시작 |
| `make down` | 서비스 중지 및 제거 |
| `make restart` | 모든 서비스 재시작 |
| `make logs` | 모든 서비스의 로그 보기 |
| `make test` | 통합 테스트 실행 |
| `make health` | 모든 서비스의 상태 확인 |
| `make ps` | 실행 중인 컨테이너 목록 |
| `make clean` | 컨테이너, 이미지, 볼륨 제거 |
| `make start` | 빠른 시작 (build + up) |
| `make rebuild` | 전체 재빌드 (down + clean + build + up) |

### Docker Compose 직접 사용

```bash
cd mini-msa

# 모든 서비스 빌드 및 실행
docker-compose up --build

# 또는 백그라운드 모드로 실행
docker-compose up -d

# 테스트 스크립트 실행
./scripts/test.sh

# 서비스 중지
docker-compose down
```

## API 엔드포인트

### Queue Service (내부 - 포트 3001)

| 메서드 | 엔드포인트 | 설명 |
|--------|----------|-------------|
| GET | `/health` | 헬스 체크 |
| GET | `/api/queue` | 큐의 모든 작업 조회 |
| POST | `/api/queue` | 큐에 작업 추가 |
| POST | `/api/queue/process` | 다음 작업 처리 |
| GET | `/api/queue/:id` | ID로 작업 조회 |
| DELETE | `/api/queue` | 모든 작업 삭제 |

### Core Service (외부 - 포트 3002)

| 메서드 | 엔드포인트 | 설명 |
|--------|----------|-------------|
| GET | `/health` | 헬스 체크 |
| GET | `/api/check-queue` | 큐 서비스 상태 확인 |
| GET | `/api/jobs` | 큐에서 모든 작업 조회 |
| POST | `/api/jobs` | 작업 생성 및 큐로 전송 |
| POST | `/api/jobs/process` | 작업 처리 트리거 |
| POST | `/api/users` | 사용자 생성 (환영 이메일 작업 트리거) |

## 환경 변수

### 데이터베이스 설정 (.env.example)
```bash
# PostgreSQL
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin123
POSTGRES_DB=mini_msa

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=redis123
```

### Queue Service (.env)
```bash
PORT=3001
SERVICE_NAME=queue-service
CORE_SERVICE_URL=http://core-service:3002
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
REDIS_HOST=redis
REDIS_PORT=6379
```

### Core Service (.env)
```bash
PORT=3002
SERVICE_NAME=core-service
QUEUE_SERVICE_URL=http://queue-service:3001
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
REDIS_HOST=redis
REDIS_PORT=6379
```

## 데이터베이스 관리

### PostgreSQL 접근

```bash
# psql을 사용하여 PostgreSQL 연결
docker exec -it postgres psql -U admin -d mini_msa

# SQL 쿼리 실행
docker exec -it postgres psql -U admin -d mini_msa -c "SELECT * FROM users;"

# 모든 테이블 보기
docker exec -it postgres psql -U admin -d mini_msa -c "\dt"

# 데이터베이스 백업
docker exec postgres pg_dump -U admin mini_msa > backup.sql

# 데이터베이스 복원
docker exec -i postgres psql -U admin mini_msa < backup.sql
```

### Redis 접근

```bash
# Redis CLI 연결
docker exec -it redis redis-cli -a redis123

# Redis 연결 테스트
docker exec -it redis redis-cli -a redis123 ping

# 모든 키 보기
docker exec -it redis redis-cli -a redis123 KEYS '*'

# 특정 키 조회
docker exec -it redis redis-cli -a redis123 GET somekey

# Redis 명령어 실시간 모니터링
docker exec -it redis redis-cli -a redis123 MONITOR
```

### 데이터베이스 스키마

PostgreSQL 데이터베이스는 다음 테이블을 포함합니다:

- **users**: 사용자 정보 (id, username, email, timestamps)
- **tasks**: 작업 관리 (id, user_id, title, description, status, priority, timestamps)
- **queue_items**: 큐 처리 (id, task_id, payload, status, attempts, timestamps)

스키마는 첫 시작 시 `scripts/init-db.sql`에서 자동으로 초기화됩니다.

## 수동 테스트 예제

### 1. 헬스 체크

```bash
# Queue 서비스 헬스
curl http://localhost:3001/health

# Core 서비스 헬스
curl http://localhost:3002/health

# Core 서비스에서 Queue 서비스 확인
curl http://localhost:3002/api/check-queue
```

### 2. 작업 생성

```bash
# 높은 우선순위 작업 생성
curl -X POST http://localhost:3002/api/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "type": "data-processing",
    "data": "important data",
    "priority": "high"
  }'

# 일반 우선순위 작업 생성
curl -X POST http://localhost:3002/api/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "type": "email-send",
    "data": "email content",
    "priority": "normal"
  }'
```

### 3. 작업 조회 및 처리

```bash
# 큐의 모든 작업 조회
curl http://localhost:3002/api/jobs

# 다음 작업 처리
curl -X POST http://localhost:3002/api/jobs/process

# 큐 상태 직접 조회
curl http://localhost:3001/api/queue
```

### 4. 비즈니스 로직 예제

```bash
# 사용자 생성 (자동으로 환영 이메일 큐에 추가)
curl -X POST http://localhost:3002/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "name": "홍길동",
    "email": "hong@example.com"
  }'

# 환영 이메일 작업이 큐에 추가되었는지 확인
curl http://localhost:3001/api/queue
```

### 5. 데이터베이스 테스트

```bash
# 사용자 테이블 조회
docker exec -it postgres psql -U admin -d mini_msa -c "SELECT * FROM users;"

# 작업 테이블 조회
docker exec -it postgres psql -U admin -d mini_msa -c "SELECT * FROM tasks;"

# Redis 캐시 테스트
docker exec -it redis redis-cli -a redis123 SET test_key "test_value"
docker exec -it redis redis-cli -a redis123 GET test_key
```

## 서비스 간 통신

서비스는 내부 Docker 네트워크(`msa-network`)를 사용하여 통신합니다:

- **내부 URL**: 서비스는 내부 호스트명 사용 (예: `http://queue-service:3001`)
- **외부 접근**: 호스트 머신에서 `localhost`를 통해 서비스 접근 가능
- **환경 변수**: 서비스 URL은 `.env` 파일에 설정
- **HTTP 클라이언트**: Core 서비스는 Queue 서비스로 HTTP 요청을 위해 `axios` 사용

## Docker 네트워크

서비스는 커스텀 브리지 네트워크를 통해 연결됩니다:

```yaml
networks:
  msa-network:
    driver: bridge
```

이를 통해 서비스는 서비스 이름을 호스트명으로 사용하여 통신할 수 있습니다.

## 구현된 기능

✅ 마이크로서비스 아키텍처
✅ 서비스 간 HTTP 통신
✅ PostgreSQL 데이터베이스 통합
✅ Redis 캐싱 레이어
✅ 데이터베이스 초기화 스크립트
✅ 영구 데이터 볼륨
✅ 환경 변수 설정
✅ Docker 컨테이너화
✅ Docker Compose 오케스트레이션
✅ 헬스 체크 및 서비스 디스커버리
✅ 서비스 의존성 관리
✅ 작업 큐 패턴
✅ RESTful API 설계
✅ 에러 핸들링 및 로깅

## 문제 해결

### 로그 보기

```bash
# 모든 서비스
docker-compose logs -f

# 특정 서비스
docker-compose logs -f queue-service
docker-compose logs -f core-service
docker-compose logs -f postgres
docker-compose logs -f redis
```

### 서비스 재시작

```bash
# 모두 재시작
docker-compose restart

# 특정 서비스 재시작
docker-compose restart queue-service
docker-compose restart postgres
```

### 서비스 상태 확인

```bash
docker-compose ps
```

### 네트워크 이슈

```bash
# 네트워크 검사
docker network inspect mini-msa_msa-network

# 컨테이너 연결 확인
docker exec -it core-service ping queue-service
docker exec -it core-service ping postgres
docker exec -it core-service ping redis
```

### 데이터베이스 연결 이슈

```bash
# PostgreSQL 연결 확인
docker exec -it postgres pg_isready -U admin -d mini_msa

# Redis 연결 확인
docker exec -it redis redis-cli -a redis123 ping

# 데이터베이스 로그 확인
docker-compose logs postgres
docker-compose logs redis
```

## 보안 고려사항

⚠️ **주의**: 이 프로젝트는 개발/테스트 환경용입니다.

프로덕션 환경에서는 다음을 변경해야 합니다:

1. **데이터베이스 자격 증명**: 강력한 비밀번호 사용
2. **Redis 비밀번호**: 복잡한 비밀번호로 변경
3. **환경 변수**: `.env` 파일을 시크릿 관리 시스템으로 대체
4. **네트워크 보안**: 적절한 방화벽 규칙 구성
5. **TLS/SSL**: HTTPS 통신 활성화
6. **컨테이너 보안**: 비root 사용자로 실행

## 다음 단계

이 프로젝트를 확장하려면:

1. **인증/권한**: JWT 기반 인증 추가
2. **API 게이트웨이**: Kong 또는 Traefik 통합
3. **모니터링**: Prometheus + Grafana 추가
4. **로깅**: ELK 스택 또는 Loki 통합
5. **메시지 브로커**: RabbitMQ 또는 Kafka로 대체
6. **서비스 메시 : Istio 또는 Linkerd 통합
7. **CI/CD**: GitHub Actions 또는 Jenkins 파이프라인 추가
