.PHONY: help build up down restart logs test clean ps health

# Default target
help:
	@echo "Mini MSA - Available Commands"
	@echo "=============================="
	@echo "  make build      - Build all Docker images"
	@echo "  make up         - Start all services"
	@echo "  make down       - Stop and remove all services"
	@echo "  make restart    - Restart all services"
	@echo "  make logs       - View logs from all services"
	@echo "  make test       - Run integration tests"
	@echo "  make health     - Check health of all services"
	@echo "  make ps         - List running containers"
	@echo "  make clean      - Remove all containers, images, and volumes"
	@echo ""

# Build Docker images
build:
	@echo "Building Docker images..."
	docker-compose build

# Start services
up:
	@echo "Starting services..."
	docker-compose up -d
	@echo "Waiting for services to be ready..."
	@sleep 5
	@make health

# Stop services
down:
	@echo "Stopping services..."
	docker-compose down

# Restart services
restart:
	@echo "Restarting services..."
	docker-compose restart
	@sleep 3
	@make health

# View logs
logs:
	docker-compose logs -f

# Run integration tests
test:
	@echo "Running integration tests..."
	@chmod +x scripts/test.sh
	@./scripts/test.sh

# Check health of all services
health:
	@echo "Checking service health..."
	@echo ""
	@echo "Queue Service:"
	@curl -s http://localhost:3001/health | jq '.' || echo "❌ Queue service not responding"
	@echo ""
	@echo "Core Service:"
	@curl -s http://localhost:3002/health | jq '.' || echo "❌ Core service not responding"
	@echo ""

# List running containers
ps:
	docker-compose ps

# Clean up everything
clean:
	@echo "Cleaning up..."
	docker-compose down -v
	@echo "Removing images..."
	docker rmi mini-msa-queue-service mini-msa-core-service 2>/dev/null || true
	@echo "Cleanup complete!"

# Quick start (build and up)
start: build up

# Full rebuild
rebuild: down clean build up
