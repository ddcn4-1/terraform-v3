.PHONY: help build up down restart logs test clean ps health
.PHONY: k8s-setup k8s-deploy k8s-test k8s-logs k8s-status k8s-clean k8s-clean-force k8s-clean-all k8s-port-forward k8s-restart
.PHONY: lint lint-yaml lint-k8s lint-docker lint-shell
.PHONY: ecr-login ecr-push ecr-push-core ecr-push-queue eks-deploy eks-update eks-kubeconfig eks-status eks-uninstall eks-test eks-test-verbose

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
	@echo "ECR Commands:"
	@echo "  make ecr-login       - Login to AWS ECR"
	@echo "  make ecr-push        - Build and push all images to ECR"
	@echo "  make ecr-push-core   - Build and push core-service to ECR"
	@echo "  make ecr-push-queue  - Build and push queue-service to ECR"
	@echo ""
	@echo "EKS Deployment Commands:"
	@echo "  make eks-kubeconfig     - Configure kubectl for EKS cluster"
	@echo "  make eks-deploy         - Deploy/upgrade application to EKS using Helm"
	@echo "  make eks-update         - Update running application with new images"
	@echo "  make eks-status         - Check EKS deployment status"
	@echo "  make eks-test           - Run EKS integration tests via ALB"
	@echo "  make eks-test-verbose   - Run EKS tests with verbose output"
	@echo "  make eks-uninstall      - Uninstall application from EKS"
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
	@echo "ELK Stack Commands:"
	@echo "  make elk-install            - Install ELK stack (enable ECK operator)"
	@echo "  make elk-status             - Check ELK stack status"
	@echo "  make elk-password           - Get Elasticsearch password"
	@echo "  make elk-port-forward-kibana - Port forward to Kibana (5601)"
	@echo "  make elk-port-forward-es    - Port forward to Elasticsearch (9200)"
	@echo "  make elk-logs-es            - View Elasticsearch logs"
	@echo "  make elk-logs-kibana        - View Kibana logs"
	@echo "  make elk-logs-filebeat      - View Filebeat logs"
	@echo "  make elk-health             - Check ELK stack health"
	@echo "  make elk-uninstall          - Uninstall ELK stack"
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

# Test via ALB (internet-facing)
alb-test:
	@echo "Running ALB API tests..."
	@chmod +x scripts/alb-test.sh
	@APP_NAMESPACE=$(APP_NAMESPACE) ./scripts/alb-test.sh

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

# =============================================================================
# ELK Stack Commands
# =============================================================================

# Install ELK stack (enable ECK operator)
elk-install:
	@echo "Installing ELK stack in two stages..."
	@echo ""
	@echo "Stage 1: Installing ECK Operator and CRDs..."
	helm dependency update $(HELM_CHART_DIR)
	helm upgrade --install $(HELM_RELEASE) $(HELM_CHART_DIR) -f $(HELM_VALUES_FILE) \
		--set logging.eck.operator.enabled=true \
		--set logging.elasticsearch.enabled=false \
		--set logging.kibana.enabled=false \
		--set logging.filebeat.enabled=false \
		$(HELM_INSTALL_FLAGS)
	@echo ""
	@echo "Waiting for ECK Operator to be ready..."
	@sleep 10
	@echo ""
	@echo "Stage 2: Installing Elasticsearch and Kibana..."
	helm upgrade --install $(HELM_RELEASE) $(HELM_CHART_DIR) -f $(HELM_VALUES_FILE) \
		--set logging.eck.operator.enabled=true \
		$(HELM_INSTALL_FLAGS)
	@echo ""
	@echo "ELK stack installation complete!"
	@echo "Run 'make elk-status' to check the status"

# Check ELK stack status
elk-status:
	@echo "Checking ELK stack status..."
	@echo ""
	@echo "=== ECK Operator ==="
	kubectl get pods -n elastic-system 2>/dev/null || echo "ECK Operator not installed"
	@echo ""
	@echo "=== Elasticsearch ==="
	kubectl get elasticsearch -n $(APP_NAMESPACE) 2>/dev/null || echo "Elasticsearch not found"
	kubectl get pods -l common.k8s.elastic.co/type=elasticsearch -n $(APP_NAMESPACE) 2>/dev/null || true
	@echo ""
	@echo "=== Kibana ==="
	kubectl get kibana -n $(APP_NAMESPACE) 2>/dev/null || echo "Kibana not found"
	kubectl get pods -l common.k8s.elastic.co/type=kibana -n $(APP_NAMESPACE) 2>/dev/null || true
	@echo ""
	@echo "=== Filebeat ==="
	kubectl get beat -n $(APP_NAMESPACE) 2>/dev/null || echo "Filebeat not found"
	kubectl get pods -l common.k8s.elastic.co/type=beat -n $(APP_NAMESPACE) 2>/dev/null || true

# Get Elasticsearch password
elk-password:
	@echo "Retrieving Elasticsearch password..."
	@kubectl get secret $(HELM_RELEASE)-elasticsearch-es-elastic-user -n $(APP_NAMESPACE) -o go-template='{{.data.elastic | base64decode}}' 2>/dev/null || echo "Secret not found. Make sure ELK stack is installed."
	@echo ""

# Port forward to Kibana
elk-port-forward-kibana:
	@echo "Port forwarding Kibana to localhost:5601..."
	@echo "Access at: https://localhost:5601"
	@echo "Username: elastic"
	@echo "Password: (run 'make elk-password')"
	@echo "Press Ctrl+C to stop"
	@echo ""
	kubectl port-forward -n $(APP_NAMESPACE) svc/$(HELM_RELEASE)-kibana-kb-http 5601:5601

# Port forward to Elasticsearch
elk-port-forward-es:
	@echo "Port forwarding Elasticsearch to localhost:9200..."
	@echo "Access at: https://localhost:9200"
	@echo "Press Ctrl+C to stop"
	@echo ""
	kubectl port-forward -n $(APP_NAMESPACE) svc/$(HELM_RELEASE)-elasticsearch-es-http 9200:9200

# View Elasticsearch logs
elk-logs-es:
	@echo "Viewing Elasticsearch logs..."
	kubectl logs -l common.k8s.elastic.co/type=elasticsearch -n $(APP_NAMESPACE) --tail=50 -f

# View Kibana logs
elk-logs-kibana:
	@echo "Viewing Kibana logs..."
	kubectl logs -l common.k8s.elastic.co/type=kibana -n $(APP_NAMESPACE) --tail=50 -f

# View Filebeat logs
elk-logs-filebeat:
	@echo "Viewing Filebeat logs..."
	kubectl logs -l common.k8s.elastic.co/type=beat -n $(APP_NAMESPACE) --tail=50 -f

# Uninstall ELK stack
elk-uninstall:
	@echo "Uninstalling ELK stack..."
	kubectl delete elasticsearch,kibana,beat --all -n $(APP_NAMESPACE) 2>/dev/null || true
	@echo "Waiting for resources to be deleted..."
	@sleep 5
	@echo "ELK stack uninstalled"

# ELK health check
elk-health:
	@echo "Checking ELK stack health..."
	@echo ""
	@echo "Elasticsearch health:"
	@kubectl exec -n $(APP_NAMESPACE) $(HELM_RELEASE)-elasticsearch-es-default-0 -- curl -k -u elastic:$$(kubectl get secret $(HELM_RELEASE)-elasticsearch-es-elastic-user -n $(APP_NAMESPACE) -o go-template='{{.data.elastic | base64decode}}') https://localhost:9200/_cluster/health?pretty 2>/dev/null || echo "Failed to connect"

# =============================================================================
# ECR Commands
# =============================================================================
TERRAFORM_DIR ?= ../terraform/core-infra
AWS_REGION ?= ap-northeast-2
IMAGE_TAG ?= latest
ECR_CORE_URL := $(shell cd $(TERRAFORM_DIR) && terraform output -raw ecr_core_service_url 2>/dev/null || echo "")
ECR_QUEUE_URL := $(shell cd $(TERRAFORM_DIR) && terraform output -raw ecr_queue_service_url 2>/dev/null || echo "")
AWS_ACCOUNT_ID := $(shell cd $(TERRAFORM_DIR) && terraform output -raw aws_account_id 2>/dev/null || echo "")

# Login to ECR
ecr-login:
	@echo "Logging in to ECR..."
	@if [ -z "$(AWS_ACCOUNT_ID)" ]; then \
		echo "Error: Cannot get AWS Account ID from Terraform outputs"; \
		exit 1; \
	fi
	aws ecr get-login-password --region $(AWS_REGION) | \
		docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
	@echo "✓ Logged in to ECR successfully"

# Build and push all images to ECR
ecr-push: ecr-login
	@echo "Building and pushing all images to ECR..."
	@if [ -z "$(ECR_CORE_URL)" ] || [ -z "$(ECR_QUEUE_URL)" ]; then \
		echo "Error: Cannot get ECR URLs from Terraform outputs"; \
		echo "Make sure Terraform has been applied in $(TERRAFORM_DIR)"; \
		exit 1; \
	fi
	@$(MAKE) ecr-push-core
	@$(MAKE) ecr-push-queue
	@echo ""
	@echo "✓ All images pushed to ECR successfully!"
	@echo ""
	@echo "Images:"
	@echo "  $(ECR_CORE_URL):$(IMAGE_TAG)"
	@echo "  $(ECR_QUEUE_URL):$(IMAGE_TAG)"

# Build and push core-service to ECR
ecr-push-core:
	@echo "Building and pushing core-service..."
	@if [ -z "$(ECR_CORE_URL)" ]; then \
		echo "Error: ECR_CORE_URL not set"; \
		exit 1; \
	fi
	docker build -t core-service:$(IMAGE_TAG) ./core-service
	docker tag core-service:$(IMAGE_TAG) $(ECR_CORE_URL):$(IMAGE_TAG)
	docker push $(ECR_CORE_URL):$(IMAGE_TAG)
	@echo "✓ core-service pushed to $(ECR_CORE_URL):$(IMAGE_TAG)"

# Build and push queue-service to ECR
ecr-push-queue:
	@echo "Building and pushing queue-service..."
	@if [ -z "$(ECR_QUEUE_URL)" ]; then \
		echo "Error: ECR_QUEUE_URL not set"; \
		exit 1; \
	fi
	docker build -t queue-service:$(IMAGE_TAG) ./queue-service
	docker tag queue-service:$(IMAGE_TAG) $(ECR_QUEUE_URL):$(IMAGE_TAG)
	docker push $(ECR_QUEUE_URL):$(IMAGE_TAG)
	@echo "✓ queue-service pushed to $(ECR_QUEUE_URL):$(IMAGE_TAG)"

# =============================================================================
# EKS Deployment Commands
# =============================================================================
EKS_NAMESPACE ?= mini-msa-app
EKS_RELEASE ?= mini-msa
EKS_VALUES_FILE ?= helm/mini-msa/values-eks.yaml
EKS_CLUSTER_NAME := $(shell cd $(TERRAFORM_DIR) && terraform output -raw eks_cluster_name 2>/dev/null || echo "")

# Configure kubectl for EKS cluster
eks-kubeconfig:
	@echo "Configuring kubectl for EKS cluster..."
	@if [ -z "$(EKS_CLUSTER_NAME)" ]; then \
		echo "Error: Cannot get EKS cluster name from Terraform outputs"; \
		exit 1; \
	fi
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(EKS_CLUSTER_NAME)
	@echo "✓ kubectl configured for cluster: $(EKS_CLUSTER_NAME)"
	@echo ""
	@kubectl cluster-info

# Deploy/upgrade application to EKS using Helm
eks-deploy: eks-kubeconfig
	@echo "Deploying to EKS cluster..."
	@if [ ! -f "$(EKS_VALUES_FILE)" ]; then \
		echo "Error: Values file not found: $(EKS_VALUES_FILE)"; \
		exit 1; \
	fi
	@echo "Updating Helm dependencies..."
	cd helm/mini-msa && helm dependency update
	@echo "Installing/Upgrading Helm release..."
	helm upgrade --install $(EKS_RELEASE) helm/mini-msa \
		-f $(EKS_VALUES_FILE) \
		--namespace $(EKS_NAMESPACE) \
		--create-namespace \
		--atomic \
		--wait \
		--timeout 10m
	@echo ""
	@echo "✓ Deployment complete!"
	@echo ""
	@$(MAKE) eks-status

# Update running application with new images (build, push, deploy)
eks-update: ecr-push
	@echo "Updating EKS deployment with new images..."
	helm upgrade $(EKS_RELEASE) helm/mini-msa \
		-f $(EKS_VALUES_FILE) \
		--namespace $(EKS_NAMESPACE) \
		--set coreService.image.tag=$(IMAGE_TAG) \
		--set queueService.image.tag=$(IMAGE_TAG) \
		--atomic \
		--wait \
		--timeout 10m
	@echo ""
	@echo "✓ Update complete!"
	@$(MAKE) eks-status

# Check EKS deployment status
eks-status:
	@echo "EKS Deployment Status"
	@echo "===================="
	@echo ""
	@echo "Helm Release:"
	@helm status $(EKS_RELEASE) -n $(EKS_NAMESPACE) || echo "Release not found"
	@echo ""
	@echo "Pods:"
	@kubectl get pods -n $(EKS_NAMESPACE) -o wide
	@echo ""
	@echo "Services:"
	@kubectl get svc -n $(EKS_NAMESPACE)
	@echo ""
	@echo "Ingress:"
	@kubectl get ingress -n $(EKS_NAMESPACE)

# Run EKS integration tests via ALB
eks-test:
	@echo "Running EKS integration tests..."
	@chmod +x scripts/eks-test.sh
	@APP_NAMESPACE=$(EKS_NAMESPACE) ./scripts/eks-test.sh

# Run EKS integration tests with verbose output
eks-test-verbose:
	@echo "Running EKS integration tests (verbose mode)..."
	@chmod +x scripts/eks-test.sh
	@APP_NAMESPACE=$(EKS_NAMESPACE) ./scripts/eks-test.sh --verbose

# Uninstall application from EKS
eks-uninstall:
	@echo "Uninstalling application from EKS..."
	helm uninstall $(EKS_RELEASE) -n $(EKS_NAMESPACE) || true
	@echo "Waiting for resources to be deleted..."
	@sleep 5
	@echo "Do you want to delete the namespace? [y/N]"
	@read -p "> " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		kubectl delete namespace $(EKS_NAMESPACE) || true; \
		echo "✓ Namespace deleted"; \
	else \
		echo "Namespace preserved"; \
	fi
	@echo "✓ Uninstall complete"
