# Makefile for EKS Infrastructure Deployment
# This Makefile simplifies the deployment of the modular EKS infrastructure

.PHONY: help init plan apply destroy clean bootstrap core-infra database all kubectl-config status

# Variables
AWS_REGION ?= ap-northeast-2
PROJECT_NAME ?= hs-eks
CLUSTER_NAME = $(PROJECT_NAME)-cluster

# Color output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

##@ General

help: ## Display this help message
	@echo "$(BLUE)EKS Infrastructure Deployment$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make $(GREEN)<target>$(NC)\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BLUE)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Bootstrap

bootstrap: ## Initialize Terraform backend (S3 + DynamoDB)
	@echo "$(BLUE)========================================$(NC)"
	@echo "$(BLUE)Step 1: Bootstrapping Terraform Backend$(NC)"
	@echo "$(BLUE)========================================$(NC)"
	cd bootstrap && terraform init
	cd bootstrap && terraform plan
	@echo "$(YELLOW)Review the plan above. Press Enter to continue or Ctrl+C to cancel...$(NC)"
	@read -r
	cd bootstrap && terraform apply
	@echo "$(GREEN)✓ Bootstrap complete!$(NC)"
	@echo "$(YELLOW)Next: Update backend.tf files with the output values, then run 'make init'$(NC)"

bootstrap-destroy: ## Destroy Terraform backend (WARNING: Deletes state storage!)
	@echo "$(RED)WARNING: This will destroy the S3 bucket and DynamoDB table!$(NC)"
	@echo "$(RED)Make sure you have destroyed all other infrastructure first!$(NC)"
	@echo "$(YELLOW)Type 'yes' to continue:$(NC) "
	@read -r confirm; \
	if [ "$$confirm" = "yes" ]; then \
		cd bootstrap && terraform destroy; \
		echo "$(GREEN)✓ Bootstrap resources destroyed$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

##@ Initialization

init: init-core init-db ## Initialize all Terraform modules

init-core: ## Initialize core-infra module
	@echo "$(BLUE)Initializing core-infra module...$(NC)"
	cd core-infra && terraform init
	@echo "$(GREEN)✓ Core-infra initialized$(NC)"

init-db: ## Initialize database module
	@echo "$(BLUE)Initializing database module...$(NC)"
	cd database && terraform init
	@echo "$(GREEN)✓ Database module initialized$(NC)"

##@ Planning

plan: plan-core plan-db ## Plan all infrastructure changes

plan-core: ## Plan core-infra changes
	@echo "$(BLUE)========================================$(NC)"
	@echo "$(BLUE)Planning core-infra changes...$(NC)"
	@echo "$(BLUE)========================================$(NC)"
	cd core-infra && terraform plan

plan-db: ## Plan database changes
	@echo "$(BLUE)========================================$(NC)"
	@echo "$(BLUE)Planning database changes...$(NC)"
	@echo "$(BLUE)========================================$(NC)"
	cd database && terraform plan

##@ Deployment

deploy: deploy-core deploy-db kubectl-config ## Deploy all infrastructure
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)✓ Full deployment complete!$(NC)"
	@echo "$(GREEN)========================================$(NC)"
	@$(MAKE) status

deploy-core: ## Deploy core infrastructure (VPC, EKS)
	@echo "$(BLUE)========================================$(NC)"
	@echo "$(BLUE)Step 2: Deploying Core Infrastructure$(NC)"
	@echo "$(BLUE)========================================$(NC)"
	cd core-infra && terraform plan
	@echo "$(YELLOW)Review the plan above. Press Enter to continue or Ctrl+C to cancel...$(NC)"
	@read -r
	cd core-infra && terraform apply -auto-approve
	@echo "$(GREEN)✓ Core infrastructure deployed!$(NC)"
	@echo "$(YELLOW)EKS cluster is being created (this takes ~15-20 minutes)...$(NC)"

deploy-db: ## Deploy database resources (RDS, Redis)
	@echo "$(BLUE)========================================$(NC)"
	@echo "$(BLUE)Step 3: Deploying Database Resources$(NC)"
	@echo "$(BLUE)========================================$(NC)"
	cd database && terraform plan
	@echo "$(YELLOW)Review the plan above. Press Enter to continue or Ctrl+C to cancel...$(NC)"
	@read -r
	cd database && terraform apply -auto-approve
	@echo "$(GREEN)✓ Database resources deployed!$(NC)"

apply: deploy ## Alias for deploy (Terraform convention)

##@ Updates

update-core: ## Update core infrastructure
	@echo "$(BLUE)Updating core infrastructure...$(NC)"
	cd core-infra && terraform apply
	@echo "$(GREEN)✓ Core infrastructure updated$(NC)"

update-db: ## Update database resources
	@echo "$(BLUE)Updating database resources...$(NC)"
	cd database && terraform apply
	@echo "$(GREEN)✓ Database resources updated$(NC)"

##@ Destruction

destroy: destroy-db destroy-core ## Destroy all infrastructure
	@echo "$(GREEN)✓ All infrastructure destroyed$(NC)"

destroy-core: ## Destroy core infrastructure (WARNING: Destructive!)
	@echo "$(RED)========================================$(NC)"
	@echo "$(RED)WARNING: Destroying Core Infrastructure$(NC)"
	@echo "$(RED)========================================$(NC)"
	@echo "$(YELLOW)Type 'yes' to continue:$(NC) "
	@read -r confirm; \
	if [ "$$confirm" = "yes" ]; then \
		cd core-infra && terraform destroy; \
		echo "$(GREEN)✓ Core infrastructure destroyed$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

destroy-db: ## Destroy database resources (WARNING: Data loss!)
	@echo "$(RED)========================================$(NC)"
	@echo "$(RED)WARNING: Destroying Database Resources$(NC)"
	@echo "$(RED)This will DELETE all data in RDS and Redis!$(NC)"
	@echo "$(RED)========================================$(NC)"
	@echo "$(YELLOW)Type 'yes' to continue:$(NC) "
	@read -r confirm; \
	if [ "$$confirm" = "yes" ]; then \
		cd database && terraform destroy; \
		echo "$(GREEN)✓ Database resources destroyed$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

##@ Kubernetes

kubectl-config: ## Configure kubectl to access the EKS cluster
	@echo "$(BLUE)Configuring kubectl...$(NC)"
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(CLUSTER_NAME)
	@echo "$(GREEN)✓ kubectl configured$(NC)"
	@kubectl cluster-info

kubectl-test: ## Test kubectl connection
	@echo "$(BLUE)Testing kubectl connection...$(NC)"
	@kubectl get nodes
	@kubectl get namespaces

##@ Information

status: ## Show deployment status
	@echo "$(BLUE)========================================$(NC)"
	@echo "$(BLUE)Infrastructure Status$(NC)"
	@echo "$(BLUE)========================================$(NC)"
	@echo ""
	@echo "$(YELLOW)Core Infrastructure:$(NC)"
	@cd core-infra && terraform output 2>/dev/null || echo "  Not deployed"
	@echo ""
	@echo "$(YELLOW)Database Resources:$(NC)"
	@cd database && terraform output 2>/dev/null || echo "  Not deployed"
	@echo ""
	@echo "$(YELLOW)Kubernetes Cluster:$(NC)"
	@kubectl get nodes 2>/dev/null || echo "  Not accessible (run 'make kubectl-config')"

outputs: outputs-core outputs-db ## Show all Terraform outputs

outputs-core: ## Show core-infra outputs
	@echo "$(BLUE)Core Infrastructure Outputs:$(NC)"
	@cd core-infra && terraform output

outputs-db: ## Show database outputs
	@echo "$(BLUE)Database Outputs:$(NC)"
	@cd database && terraform output

##@ Validation

validate: validate-core validate-db ## Validate all Terraform configurations

validate-core: ## Validate core-infra configuration
	@echo "$(BLUE)Validating core-infra...$(NC)"
	cd core-infra && terraform validate
	@echo "$(GREEN)✓ Core-infra validated$(NC)"

validate-db: ## Validate database configuration
	@echo "$(BLUE)Validating database...$(NC)"
	cd database && terraform validate
	@echo "$(GREEN)✓ Database validated$(NC)"

fmt: ## Format all Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	terraform fmt -recursive .
	@echo "$(GREEN)✓ Files formatted$(NC)"

##@ Maintenance

clean: ## Clean Terraform temporary files
	@echo "$(BLUE)Cleaning Terraform files...$(NC)"
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	find . -type f -name "terraform.tfstate.backup" -delete 2>/dev/null || true
	@echo "$(GREEN)✓ Cleaned$(NC)"

refresh: ## Refresh Terraform state
	@echo "$(BLUE)Refreshing state...$(NC)"
	cd core-infra && terraform refresh
	cd database && terraform refresh
	@echo "$(GREEN)✓ State refreshed$(NC)"

##@ Quick Start

all: bootstrap init deploy ## Full deployment from scratch
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)✓ Complete deployment finished!$(NC)"
	@echo "$(GREEN)========================================$(NC)"
	@echo ""
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  1. Run 'make kubectl-test' to verify cluster access"
	@echo "  2. Deploy your application: cd ../mini-msa/helm && helm install mini-msa ./mini-msa"
	@echo "  3. Check status: make status"

quick-start: ## Show quick start guide
	@echo "$(BLUE)========================================$(NC)"
	@echo "$(BLUE)EKS Infrastructure Quick Start$(NC)"
	@echo "$(BLUE)========================================$(NC)"
	@echo ""
	@echo "$(GREEN)1. Bootstrap (one-time setup):$(NC)"
	@echo "   make bootstrap"
	@echo ""
	@echo "$(GREEN)2. Update backend.tf files:$(NC)"
	@echo "   Edit core-infra/backend.tf and database/backend.tf"
	@echo "   Replace REPLACE_WITH_BOOTSTRAP_OUTPUT with actual values"
	@echo ""
	@echo "$(GREEN)3. Initialize:$(NC)"
	@echo "   make init"
	@echo ""
	@echo "$(GREEN)4. Deploy:$(NC)"
	@echo "   make deploy"
	@echo ""
	@echo "$(GREEN)5. Configure kubectl:$(NC)"
	@echo "   make kubectl-config"
	@echo ""
	@echo "$(GREEN)6. Deploy application:$(NC)"
	@echo "   cd ../mini-msa/helm"
	@echo "   helm install mini-msa ./mini-msa"
	@echo ""
	@echo "$(YELLOW)For help: make help$(NC)"
