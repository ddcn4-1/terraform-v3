# Mini MSA Test Environment

Simple microservices architecture with queue and core services for testing inter-service communication.

## Architecture

```
┌──────────────┐         ┌─────────────┐
│Queue Service │ ◄────── │Core Service │
│    :3001     │         │    :3002    │
└──────────────┘         └─────────────┘
     Internal               External
   Communication          Entry Point
```

## Services

### Queue Service (port 3001)
- Message queue management
- Job processing and status tracking
- In-memory queue storage
- Priority-based job processing

### Core Service (port 3002)
- Core business logic
- Sends jobs to queue service
- Internal HTTP communication
- User management example

## Project Structure

```
mini-msa/
├── docker-compose.yml          # Docker orchestration
├── Makefile                    # Build and test automation
├── scripts/
│   └── test.sh                 # Integration test script
├── queue-service/
│   ├── Dockerfile
│   ├── package.json
│   ├── .env                    # Environment variables
│   └── index.js                # Queue service implementation
└── core-service/
    ├── Dockerfile
    ├── package.json
    ├── .env                    # Environment variables
    └── index.js                # Core service implementation
```

## Quick Start

### Using Makefile (Recommended)

```bash
cd mini-msa

# View all available commands
make help

# Build and start services
make start              # or: make build && make up

# Run integration tests
make test

# Check service health
make health

# View logs
make logs

# Restart services
make restart

# Stop services
make down

# Clean up everything (containers, images, volumes)
make clean

# Full rebuild
make rebuild
```

### Available Make Commands

| Command | Description |
|---------|-------------|
| `make help` | Show all available commands |
| `make build` | Build Docker images |
| `make up` | Start services in detached mode |
| `make down` | Stop and remove services |
| `make restart` | Restart all services |
| `make logs` | View logs from all services |
| `make test` | Run integration tests |
| `make health` | Check health of all services |
| `make ps` | List running containers |
| `make clean` | Remove containers, images, and volumes |
| `make start` | Quick start (build + up) |
| `make rebuild` | Full rebuild (down + clean + build + up) |

### Using Docker Compose Directly

```bash
cd mini-msa

# Build and run all services
docker-compose up --build

# Or run in detached mode
docker-compose up -d

# Run test script
./scripts/test.sh

# Stop services
docker-compose down
```

## API Endpoints

### Queue Service (Internal - port 3001)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/api/queue` | Get all jobs in queue |
| POST | `/api/queue` | Add job to queue |
| POST | `/api/queue/process` | Process next job |
| GET | `/api/queue/:id` | Get job by ID |
| DELETE | `/api/queue` | Clear all jobs |

### Core Service (External - port 3002)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/api/check-queue` | Check queue service health |
| GET | `/api/jobs` | Get all jobs from queue |
| POST | `/api/jobs` | Create and send job to queue |
| POST | `/api/jobs/process` | Trigger job processing |
| POST | `/api/users` | Create user (triggers welcome email job) |

## Environment Variables

### Queue Service (.env)
```bash
PORT=3001
SERVICE_NAME=queue-service
CORE_SERVICE_URL=http://core-service:3002
```

### Core Service (.env)
```bash
PORT=3002
SERVICE_NAME=core-service
QUEUE_SERVICE_URL=http://queue-service:3001
```

## Manual Testing Examples

### 1. Health Checks

```bash
# Queue service health
curl http://localhost:3001/health

# Core service health
curl http://localhost:3002/health

# Core service checking queue service
curl http://localhost:3002/api/check-queue
```

### 2. Create Jobs

```bash
# Create a high-priority job
curl -X POST http://localhost:3002/api/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "type": "data-processing",
    "data": "important data",
    "priority": "high"
  }'

# Create a normal priority job
curl -X POST http://localhost:3002/api/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "type": "email-send",
    "data": "email content",
    "priority": "normal"
  }'
```

### 3. View and Process Jobs

```bash
# Get all jobs in queue
curl http://localhost:3002/api/jobs

# Process next job
curl -X POST http://localhost:3002/api/jobs/process

# View queue status directly
curl http://localhost:3001/api/queue
```

### 4. Business Logic Example

```bash
# Create user (automatically queues welcome email)
curl -X POST http://localhost:3002/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com"
  }'

# Check if welcome email job was queued
curl http://localhost:3001/api/queue
```

## Inter-Service Communication

Services communicate using internal Docker network (`msa-network`):

- **Internal URLs**: Services use internal hostnames (e.g., `http://queue-service:3001`)
- **External Access**: Services are accessible via `localhost` on host machine
- **Environment Variables**: Service URLs are configured in `.env` files
- **HTTP Client**: Core service uses `axios` for HTTP requests to queue service

## Docker Network

Services are connected via a custom bridge network:

```yaml
networks:
  msa-network:
    driver: bridge
```

This allows services to communicate using service names as hostnames.

## Features Demonstrated

✅ Microservices architecture
✅ Inter-service HTTP communication
✅ Environment variable configuration
✅ Docker containerization
✅ Docker Compose orchestration
✅ Health checks and service discovery
✅ Job queue pattern
✅ RESTful API design
✅ Error handling and logging
✅ Service dependencies management

## Troubleshooting

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f queue-service
docker-compose logs -f core-service
```

### Restart Services

```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart queue-service
```

### Check Service Status

```bash
docker-compose ps
```

### Network Issues

```bash
# Inspect network
docker network inspect mini-msa_msa-network

# Check container connectivity
docker exec -it core-service ping queue-service
```
