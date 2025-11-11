.PHONY: help build up down restart logs test clean ps health
.PHONY: k8s-setup k8s-deploy k8s-test k8s-logs k8s-status k8s-clean k8s-clean-force k8s-clean-all k8s-port-forward k8s-restart
.PHONY: lint lint-yaml lint-k8s lint-docker lint-shell

# Default target
help:
	@echo "Mini MSA - Available Commands"
	@echo "=============================="
	@echo ""
	@echo "Docker Compose Commands:"
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
	@echo "Kubernetes Commands:"
	@echo "  make k8s-setup         - Setup and deploy to local Kubernetes cluster"
	@echo "  make k8s-deploy        - Deploy/update application to Kubernetes"
	@echo "  make k8s-test          - Run Kubernetes integration tests"
	@echo "  make k8s-logs          - View logs from Kubernetes pods"
	@echo "  make k8s-status        - Check status of Kubernetes resources"
	@echo "  make k8s-port-forward  - Port forward to core-service (3002)"
	@echo "  make k8s-restart       - Restart Kubernetes deployments"
	@echo "  make k8s-clean         - Remove all Kubernetes resources (with confirmation)"
	@echo "  make k8s-clean-force   - Remove all Kubernetes resources (no confirmation)"
	@echo "  make k8s-clean-all     - Remove Kubernetes resources and Docker images"
	@echo ""
	@echo "Linting Commands:"
	@echo "  make lint              - Run all linting checks"
	@echo "  make lint-yaml         - Lint YAML files"
	@echo "  make lint-k8s          - Lint Kubernetes manifests"
	@echo "  make lint-docker       - Lint Dockerfiles"
	@echo "  make lint-shell        - Lint shell scripts"
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

# ========================================
# Kubernetes Commands
# ========================================

# Setup and deploy to local Kubernetes
k8s-setup:
	@echo "Setting up Kubernetes environment..."
	@chmod +x scripts/k8s-setup.sh
	@./scripts/k8s-setup.sh

# Deploy/update application to Kubernetes
k8s-deploy:
	@echo "Deploying to Kubernetes..."
	@docker build -t queue-service:latest ./queue-service
	@docker build -t core-service:latest ./core-service
	@echo "Applying Kubernetes manifests..."
	@kubectl apply -f k8s/base/namespace-app.yaml
	@kubectl apply -f k8s/base/namespace-data.yaml
	@kubectl apply -f k8s/base/shared-secrets.yaml
	@kubectl apply -f k8s/base/postgres/
	@kubectl apply -f k8s/base/redis/
	@kubectl apply -f k8s/base/queue-service/
	@kubectl apply -f k8s/base/core-service/
	@echo "Deployment complete!"

# Run Kubernetes integration tests
k8s-test:
	@echo "Running Kubernetes tests..."
	@chmod +x scripts/k8s-test.sh
	@./scripts/k8s-test.sh

# View logs from Kubernetes pods
k8s-logs:
	@echo "Viewing logs from all pods..."
	@echo ""
	@echo "=== PostgreSQL Logs (mini-msa-data) ==="
	@kubectl logs -l app=postgres -n mini-msa-data --tail=50 || true
	@echo ""
	@echo "=== Redis Logs (mini-msa-data) ==="
	@kubectl logs -l app=redis -n mini-msa-data --tail=50 || true
	@echo ""
	@echo "=== Queue Service Logs (mini-msa-app) ==="
	@kubectl logs -l app=queue-service -n mini-msa-app --tail=50 || true
	@echo ""
	@echo "=== Core Service Logs (mini-msa-app) ==="
	@kubectl logs -l app=core-service -n mini-msa-app --tail=50 || true

# Follow logs from a specific service
k8s-logs-core:
	kubectl logs -f -l app=core-service -n mini-msa-app

k8s-logs-queue:
	kubectl logs -f -l app=queue-service -n mini-msa-app

k8s-logs-postgres:
	kubectl logs -f -l app=postgres -n mini-msa-data

k8s-logs-redis:
	kubectl logs -f -l app=redis -n mini-msa-data

# Check status of Kubernetes resources
k8s-status:
	@echo "Kubernetes Resources Status"
	@echo "============================"
	@echo ""
	@echo "=== Application Namespace (mini-msa-app) ==="
	@echo ""
	@echo "Pods:"
	@kubectl get pods -n mini-msa-app
	@echo ""
	@echo "Services:"
	@kubectl get svc -n mini-msa-app
	@echo ""
	@echo "Deployments:"
	@kubectl get deployments -n mini-msa-app
	@echo ""
	@echo "Ingress:"
	@kubectl get ingress -n mini-msa-app 2>/dev/null || echo "No ingress resources found"
	@echo ""
	@echo "=== Data Namespace (mini-msa-data) ==="
	@echo ""
	@echo "Pods:"
	@kubectl get pods -n mini-msa-data
	@echo ""
	@echo "Services:"
	@kubectl get svc -n mini-msa-data
	@echo ""
	@echo "StatefulSets:"
	@kubectl get statefulsets -n mini-msa-data
	@echo ""
	@echo "PersistentVolumeClaims:"
	@kubectl get pvc -n mini-msa-data

# Port forward to core-service
k8s-port-forward:
	@echo "Port forwarding to core-service on port 3002..."
	@echo "Access at: http://localhost:3002"
	@echo "Press Ctrl+C to stop"
	kubectl port-forward -n mini-msa-app svc/core-service 3002:3002

# Port forward to queue-service
k8s-port-forward-queue:
	@echo "Port forwarding to queue-service on port 3001..."
	@echo "Access at: http://localhost:3001"
	@echo "Press Ctrl+C to stop"
	kubectl port-forward -n mini-msa-app svc/queue-service 3001:3001

# Remove all Kubernetes resources
k8s-clean:
	@echo "Removing Kubernetes resources..."
	@chmod +x scripts/k8s-cleanup.sh
	@./scripts/k8s-cleanup.sh

# Remove all Kubernetes resources (force, no confirmation)
k8s-clean-force:
	@echo "Removing Kubernetes resources (force)..."
	@chmod +x scripts/k8s-cleanup.sh
	@./scripts/k8s-cleanup.sh --force

# Remove all Kubernetes resources including Docker images
k8s-clean-all:
	@echo "Removing Kubernetes resources and Docker images..."
	@chmod +x scripts/k8s-cleanup.sh
	@./scripts/k8s-cleanup.sh --images

# Restart Kubernetes pods
k8s-restart:
	@echo "Restarting application pods..."
	@kubectl rollout restart deployment/queue-service -n mini-msa-app
	@kubectl rollout restart deployment/core-service -n mini-msa-app
	@echo "Application pods are restarting..."

k8s-restart-data:
	@echo "Restarting data pods..."
	@kubectl rollout restart statefulset/postgres -n mini-msa-data
	@kubectl rollout restart statefulset/redis -n mini-msa-data
	@echo "Data pods are restarting..."

# Describe a specific pod (useful for debugging)
k8s-describe-core:
	kubectl describe pods -l app=core-service -n mini-msa-app

k8s-describe-queue:
	kubectl describe pods -l app=queue-service -n mini-msa-app

k8s-describe-postgres:
	kubectl describe pods -l app=postgres -n mini-msa-data

k8s-describe-redis:
	kubectl describe pods -l app=redis -n mini-msa-data

# Shell into a pod
k8s-shell-core:
	kubectl exec -it -n mini-msa-app $$(kubectl get pod -l app=core-service -n mini-msa-app -o jsonpath='{.items[0].metadata.name}') -- sh

k8s-shell-queue:
	kubectl exec -it -n mini-msa-app $$(kubectl get pod -l app=queue-service -n mini-msa-app -o jsonpath='{.items[0].metadata.name}') -- sh

k8s-shell-postgres:
	kubectl exec -it -n mini-msa-data $$(kubectl get pod -l app=postgres -n mini-msa-data -o jsonpath='{.items[0].metadata.name}') -- psql -U admin -d mini_msa

k8s-shell-redis:
	kubectl exec -it -n mini-msa-data $$(kubectl get pod -l app=redis -n mini-msa-data -o jsonpath='{.items[0].metadata.name}') -- redis-cli -a redis123

# ========================================
# Linting Commands
# ========================================

# Run all linting checks
lint:
	@echo "Running all linting checks..."
	@chmod +x scripts/lint-all.sh
	@./scripts/lint-all.sh

# Lint YAML files
lint-yaml:
	@echo "Linting YAML files..."
	@yamllint k8s/

# Lint Kubernetes manifests
lint-k8s:
	@echo "Linting Kubernetes manifests..."
	@kube-linter lint k8s/base/ --config .kube-linter.yaml

# Lint Dockerfiles
lint-docker:
	@echo "Linting Dockerfiles..."
	@hadolint queue-service/Dockerfile
	@hadolint core-service/Dockerfile

# Lint shell scripts
lint-shell:
	@echo "Linting shell scripts..."
	@shellcheck scripts/*.sh
