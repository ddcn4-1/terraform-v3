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
	@echo "Helm Commands:"
	@echo "  make helm-preflight    - Run pre-flight validation checks (recommended first)"
	@echo "  make helm-reset        - Automated cleanup and fresh install (zero manual intervention)"
	@echo "  make helm-install      - Install/upgrade application using Helm (idempotent)"
	@echo "  make helm-upgrade      - Upgrade existing Helm release"
	@echo "  make helm-uninstall    - Uninstall Helm release and clean up"
	@echo "  make helm-deps         - Update Helm chart dependencies"
	@echo "  make helm-lint         - Lint Helm chart"
	@echo "  make helm-template     - Render Helm templates"
	@echo "  make helm-status       - Show Helm release status"
	@echo "  make helm-build-images - Build local service images for Helm dev profile"
	@echo "  make helm-dry-run      - Perform dry-run installation"
	@echo "  make helm-values       - Show current Helm values"
	@echo "  make helm-history      - Show Helm release history"
	@echo "  make helm-rollback     - Rollback to previous Helm release"
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

# =============================================================================
# Helm Commands
# =============================================================================
HELM_RELEASE ?= mini-msa
HELM_CHART_DIR ?= helm/mini-msa
HELM_VALUES_FILE ?= $(HELM_CHART_DIR)/values-dev.yaml
HELM_INSTALL_FLAGS ?= --atomic --wait --timeout 5m
HELM_DEBUG ?= true
HELM_DEBUG_FLAG := $(if $(filter true,$(HELM_DEBUG)),--debug,)
HELM_BUILD_IMAGES ?= true
APP_NAMESPACE ?= mini-msa-app
DATA_NAMESPACE ?= mini-msa-data
.PHONY: helm-deps helm-lint helm-template helm-install helm-upgrade helm-uninstall helm-status helm-test helm-rollback helm-reset helm-preflight helm-build-images

# Build service images for local Helm deployments
helm-build-images:
	@echo "Building Docker images for Helm deployment (queue/core)..."
	docker build -t queue-service:latest ./queue-service
	docker build -t core-service:latest ./core-service

# Update Helm dependencies
helm-deps:
	@echo "Updating Helm dependencies..."
	cd $(HELM_CHART_DIR) && helm dependency update

# Lint Helm chart
helm-lint:
	@echo "Linting Helm chart..."
	helm lint $(HELM_CHART_DIR)

# Render Helm templates
helm-template:
	@echo "Rendering Helm templates..."
	helm template $(HELM_RELEASE) $(HELM_CHART_DIR) -f $(HELM_VALUES_FILE)

# Install Helm chart (development environment) - Idempotent
helm-install:
	@echo "Installing Mini MSA with Helm..."
	@if [ "$(HELM_BUILD_IMAGES)" = "true" ]; then \
		$(MAKE) helm-build-images; \
	fi
	@if helm list -q | grep -q "^$(HELM_RELEASE)$$"; then \
		echo "Release already exists, upgrading..."; \
		HELM_BUILD_IMAGES=false $(MAKE) helm-upgrade; \
	else \
		echo "New installation..."; \
		set -x; \
		helm dependency update $(HELM_CHART_DIR); \
		helm install $(HELM_RELEASE) $(HELM_CHART_DIR) -f $(HELM_VALUES_FILE) --create-namespace $(HELM_INSTALL_FLAGS) $(HELM_DEBUG_FLAG); \
		set +x; \
	fi
	@echo ""
	@echo "Deployment complete!"
	@echo ""
	@echo "Access the application:"
	@echo "  - Core Service: http://localhost:30002"
	@echo "  - With Ingress: http://mini-msa.local (add to /etc/hosts)"
	@echo ""
	@echo "Helm status snapshot:"
	@$(MAKE) --no-print-directory helm-status || true

# Automated reset and install (eliminates manual intervention)
helm-reset:
	@echo "Running automated Helm reset..."
	@chmod +x scripts/helm-reset.sh
	@./scripts/helm-reset.sh

# Pre-flight validation checks
helm-preflight:
	@echo "Running pre-flight checks..."
	@chmod +x scripts/preflight-check.sh
	@./scripts/preflight-check.sh

# Upgrade Helm release
helm-upgrade:
	@echo "Upgrading Mini MSA Helm release..."
	@if [ "$(HELM_BUILD_IMAGES)" = "true" ]; then \
		$(MAKE) helm-build-images; \
	fi
	@set -x; \
	helm dependency update $(HELM_CHART_DIR); \
	helm upgrade $(HELM_RELEASE) $(HELM_CHART_DIR) -f $(HELM_VALUES_FILE) --install $(HELM_INSTALL_FLAGS) $(HELM_DEBUG_FLAG); \
	set +x

# Uninstall Helm release
helm-uninstall:
	@echo "Uninstalling Mini MSA Helm release..."
	helm uninstall $(HELM_RELEASE) || true
	kubectl delete namespace $(APP_NAMESPACE) $(DATA_NAMESPACE) || true

# Check Helm release status
helm-status:
	@echo "Helm Release Status:"
	helm status $(HELM_RELEASE)
	@echo ""
	@echo "Kubernetes Resources:"
	kubectl get all -n $(APP_NAMESPACE)
	@echo ""
	kubectl get all -n $(DATA_NAMESPACE)

# Run Helm tests
helm-test:
	@echo "Running Helm connectivity tests..."
	@chmod +x scripts/helm-test.sh
	@APP_NAMESPACE=$(APP_NAMESPACE) DATA_NAMESPACE=$(DATA_NAMESPACE) HELM_RELEASE=$(HELM_RELEASE) ./scripts/helm-test.sh

# Rollback Helm release
helm-rollback:
	@echo "Rolling back Helm release..."
	helm rollback $(HELM_RELEASE)

# Dry-run installation
helm-dry-run:
	@echo "Performing dry-run installation..."
	helm dependency update $(HELM_CHART_DIR)
	helm install $(HELM_RELEASE) $(HELM_CHART_DIR) -f $(HELM_VALUES_FILE) --create-namespace $(HELM_INSTALL_FLAGS) --dry-run $(HELM_DEBUG_FLAG)

# Get Helm values
helm-values:
	@echo "Current Helm values:"
	helm get values $(HELM_RELEASE)

# Helm history
helm-history:
	@echo "Helm release history:"
	helm history $(HELM_RELEASE)
