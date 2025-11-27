# ============================================================================
# Ansible Makefile - Velero DR Operations
# ============================================================================

.PHONY: help install backup restore uninstall dr-failover dr-test \
        seoul-install seoul-backup tokyo-install tokyo-restore \
        phz-tokyo phz-seoul phz-verify \
        clean clean-seoul clean-tokyo clean-all \
        delete-backup delete-all-backups delete-restore delete-all-restores \
        lint check deps

# Colors
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m

# Defaults
ANSIBLE_DIR := $(shell pwd)
PLAYBOOK_DIR := $(ANSIBLE_DIR)/playbooks

# ============================================================================
# Help
# ============================================================================
help: ## Show this help
	@echo "$(BLUE)╔══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║              Velero DR Ansible Operations                        ║$(NC)"
	@echo "$(BLUE)╚══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)Setup:$(NC)"
	@echo "  make deps              Install Ansible dependencies"
	@echo "  make check             Verify Ansible and dependencies"
	@echo "  make lint              Lint playbooks"
	@echo ""
	@echo "$(GREEN)All Clusters (권장):$(NC)"
	@echo "  make install           Seoul & Tokyo 동시 설치"
	@echo "  make uninstall         Seoul & Tokyo 동시 삭제"
	@echo ""
	@echo "$(GREEN)Seoul (Primary) Operations:$(NC)"
	@echo "  make seoul-install     Install Velero on Seoul cluster"
	@echo "  make seoul-backup      Create backup (all namespaces)"
	@echo "  make seoul-backup NAME=my-backup  Create named backup"
	@echo "  make seoul-backup NS=ticketing    Create namespace backup"
	@echo "  make seoul-backup-full NAME=full  Create full cluster backup"
	@echo "  make seoul-uninstall   Uninstall Velero from Seoul"
	@echo ""
	@echo "$(GREEN)Tokyo (DR) Operations:$(NC)"
	@echo "  make tokyo-install     Install Velero on Tokyo cluster"
	@echo "  make tokyo-restore BACKUP=name       Restore backup to Tokyo"
	@echo "  make tokyo-restore-full BACKUP=name  Restore + PHZ update"
	@echo "  make tokyo-uninstall   Uninstall Velero from Tokyo"
	@echo ""
	@echo "$(GREEN)DR Operations:$(NC)"
	@echo "  make dr-status         Show comprehensive DR status dashboard"
	@echo "  make dr-failover BACKUP=name    Full DR failover to Tokyo"
	@echo "  make dr-failover-auto BACKUP=name  DR failover (no prompts)"
	@echo "  make dr-failback       Full failback to Seoul (backup+restore+DNS)"
	@echo "  make dr-failback-rds   Full failback with RDS snapshot"
	@echo "  make dr-failback-dns-only  Quick failback (DNS only)"
	@echo "  make tokyo-cleanup     Clean up Tokyo resources (delete namespace)"
	@echo "  make dr-test           Run full DR test scenario"
	@echo ""
	@echo "$(GREEN)PHZ (DNS) Operations:$(NC)"
	@echo "  make phz-tokyo         Switch DNS to Tokyo endpoints"
	@echo "  make phz-seoul         Switch DNS to Seoul endpoints (rollback)"
	@echo "  make phz-verify        Verify current PHZ DNS records"
	@echo ""
	@echo "$(GREEN)RDS Snapshot Operations:$(NC)"
	@echo "  make rds-snapshot NAME=name       Create RDS snapshot in Seoul"
	@echo "  make rds-snapshot-copy NAME=name  Create snapshot + copy to Tokyo"
	@echo "  make rds-copy-tokyo SNAPSHOT=name Copy existing snapshot to Tokyo"
	@echo "  make rds-restore-tokyo SNAPSHOT=name  Restore snapshot in Tokyo"
	@echo "  make rds-list-snapshots           List all RDS snapshots"
	@echo ""
	@echo "$(GREEN)Examples:$(NC)"
	@echo "  make install                     # 양쪽 클러스터에 Velero 설치"
	@echo "  make seoul-backup NAME=daily     # Seoul에서 백업"
	@echo "  make tokyo-restore BACKUP=daily  # Tokyo에서 복구"
	@echo "  make uninstall                   # 양쪽 클러스터에서 Velero 삭제"
	@echo ""

# ============================================================================
# All Clusters Operations
# ============================================================================
install: ## Install Velero on Seoul & Tokyo simultaneously
	@echo "$(BLUE)Installing Velero on all clusters...$(NC)"
	ansible-playbook $(PLAYBOOK_DIR)/velero-install-all.yml

uninstall: ## Uninstall Velero from Seoul & Tokyo
	@echo "$(YELLOW)Uninstalling Velero from all clusters...$(NC)"
	ansible-playbook $(PLAYBOOK_DIR)/velero-uninstall-all.yml

uninstall-auto: ## Uninstall without confirmation
	ansible-playbook $(PLAYBOOK_DIR)/velero-uninstall-all.yml -e "auto_confirm=true"

# ============================================================================
# Setup & Validation
# ============================================================================
deps: ## Install Ansible dependencies
	@echo "$(BLUE)Installing Ansible collections...$(NC)"
	ansible-galaxy collection install kubernetes.core --force
	ansible-galaxy collection install amazon.aws --force
	@echo "$(GREEN)✓ Dependencies installed$(NC)"

check: ## Verify Ansible and dependencies
	@echo "$(BLUE)Checking prerequisites...$(NC)"
	@command -v ansible >/dev/null 2>&1 || { echo "$(RED)✗ ansible not found$(NC)"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "$(RED)✗ kubectl not found$(NC)"; exit 1; }
	@command -v velero >/dev/null 2>&1 || { echo "$(YELLOW)⚠ velero CLI not found (optional for some operations)$(NC)"; }
	@command -v aws >/dev/null 2>&1 || { echo "$(RED)✗ aws CLI not found$(NC)"; exit 1; }
	@echo "$(GREEN)✓ All prerequisites met$(NC)"
	@echo ""
	@echo "Ansible version:"
	@ansible --version | head -1
	@echo ""
	@echo "Installed collections:"
	@ansible-galaxy collection list | grep -E "kubernetes|amazon" || echo "No relevant collections found"

lint: ## Lint playbooks
	@echo "$(BLUE)Linting playbooks...$(NC)"
	@command -v ansible-lint >/dev/null 2>&1 && ansible-lint playbooks/*.yml || echo "$(YELLOW)ansible-lint not installed, skipping$(NC)"

# ============================================================================
# Seoul Operations
# ============================================================================
seoul-install: ## Install Velero on Seoul cluster
	@echo "$(BLUE)Installing Velero on Seoul...$(NC)"
	ansible-playbook $(PLAYBOOK_DIR)/velero-install.yml -e "target=seoul"

seoul-backup: ## Create backup on Seoul (NAME=backup-name, NS=namespace)
	@echo "$(BLUE)Creating backup on Seoul...$(NC)"
ifdef NS
ifdef NAME
	ansible-playbook $(PLAYBOOK_DIR)/velero-backup.yml -e "target=seoul backup_name=$(NAME) backup_namespaces=['$(NS)']"
else
	ansible-playbook $(PLAYBOOK_DIR)/velero-backup.yml -e "target=seoul backup_namespaces=['$(NS)']"
endif
else ifdef NAME
	ansible-playbook $(PLAYBOOK_DIR)/velero-backup.yml -e "target=seoul backup_name=$(NAME)"
else
	ansible-playbook $(PLAYBOOK_DIR)/velero-backup.yml -e "target=seoul"
endif

seoul-backup-full: ## Create full cluster backup on Seoul (NAME=backup-name)
	@echo "$(BLUE)Creating FULL backup on Seoul (all namespaces)...$(NC)"
ifdef NAME
	ansible-playbook $(PLAYBOOK_DIR)/velero-backup.yml -e "target=seoul backup_name=$(NAME)"
else
	ansible-playbook $(PLAYBOOK_DIR)/velero-backup.yml -e "target=seoul backup_name=full-backup-$$(date +%Y%m%d-%H%M%S)"
endif

seoul-uninstall: ## Uninstall Velero from Seoul
	@echo "$(YELLOW)Uninstalling Velero from Seoul...$(NC)"
	ansible-playbook $(PLAYBOOK_DIR)/velero-uninstall.yml -e "target=seoul"

# ============================================================================
# Tokyo Operations
# ============================================================================
tokyo-install: ## Install Velero on Tokyo cluster
	@echo "$(BLUE)Installing Velero on Tokyo...$(NC)"
	ansible-playbook $(PLAYBOOK_DIR)/velero-install.yml -e "target=tokyo"

tokyo-restore: ## Restore backup to Tokyo (BACKUP=name required)
ifndef BACKUP
	@echo "$(RED)Error: BACKUP is required$(NC)"
	@echo "Usage: make tokyo-restore BACKUP=backup-name"
	@exit 1
endif
	@echo "$(BLUE)Restoring '$(BACKUP)' to Tokyo...$(NC)"
	@DIGEST_FILE="$(ANSIBLE_DIR)/image-digests-$(BACKUP).yml"; \
	if [ -f "$$DIGEST_FILE" ]; then \
		echo "$(GREEN)Found image digests file: $$DIGEST_FILE$(NC)"; \
		ansible-playbook $(PLAYBOOK_DIR)/velero-restore.yml -e "target=tokyo backup_name=$(BACKUP)" -e "@$$DIGEST_FILE"; \
	else \
		echo "$(YELLOW)Warning: No digest file found at $$DIGEST_FILE$(NC)"; \
		echo "$(YELLOW)Restoring without image digest pinning...$(NC)"; \
		ansible-playbook $(PLAYBOOK_DIR)/velero-restore.yml -e "target=tokyo backup_name=$(BACKUP)"; \
	fi

tokyo-restore-full: ## Restore full backup to Tokyo with PHZ update (BACKUP=name required)
ifndef BACKUP
	@echo "$(RED)Error: BACKUP is required$(NC)"
	@echo "Usage: make tokyo-restore-full BACKUP=backup-name"
	@exit 1
endif
	@echo "$(BLUE)Restoring '$(BACKUP)' to Tokyo...$(NC)"
	@DIGEST_FILE="$(ANSIBLE_DIR)/image-digests-$(BACKUP).yml"; \
	if [ -f "$$DIGEST_FILE" ]; then \
		echo "$(GREEN)Found image digests file: $$DIGEST_FILE$(NC)"; \
		ansible-playbook $(PLAYBOOK_DIR)/velero-restore.yml -e "target=tokyo backup_name=$(BACKUP)" -e "@$$DIGEST_FILE"; \
	else \
		echo "$(YELLOW)Warning: No digest file found at $$DIGEST_FILE$(NC)"; \
		ansible-playbook $(PLAYBOOK_DIR)/velero-restore.yml -e "target=tokyo backup_name=$(BACKUP)"; \
	fi
	@echo "$(BLUE)Updating PHZ DNS to Tokyo endpoints...$(NC)"
	ansible-playbook $(PLAYBOOK_DIR)/phz-update.yml -e "target_region=tokyo auto_confirm=true"

tokyo-uninstall: ## Uninstall Velero from Tokyo
	@echo "$(YELLOW)Uninstalling Velero from Tokyo...$(NC)"
	ansible-playbook $(PLAYBOOK_DIR)/velero-uninstall.yml -e "target=tokyo"

# ============================================================================
# DR Operations
# ============================================================================
dr-failover: ## Full DR failover to Tokyo (BACKUP=name required)
ifndef BACKUP
	@echo "$(RED)Error: BACKUP is required$(NC)"
	@echo "Usage: make dr-failover BACKUP=backup-name"
	@exit 1
endif
	@echo "$(RED)╔══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(RED)║                    DR FAILOVER                                   ║$(NC)"
	@echo "$(RED)╚══════════════════════════════════════════════════════════════════╝$(NC)"
	ansible-playbook $(PLAYBOOK_DIR)/dr-failover.yml -e "backup_name=$(BACKUP)"

dr-failover-auto: ## DR failover without prompts (BACKUP=name required)
ifndef BACKUP
	@echo "$(RED)Error: BACKUP is required$(NC)"
	@exit 1
endif
	ansible-playbook $(PLAYBOOK_DIR)/dr-failover.yml -e "backup_name=$(BACKUP) auto_confirm=true"

dr-failover-cleanup: ## DR failover with cleanup after restore (BACKUP=name required)
ifndef BACKUP
	@echo "$(RED)Error: BACKUP is required$(NC)"
	@exit 1
endif
	ansible-playbook $(PLAYBOOK_DIR)/dr-failover.yml \
		-e "backup_name=$(BACKUP) cleanup_after_restore=true auto_confirm=true"

dr-test: ## Run full DR test scenario
	@echo "$(BLUE)Running DR test scenario...$(NC)"
	ansible-playbook $(PLAYBOOK_DIR)/dr-test.yml

dr-test-no-cleanup: ## Run DR test without cleanup
	ansible-playbook $(PLAYBOOK_DIR)/dr-test.yml -e "cleanup_all=false"

dr-failback: ## Full failback from Tokyo to Seoul (backup Tokyo → restore Seoul → switch DNS)
	@echo "$(GREEN)╔══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║                    DR FAILBACK TO SEOUL                          ║$(NC)"
	@echo "$(GREEN)╚══════════════════════════════════════════════════════════════════╝$(NC)"
	ansible-playbook $(PLAYBOOK_DIR)/dr-failback.yml

dr-failback-auto: ## Full failback without prompts
	ansible-playbook $(PLAYBOOK_DIR)/dr-failback.yml -e "auto_confirm=true"

dr-failback-rds: ## Full failback with RDS snapshot (backup+restore+RDS+DNS)
	@echo "$(GREEN)╔══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║           DR FAILBACK TO SEOUL (WITH RDS)                        ║$(NC)"
	@echo "$(GREEN)╚══════════════════════════════════════════════════════════════════╝$(NC)"
	ansible-playbook $(PLAYBOOK_DIR)/dr-failback.yml -e "include_rds=true"

dr-failback-rds-auto: ## Full failback with RDS (no prompts)
	ansible-playbook $(PLAYBOOK_DIR)/dr-failback.yml -e "include_rds=true auto_confirm=true"

dr-failback-dns-only: ## Quick failback (DNS only, no data sync)
	@echo "$(YELLOW)Switching DNS to Seoul (no data sync)...$(NC)"
	@echo "$(YELLOW)Warning: Use this only if Seoul data is already up-to-date$(NC)"
	@read -p "Proceed? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@aws eks update-kubeconfig --region ap-northeast-2 --name ddcn41-eks-cluster --quiet
	@$(MAKE) phz-seoul-auto
	@echo "$(GREEN)✓ DNS switched to Seoul$(NC)"

tokyo-cleanup: ## Clean up Tokyo DR resources (delete ticketing namespace)
	@echo "$(RED)╔══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(RED)║              ⚠️  TOKYO RESOURCE CLEANUP                           ║$(NC)"
	@echo "$(RED)╚══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo "$(YELLOW)This will delete the ticketing namespace in Tokyo cluster$(NC)"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@aws eks update-kubeconfig --region ap-northeast-1 --name ddcn41-eks-cluster > /dev/null 2>&1
	@echo "$(YELLOW)Deleting ticketing namespace in Tokyo...$(NC)"
	@kubectl delete namespace ticketing --ignore-not-found --wait=true
	@echo "$(GREEN)✓ Tokyo ticketing namespace deleted$(NC)"
	@kubectl get namespaces
	@aws eks update-kubeconfig --region ap-northeast-2 --name ddcn41-eks-cluster > /dev/null 2>&1

tokyo-cleanup-auto: ## Clean up Tokyo resources (no prompts)
	@aws eks update-kubeconfig --region ap-northeast-1 --name ddcn41-eks-cluster > /dev/null 2>&1
	@kubectl delete namespace ticketing --ignore-not-found --wait=true
	@aws eks update-kubeconfig --region ap-northeast-2 --name ddcn41-eks-cluster > /dev/null 2>&1

# ============================================================================
# PHZ (DNS) Operations
# ============================================================================
phz-tokyo: ## Switch PHZ DNS to Tokyo endpoints
	@echo "$(BLUE)Switching DNS to Tokyo endpoints...$(NC)"
	ansible-playbook $(PLAYBOOK_DIR)/phz-update.yml -e "target_region=tokyo"

phz-tokyo-auto: ## Switch PHZ DNS to Tokyo (no prompts)
	ansible-playbook $(PLAYBOOK_DIR)/phz-update.yml -e "target_region=tokyo auto_confirm=true"

phz-seoul: ## Switch PHZ DNS to Seoul endpoints (rollback)
	@echo "$(BLUE)Switching DNS to Seoul endpoints...$(NC)"
	ansible-playbook $(PLAYBOOK_DIR)/phz-update.yml -e "target_region=seoul"

phz-seoul-auto: ## Switch PHZ DNS to Seoul (no prompts)
	ansible-playbook $(PLAYBOOK_DIR)/phz-update.yml -e "target_region=seoul auto_confirm=true"

phz-verify: ## Verify current PHZ DNS records
	@echo "$(BLUE)Verifying PHZ DNS records...$(NC)"
	@echo "$(YELLOW)Note: PHZ Zone is managed by Seoul. Fetching from Seoul terraform output.$(NC)"
	@PHZ_ZONE_ID=$$(terraform -chdir=$(ANSIBLE_DIR)/../infrastructure/environments/seoul output -raw phz_zone_id 2>/dev/null || echo ""); \
	if [ -n "$$PHZ_ZONE_ID" ]; then \
		echo "Zone ID: $$PHZ_ZONE_ID"; \
		echo ""; \
		echo "RDS Record:"; \
		aws route53 list-resource-record-sets --hosted-zone-id $$PHZ_ZONE_ID \
			--query "ResourceRecordSets[?Name=='db.ddcn41-eks.internal.']" --output table; \
		echo ""; \
		echo "Redis Record:"; \
		aws route53 list-resource-record-sets --hosted-zone-id $$PHZ_ZONE_ID \
			--query "ResourceRecordSets[?Name=='redis.ddcn41-eks.internal.']" --output table; \
	else \
		echo "$(RED)PHZ Zone ID not found. Run 'terraform apply' on Seoul first.$(NC)"; \
	fi

# ============================================================================
# RDS Snapshot Operations
# ============================================================================
rds-snapshot: ## Create RDS snapshot in Seoul (NAME=name optional)
	@echo "$(BLUE)Creating RDS snapshot in Seoul...$(NC)"
ifdef NAME
	ansible-playbook $(PLAYBOOK_DIR)/rds-backup.yml -e "snapshot_name=$(NAME)"
else
	ansible-playbook $(PLAYBOOK_DIR)/rds-backup.yml
endif

rds-snapshot-copy: ## Create RDS snapshot and copy to Tokyo (NAME=name optional)
	@echo "$(BLUE)Creating RDS snapshot and copying to Tokyo...$(NC)"
ifdef NAME
	ansible-playbook $(PLAYBOOK_DIR)/rds-backup.yml -e "snapshot_name=$(NAME) copy_to_tokyo=true"
else
	ansible-playbook $(PLAYBOOK_DIR)/rds-backup.yml -e "copy_to_tokyo=true"
endif

rds-copy-tokyo: ## Copy existing snapshot to Tokyo (SNAPSHOT=name required)
ifndef SNAPSHOT
	@echo "$(RED)Error: SNAPSHOT is required$(NC)"
	@echo "Usage: make rds-copy-tokyo SNAPSHOT=snapshot-name"
	@exit 1
endif
	@echo "$(BLUE)Copying snapshot '$(SNAPSHOT)' to Tokyo...$(NC)"
	ansible-playbook $(PLAYBOOK_DIR)/rds-backup.yml -e "snapshot_name=$(SNAPSHOT) copy_to_tokyo=true skip_snapshot=true"

rds-restore-tokyo: ## Restore RDS from snapshot in Tokyo (SNAPSHOT=name required)
ifndef SNAPSHOT
	@echo "$(RED)Error: SNAPSHOT is required$(NC)"
	@echo "Usage: make rds-restore-tokyo SNAPSHOT=snapshot-name"
	@echo ""
	@echo "List available snapshots:"
	@echo "  make rds-list-snapshots"
	@exit 1
endif
	@echo "$(BLUE)Restoring RDS from snapshot '$(SNAPSHOT)' in Tokyo...$(NC)"
	ansible-playbook $(PLAYBOOK_DIR)/rds-restore.yml -e "snapshot_name=$(SNAPSHOT)"

rds-list-snapshots: ## List all RDS snapshots (Seoul and Tokyo)
	@echo "$(BLUE)Listing RDS snapshots...$(NC)"
	@echo ""
	@echo "$(GREEN)═══ Seoul Snapshots ═══$(NC)"
	@aws rds describe-db-snapshots \
		--db-instance-identifier ddcn41-eks-db \
		--region ap-northeast-2 \
		--query 'DBSnapshots[*].{Name:DBSnapshotIdentifier,Status:Status,Created:SnapshotCreateTime}' \
		--output table 2>/dev/null || echo "No snapshots found"
	@echo ""
	@echo "$(GREEN)═══ Tokyo Snapshots ═══$(NC)"
	@aws rds describe-db-snapshots \
		--region ap-northeast-1 \
		--query 'DBSnapshots[?contains(DBSnapshotIdentifier, `dr-`) || contains(DBSnapshotIdentifier, `ddcn41`)].{Name:DBSnapshotIdentifier,Status:Status,Created:SnapshotCreateTime}' \
		--output table 2>/dev/null || echo "No snapshots found"

# ============================================================================
# Cleanup Operations (실패한 설치 정리)
# ============================================================================
clean: ## Force cleanup failed Velero installation (current cluster)
	@echo "$(YELLOW)Force cleaning Velero from current cluster...$(NC)"
	helm uninstall velero -n velero 2>/dev/null || true
	kubectl delete namespace velero --ignore-not-found --wait=false
	kubectl delete namespace velero --force --grace-period=0 2>/dev/null || true
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

clean-seoul: ## Force cleanup Velero from Seoul
	@echo "$(YELLOW)Force cleaning Velero from Seoul...$(NC)"
	aws eks update-kubeconfig --region ap-northeast-2 --name ddcn41-eks-cluster
	helm uninstall velero -n velero 2>/dev/null || true
	kubectl delete namespace velero --ignore-not-found --wait=false
	kubectl delete namespace velero --force --grace-period=0 2>/dev/null || true
	@echo "$(GREEN)✓ Seoul cleanup complete$(NC)"

clean-tokyo: ## Force cleanup Velero from Tokyo
	@echo "$(YELLOW)Force cleaning Velero from Tokyo...$(NC)"
	aws eks update-kubeconfig --region ap-northeast-1 --name ddcn41-eks-cluster
	helm uninstall velero -n velero 2>/dev/null || true
	kubectl delete namespace velero --ignore-not-found --wait=false
	kubectl delete namespace velero --force --grace-period=0 2>/dev/null || true
	@echo "$(GREEN)✓ Tokyo cleanup complete$(NC)"

clean-all: clean-seoul clean-tokyo ## Force cleanup Velero from both clusters
	@echo "$(GREEN)✓ All clusters cleaned$(NC)"

# ============================================================================
# Status & Monitoring Operations
# ============================================================================
dr-status: ## Show comprehensive DR status (both clusters, DNS, services)
	@echo "$(BLUE)╔══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║                    DR STATUS DASHBOARD                           ║$(NC)"
	@echo "$(BLUE)╚══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)═══ PHZ DNS Status ═══$(NC)"
	@PHZ_ZONE_ID=$$(terraform -chdir=$(ANSIBLE_DIR)/../infrastructure/environments/seoul output -raw phz_zone_id 2>/dev/null || echo ""); \
	if [ -n "$$PHZ_ZONE_ID" ]; then \
		RDS_TARGET=$$(aws route53 list-resource-record-sets --hosted-zone-id $$PHZ_ZONE_ID \
			--query "ResourceRecordSets[?Name=='db.ddcn41-eks.internal.'].ResourceRecords[0].Value" --output text 2>/dev/null); \
		if echo "$$RDS_TARGET" | grep -q "ap-northeast-1"; then \
			echo "  Current Target: $(RED)TOKYO (DR Mode)$(NC)"; \
		else \
			echo "  Current Target: $(GREEN)SEOUL (Normal)$(NC)"; \
		fi; \
		echo "  RDS Endpoint:   $$RDS_TARGET"; \
	else \
		echo "  $(YELLOW)PHZ not configured$(NC)"; \
	fi
	@echo ""
	@echo "$(GREEN)═══ Seoul Cluster ═══$(NC)"
	@aws eks update-kubeconfig --region ap-northeast-2 --name ddcn41-eks-cluster 2>/dev/null; \
	if kubectl get nodes --no-headers 2>/dev/null | head -1 > /dev/null; then \
		echo "  Status: $(GREEN)Connected$(NC)"; \
		echo "  Nodes:  $$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ') ready"; \
		echo "  Pods:   $$(kubectl get pods -n ticketing --no-headers 2>/dev/null | grep -c Running || echo 0) running in ticketing"; \
	else \
		echo "  Status: $(RED)Not accessible$(NC)"; \
	fi
	@echo ""
	@echo "$(GREEN)═══ Tokyo Cluster ═══$(NC)"
	@aws eks update-kubeconfig --region ap-northeast-1 --name ddcn41-eks-cluster 2>/dev/null; \
	if kubectl get nodes --no-headers 2>/dev/null | head -1 > /dev/null; then \
		echo "  Status: $(GREEN)Connected$(NC)"; \
		echo "  Nodes:  $$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ') ready"; \
		echo "  Pods:   $$(kubectl get pods -n ticketing --no-headers 2>/dev/null | grep -c Running || echo 0) running in ticketing"; \
	else \
		echo "  Status: $(RED)Not accessible$(NC)"; \
	fi
	@echo ""
	@echo "$(GREEN)═══ Recent Velero Backups (Tokyo) ═══$(NC)"
	@velero backup get --sort-by=.metadata.creationTimestamp 2>/dev/null | tail -5 || echo "  No backups found"
	@echo ""

status: ## Show Velero status on current cluster
	@echo "$(BLUE)Velero Status:$(NC)"
	@velero version 2>/dev/null || echo "Velero not installed or not connected"
	@echo ""
	@echo "$(BLUE)Backup Locations:$(NC)"
	@velero backup-location get 2>/dev/null || echo "N/A"
	@echo ""
	@echo "$(BLUE)Recent Backups:$(NC)"
	@velero backup get 2>/dev/null || echo "N/A"

backups: ## List all backups
	@velero backup get

restores: ## List all restores
	@velero restore get

delete-backup: ## Delete specific backup (NAME required)
ifndef NAME
	@echo "$(RED)Error: NAME is required$(NC)"
	@echo "Usage: make delete-backup NAME=backup-name"
	@exit 1
endif
	@echo "$(YELLOW)Deleting backup '$(NAME)'...$(NC)"
	velero backup delete $(NAME) --confirm
	@echo "$(GREEN)✓ Backup '$(NAME)' deleted$(NC)"

delete-all-backups: ## Delete all backups from current cluster
	@echo "$(RED)WARNING: This will delete ALL backups from the current cluster!$(NC)"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	velero backup delete --all --confirm
	@echo "$(GREEN)✓ All backups deleted$(NC)"

delete-restore: ## Delete specific restore (NAME required)
ifndef NAME
	@echo "$(RED)Error: NAME is required$(NC)"
	@echo "Usage: make delete-restore NAME=restore-name"
	@exit 1
endif
	@echo "$(YELLOW)Deleting restore '$(NAME)'...$(NC)"
	velero restore delete $(NAME) --confirm
	@echo "$(GREEN)✓ Restore '$(NAME)' deleted$(NC)"

delete-all-restores: ## Delete all restores from current cluster
	@echo "$(YELLOW)Deleting all restores...$(NC)"
	velero restore delete --all --confirm
	@echo "$(GREEN)✓ All restores deleted$(NC)"

# ============================================================================
# Quick Commands
# ============================================================================
quick-backup: seoul-backup ## Alias for seoul-backup

quick-restore: ## Quick restore (BACKUP required)
ifndef BACKUP
	@echo "$(RED)Error: BACKUP is required$(NC)"
	@exit 1
endif
	@$(MAKE) tokyo-install
	@$(MAKE) tokyo-restore BACKUP=$(BACKUP)
