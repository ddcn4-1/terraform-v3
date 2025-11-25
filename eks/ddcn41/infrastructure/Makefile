# ============================================================================
# EKS Infrastructure Makefile
# Multi-region deployment management with Velero migration support
# ============================================================================

.PHONY: help init plan apply destroy fmt validate clean \
        seoul-init seoul-plan seoul-apply seoul-destroy \
        tokyo-init tokyo-plan tokyo-apply tokyo-destroy \
        dev-init dev-plan dev-apply dev-destroy \
        velero-install velero-backup velero-restore velero-status \
        dr-failover dr-failback ecr-login

# Default environment
ENV ?= dev
REGION ?= seoul

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Terraform directories
TF_DIR := environments
DEV_DIR := $(TF_DIR)/dev
SEOUL_DIR := $(TF_DIR)/seoul
TOKYO_DIR := $(TF_DIR)/tokyo

# AWS Configuration
AWS_REGION_SEOUL := ap-northeast-2
AWS_REGION_TOKYO := ap-northeast-1

# ============================================================================
# Help
# ============================================================================
help: ## Show this help message
	@echo "$(BLUE)╔══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║           EKS Infrastructure Management Commands                  ║$(NC)"
	@echo "$(BLUE)╚══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)Development Environment:$(NC)"
	@echo "  make dev-init          Initialize dev environment"
	@echo "  make dev-plan          Plan dev infrastructure changes"
	@echo "  make dev-apply         Apply dev infrastructure"
	@echo "  make dev-destroy       Destroy dev infrastructure"
	@echo ""
	@echo "$(GREEN)Seoul (Production Primary):$(NC)"
	@echo "  make seoul-init        Initialize Seoul environment"
	@echo "  make seoul-plan        Plan Seoul infrastructure changes"
	@echo "  make seoul-apply       Apply Seoul infrastructure"
	@echo "  make seoul-destroy     Destroy Seoul infrastructure (⚠️  DANGEROUS)"
	@echo ""
	@echo "$(GREEN)Tokyo (DR Secondary):$(NC)"
	@echo "  make tokyo-init        Initialize Tokyo environment"
	@echo "  make tokyo-plan        Plan Tokyo infrastructure changes"
	@echo "  make tokyo-apply       Apply Tokyo infrastructure"
	@echo "  make tokyo-destroy     Destroy Tokyo infrastructure"
	@echo ""
	@echo "$(GREEN)Velero Operations:$(NC)"
	@echo "  make velero-install REGION=<seoul|tokyo>    Install Velero on cluster"
	@echo "  make velero-backup NAME=<name> REGION=<region>  Create backup"
	@echo "  make velero-restore NAME=<name> REGION=<region> Restore from backup"
	@echo "  make velero-status REGION=<region>          Check Velero status"
	@echo ""
	@echo "$(GREEN)DR Operations:$(NC)"
	@echo "  make dr-failover       Failover to Tokyo (DR activation)"
	@echo "  make dr-failback       Failback to Seoul (DR deactivation)"
	@echo ""
	@echo "$(GREEN)Utility Commands:$(NC)"
	@echo "  make fmt               Format all Terraform files"
	@echo "  make validate          Validate all Terraform configurations"
	@echo "  make clean             Clean temporary files"
	@echo "  make ecr-login REGION=<region>  Login to ECR"
	@echo ""

# ============================================================================
# Common Terraform Commands
# ============================================================================
fmt: ## Format all Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	@terraform fmt -recursive .
	@echo "$(GREEN)✓ Formatting complete$(NC)"

validate: ## Validate all configurations
	@echo "$(BLUE)Validating Terraform configurations...$(NC)"
	@for dir in $(DEV_DIR) $(SEOUL_DIR) $(TOKYO_DIR); do \
		if [ -d "$$dir" ]; then \
			echo "Validating $$dir..."; \
			cd $$dir && terraform validate && cd - > /dev/null; \
		fi \
	done
	@echo "$(GREEN)✓ All configurations valid$(NC)"

clean: ## Clean temporary files
	@echo "$(BLUE)Cleaning temporary files...$(NC)"
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.tfstate.backup" -delete 2>/dev/null || true
	@find . -type f -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

# ============================================================================
# Development Environment
# ============================================================================
dev-init: ## Initialize dev environment
	@echo "$(BLUE)Initializing Dev environment...$(NC)"
	@cd $(DEV_DIR) && terraform init
	@echo "$(GREEN)✓ Dev environment initialized$(NC)"

dev-plan: ## Plan dev infrastructure
	@echo "$(BLUE)Planning Dev infrastructure...$(NC)"
	@cd $(DEV_DIR) && terraform plan -out=tfplan

dev-apply: ## Apply dev infrastructure
	@echo "$(YELLOW)Applying Dev infrastructure...$(NC)"
	@cd $(DEV_DIR) && terraform apply tfplan
	@echo "$(GREEN)✓ Dev infrastructure applied$(NC)"

dev-apply-auto: ## Apply dev infrastructure (auto-approve)
	@echo "$(YELLOW)Applying Dev infrastructure (auto-approve)...$(NC)"
	@cd $(DEV_DIR) && terraform apply -auto-approve
	@echo "$(GREEN)✓ Dev infrastructure applied$(NC)"

dev-destroy: ## Destroy dev infrastructure
	@echo "$(RED)⚠️  Destroying Dev infrastructure...$(NC)"
	@cd $(DEV_DIR) && terraform destroy
	@echo "$(GREEN)✓ Dev infrastructure destroyed$(NC)"

dev-output: ## Show dev outputs
	@cd $(DEV_DIR) && terraform output

# ============================================================================
# Seoul Environment (Production Primary)
# ============================================================================
seoul-init: ## Initialize Seoul environment
	@echo "$(BLUE)Initializing Seoul (ap-northeast-2) environment...$(NC)"
	@cd $(SEOUL_DIR) && terraform init
	@echo "$(GREEN)✓ Seoul environment initialized$(NC)"

seoul-plan: ## Plan Seoul infrastructure
	@echo "$(BLUE)Planning Seoul infrastructure...$(NC)"
	@cd $(SEOUL_DIR) && terraform plan -out=tfplan

seoul-apply: ## Apply Seoul infrastructure
	@echo "$(YELLOW)Applying Seoul infrastructure...$(NC)"
	@read -p "Are you sure you want to apply to Seoul (Production)? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		cd $(SEOUL_DIR) && terraform apply tfplan; \
		echo "$(GREEN)✓ Seoul infrastructure applied$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

seoul-destroy: ## Destroy Seoul infrastructure (DANGEROUS)
	@echo "$(RED)╔══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(RED)║  ⚠️  WARNING: This will destroy PRODUCTION infrastructure!        ║$(NC)"
	@echo "$(RED)╚══════════════════════════════════════════════════════════════════╝$(NC)"
	@read -p "Type 'DESTROY-SEOUL-PROD' to confirm: " confirm; \
	if [ "$$confirm" = "DESTROY-SEOUL-PROD" ]; then \
		cd $(SEOUL_DIR) && terraform destroy; \
	else \
		echo "$(YELLOW)Destruction cancelled$(NC)"; \
	fi

seoul-output: ## Show Seoul outputs
	@cd $(SEOUL_DIR) && terraform output

# ============================================================================
# Tokyo Environment (DR Secondary)
# ============================================================================
tokyo-init: ## Initialize Tokyo environment
	@echo "$(BLUE)Initializing Tokyo (ap-northeast-1) environment...$(NC)"
	@cd $(TOKYO_DIR) && terraform init
	@echo "$(GREEN)✓ Tokyo environment initialized$(NC)"

tokyo-plan: ## Plan Tokyo infrastructure
	@echo "$(BLUE)Planning Tokyo infrastructure...$(NC)"
	@cd $(TOKYO_DIR) && terraform plan -out=tfplan

tokyo-apply: ## Apply Tokyo infrastructure
	@echo "$(YELLOW)Applying Tokyo infrastructure...$(NC)"
	@cd $(TOKYO_DIR) && terraform apply tfplan
	@echo "$(GREEN)✓ Tokyo infrastructure applied$(NC)"

tokyo-destroy: ## Destroy Tokyo infrastructure
	@echo "$(YELLOW)Destroying Tokyo infrastructure...$(NC)"
	@read -p "Are you sure you want to destroy Tokyo infrastructure? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		cd $(TOKYO_DIR) && terraform destroy; \
		echo "$(GREEN)✓ Tokyo infrastructure destroyed$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

tokyo-output: ## Show Tokyo outputs
	@cd $(TOKYO_DIR) && terraform output

# ============================================================================
# Velero Operations
# ============================================================================
velero-install: ## Install Velero on cluster (REGION=seoul|tokyo)
	@echo "$(BLUE)Installing Velero on $(REGION) cluster...$(NC)"
	@if [ "$(REGION)" = "seoul" ]; then \
		AWS_REGION=$(AWS_REGION_SEOUL); \
		BUCKET=$$(cd $(SEOUL_DIR) && terraform output -raw velero_bucket_name 2>/dev/null); \
		ROLE_ARN=$$(cd $(SEOUL_DIR) && terraform output -raw velero_role_arn 2>/dev/null); \
	elif [ "$(REGION)" = "tokyo" ]; then \
		AWS_REGION=$(AWS_REGION_TOKYO); \
		BUCKET=$$(cd $(TOKYO_DIR) && terraform output -raw velero_bucket_name 2>/dev/null); \
		ROLE_ARN=$$(cd $(TOKYO_DIR) && terraform output -raw velero_role_arn 2>/dev/null); \
	else \
		echo "$(RED)Invalid REGION. Use seoul or tokyo$(NC)"; \
		exit 1; \
	fi; \
	echo "Bucket: $$BUCKET"; \
	echo "Role ARN: $$ROLE_ARN"; \
	echo "Region: $$AWS_REGION"; \
	velero install \
		--provider aws \
		--plugins velero/velero-plugin-for-aws:v1.10.0 \
		--bucket $$BUCKET \
		--backup-location-config region=$$AWS_REGION \
		--snapshot-location-config region=$$AWS_REGION \
		--use-node-agent \
		--sa-annotations "eks.amazonaws.com/role-arn=$$ROLE_ARN"

velero-backup: ## Create Velero backup (NAME=backup-name REGION=seoul|tokyo)
ifndef NAME
	@echo "$(RED)Error: NAME is required. Usage: make velero-backup NAME=my-backup REGION=seoul$(NC)"
	@exit 1
endif
	@echo "$(BLUE)Creating Velero backup '$(NAME)' on $(REGION)...$(NC)"
	@velero backup create $(NAME) --wait
	@echo "$(GREEN)✓ Backup '$(NAME)' created$(NC)"

velero-backup-schedule: ## Create scheduled backup
	@echo "$(BLUE)Creating scheduled backup...$(NC)"
	@velero schedule create daily-backup --schedule="0 2 * * *" --ttl 168h
	@echo "$(GREEN)✓ Daily backup schedule created$(NC)"

velero-restore: ## Restore from Velero backup (NAME=backup-name)
ifndef NAME
	@echo "$(RED)Error: NAME is required. Usage: make velero-restore NAME=my-backup$(NC)"
	@exit 1
endif
	@echo "$(YELLOW)Restoring from backup '$(NAME)'...$(NC)"
	@velero restore create --from-backup $(NAME) --wait
	@echo "$(GREEN)✓ Restore from '$(NAME)' complete$(NC)"

velero-status: ## Check Velero status
	@echo "$(BLUE)Velero Status:$(NC)"
	@echo ""
	@echo "$(BLUE)=== Backup Locations ===$(NC)"
	@velero backup-location get || echo "No backup locations found"
	@echo ""
	@echo "$(BLUE)=== Recent Backups ===$(NC)"
	@velero backup get || echo "No backups found"
	@echo ""
	@echo "$(BLUE)=== Recent Restores ===$(NC)"
	@velero restore get || echo "No restores found"
	@echo ""
	@echo "$(BLUE)=== Schedules ===$(NC)"
	@velero schedule get || echo "No schedules found"

velero-logs: ## Show Velero logs
	@kubectl logs -n velero deployment/velero -f

# ============================================================================
# DR Operations
# ============================================================================
dr-failover: ## Failover to Tokyo (DR activation)
	@echo "$(RED)╔══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(RED)║           DR FAILOVER - Activating Tokyo Cluster                  ║$(NC)"
	@echo "$(RED)╚══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)This will:$(NC)"
	@echo "  1. Switch kubectl context to Tokyo cluster"
	@echo "  2. Add Seoul backup location as read-only source"
	@echo "  3. List available backups from Seoul"
	@echo "  4. Prompt for backup to restore"
	@echo ""
	@read -p "Proceed with DR failover? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		echo "$(BLUE)Step 1: Switching to Tokyo cluster...$(NC)"; \
		TOKYO_CLUSTER=$$(cd $(TOKYO_DIR) && terraform output -raw eks_cluster_name 2>/dev/null); \
		aws eks update-kubeconfig --region $(AWS_REGION_TOKYO) --name $$TOKYO_CLUSTER; \
		echo "$(BLUE)Step 2: Adding Seoul backup location...$(NC)"; \
		SEOUL_BUCKET=$$(cd $(SEOUL_DIR) && terraform output -raw velero_bucket_name 2>/dev/null); \
		velero backup-location create seoul-source \
			--provider aws \
			--bucket $$SEOUL_BUCKET \
			--config region=$(AWS_REGION_SEOUL) \
			--access-mode=ReadOnly || true; \
		echo "$(BLUE)Step 3: Waiting for backup sync...$(NC)"; \
		sleep 10; \
		echo "$(BLUE)Available backups:$(NC)"; \
		velero backup get; \
		echo ""; \
		read -p "Enter backup name to restore: " BACKUP_NAME; \
		echo "$(BLUE)Step 4: Restoring from $$BACKUP_NAME...$(NC)"; \
		velero restore create dr-failover-$$(date +%Y%m%d%H%M%S) --from-backup $$BACKUP_NAME --wait; \
		echo "$(GREEN)✓ DR Failover complete$(NC)"; \
	else \
		echo "$(YELLOW)Failover cancelled$(NC)"; \
	fi

dr-failback: ## Failback to Seoul (DR deactivation)
	@echo "$(BLUE)╔══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║           DR FAILBACK - Returning to Seoul Cluster                ║$(NC)"
	@echo "$(BLUE)╚══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)This will:$(NC)"
	@echo "  1. Create final backup of Tokyo state"
	@echo "  2. Switch kubectl context to Seoul cluster"
	@echo "  3. Restore Tokyo backup to Seoul (if needed)"
	@echo ""
	@read -p "Proceed with DR failback? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		echo "$(BLUE)Step 1: Creating Tokyo backup...$(NC)"; \
		velero backup create tokyo-failback-$$(date +%Y%m%d%H%M%S) --wait; \
		echo "$(BLUE)Step 2: Switching to Seoul cluster...$(NC)"; \
		SEOUL_CLUSTER=$$(cd $(SEOUL_DIR) && terraform output -raw eks_cluster_name 2>/dev/null); \
		aws eks update-kubeconfig --region $(AWS_REGION_SEOUL) --name $$SEOUL_CLUSTER; \
		echo "$(GREEN)✓ Now connected to Seoul cluster$(NC)"; \
		echo "$(YELLOW)Note: If data sync from Tokyo is needed, use 'make velero-restore'$(NC)"; \
	else \
		echo "$(YELLOW)Failback cancelled$(NC)"; \
	fi

# ============================================================================
# ECR Operations
# ============================================================================
ecr-login: ## Login to ECR (REGION=seoul|tokyo)
	@if [ "$(REGION)" = "seoul" ]; then \
		AWS_REGION=$(AWS_REGION_SEOUL); \
	elif [ "$(REGION)" = "tokyo" ]; then \
		AWS_REGION=$(AWS_REGION_TOKYO); \
	else \
		echo "$(RED)Invalid REGION. Use seoul or tokyo$(NC)"; \
		exit 1; \
	fi; \
	echo "$(BLUE)Logging into ECR ($$AWS_REGION)...$(NC)"; \
	aws ecr get-login-password --region $$AWS_REGION | \
		docker login --username AWS --password-stdin \
		$$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$$AWS_REGION.amazonaws.com; \
	echo "$(GREEN)✓ ECR login successful$(NC)"

# ============================================================================
# Cluster Context Switching
# ============================================================================
use-seoul: ## Switch kubectl context to Seoul
	@echo "$(BLUE)Switching to Seoul cluster...$(NC)"
	@CLUSTER=$$(cd $(SEOUL_DIR) && terraform output -raw eks_cluster_name 2>/dev/null); \
	aws eks update-kubeconfig --region $(AWS_REGION_SEOUL) --name $$CLUSTER
	@echo "$(GREEN)✓ Now using Seoul cluster$(NC)"

use-tokyo: ## Switch kubectl context to Tokyo
	@echo "$(BLUE)Switching to Tokyo cluster...$(NC)"
	@CLUSTER=$$(cd $(TOKYO_DIR) && terraform output -raw eks_cluster_name 2>/dev/null); \
	aws eks update-kubeconfig --region $(AWS_REGION_TOKYO) --name $$CLUSTER
	@echo "$(GREEN)✓ Now using Tokyo cluster$(NC)"

use-dev: ## Switch kubectl context to Dev
	@echo "$(BLUE)Switching to Dev cluster...$(NC)"
	@CLUSTER=$$(cd $(DEV_DIR) && terraform output -raw eks_cluster_name 2>/dev/null); \
	aws eks update-kubeconfig --region $(AWS_REGION_SEOUL) --name $$CLUSTER
	@echo "$(GREEN)✓ Now using Dev cluster$(NC)"

# ============================================================================
# Status & Monitoring
# ============================================================================
status: ## Show overall infrastructure status
	@echo "$(BLUE)╔══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║               Infrastructure Status Overview                      ║$(NC)"
	@echo "$(BLUE)╚══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)=== Development ===$(NC)"
	@cd $(DEV_DIR) && terraform show -no-color 2>/dev/null | head -20 || echo "Not initialized"
	@echo ""
	@echo "$(GREEN)=== Seoul (Production) ===$(NC)"
	@cd $(SEOUL_DIR) && terraform show -no-color 2>/dev/null | head -20 || echo "Not initialized"
	@echo ""
	@echo "$(GREEN)=== Tokyo (DR) ===$(NC)"
	@cd $(TOKYO_DIR) && terraform show -no-color 2>/dev/null | head -20 || echo "Not initialized"

# ============================================================================
# All Environments
# ============================================================================
all-init: dev-init seoul-init tokyo-init ## Initialize all environments

all-plan: ## Plan all environments
	@echo "$(BLUE)Planning all environments...$(NC)"
	@$(MAKE) dev-plan
	@$(MAKE) seoul-plan
	@$(MAKE) tokyo-plan

all-fmt: fmt ## Alias for fmt
