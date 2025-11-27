# Ticketing Chart Makefile
# Usage: make [target]

NAMESPACE := ticketing
RELEASE_NAME := ticketing
CHART_DIR := .

# Secrets (override with environment variables if needed)
DB_PASSWORD ?= Password!23
JWT_SECRET ?= supersecretjwtkey12345678901234567890

# EKS Cluster Info
# terraform output: eks_cluster_name = "ddcn41-eks-cluster"
# Usage: make [target] REGION=ap-northeast-1  (for Tokyo)
CLUSTER_NAME := ddcn41-eks-cluster
REGION ?= ap-northeast-2

# NGINX Ingress Controller
INGRESS_NAMESPACE := ingress-nginx
INGRESS_RELEASE := ingress-nginx

.PHONY: help config kubeconfig install upgrade uninstall status logs template dry-run ingress-install ingress-uninstall setup reset-db dump-db clean-db backup backup-status backup-sync restore \
	velero-install velero-uninstall velero-status

help:
	@echo "Ticketing Chart Management"
	@echo ""
	@echo "Usage: make [target] [REGION=ap-northeast-1|ap-northeast-2]"
	@echo ""
	@echo "Regions:"
	@echo "  ap-northeast-2  - Seoul (Primary, default)"
	@echo "  ap-northeast-1  - Tokyo (DR)"
	@echo ""
	@echo "Targets:"
	@echo "  setup           - Full setup: NGINX Ingress + Ticketing app (recommended for first deploy)"
	@echo "  config          - Configure kubectl for EKS cluster (alias: kubeconfig)"
	@echo "  ingress-install - Install NGINX Ingress Controller"
	@echo "  ingress-uninstall - Uninstall NGINX Ingress Controller"
	@echo "  install         - Install the Helm chart"
	@echo "  upgrade         - Upgrade the Helm release"
	@echo "  uninstall       - Uninstall the Helm release"
	@echo "  uninstall-all   - Uninstall Ticketing + NGINX Ingress"
	@echo "  status          - Show release status and pods"
	@echo "  logs            - Show logs for all pods"
	@echo "  template        - Render templates locally"
	@echo "  dry-run         - Simulate install without deploying"
	@echo "  reset-db        - Reset database to snapshot state"
	@echo "  dump-db         - Create database dump (db-snapshot.sql)"
	@echo "  clean-db        - Drop all tables (empty database)"
	@echo ""
	@echo "Velero (Simple Operations):"
	@echo "  velero-install  - Install Velero with AWS plugin"
	@echo "  velero-uninstall - Uninstall Velero"
	@echo "  velero-status   - Show Velero status"
	@echo "  backup          - Create Velero backup (full cluster, excludes kube-system/velero)"
	@echo "  backup-status   - Show recent backups"
	@echo "  backup-sync     - Sync backup list from S3 (for cross-region DR)"
	@echo "  restore         - Restore from backup (usage: make restore FROM=<backup-name>)"
	@echo ""
	@echo "DR Workflow (use ansible/Makefile instead):"
	@echo "  cd ../ansible && make help"

config: kubeconfig
kubeconfig:
	@echo "Configuring kubeconfig for $(CLUSTER_NAME)..."
	aws eks update-kubeconfig --name $(CLUSTER_NAME) --region $(REGION)
	@echo ""
	@echo "Current context:"
	@kubectl config current-context
	@echo ""
	@echo "Cluster nodes:"
	@kubectl get nodes

install: kubeconfig
	@echo "Installing $(RELEASE_NAME) in namespace $(NAMESPACE)..."
	helm install $(RELEASE_NAME) $(CHART_DIR) \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--set global.env.SPRING_DATASOURCE_PASSWORD=$(DB_PASSWORD) \
		--set global.env.JWT_SECRET=$(JWT_SECRET)
	@echo ""
	@echo "Waiting for pods to be ready..."
	kubectl wait --for=condition=ready pod -l app=ticketing-api -n $(NAMESPACE) --timeout=300s || true
	@$(MAKE) status

upgrade: kubeconfig
	@echo "Upgrading $(RELEASE_NAME)..."
	helm upgrade $(RELEASE_NAME) $(CHART_DIR) \
		--namespace $(NAMESPACE) \
		--set global.env.SPRING_DATASOURCE_PASSWORD=$(DB_PASSWORD) \
		--set global.env.JWT_SECRET=$(JWT_SECRET)
	@$(MAKE) status

uninstall: kubeconfig
	@echo "Uninstalling $(RELEASE_NAME)..."
	helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE) || true
	@echo "Deleting namespace $(NAMESPACE)..."
	kubectl delete namespace $(NAMESPACE) --ignore-not-found
	@echo "Uninstall complete."

status: kubeconfig
	@echo ""
	@echo "=== Helm Release Status ==="
	helm status $(RELEASE_NAME) -n $(NAMESPACE) 2>/dev/null || echo "Release not found"
	@echo ""
	@echo "=== Pods ==="
	kubectl get pods -n $(NAMESPACE) -o wide 2>/dev/null || echo "Namespace not found"
	@echo ""
	@echo "=== Services ==="
	kubectl get svc -n $(NAMESPACE) 2>/dev/null || echo "Namespace not found"
	@echo ""
	@echo "=== Ingress ==="
	kubectl get ingress -n $(NAMESPACE) 2>/dev/null || echo "No ingress found"

logs:
	@echo "=== API Logs ==="
	kubectl logs -l app=ticketing-api -n $(NAMESPACE) --tail=50 2>/dev/null || true
	@echo ""
	@echo "=== Admin Logs ==="
	kubectl logs -l app=ticketing-admin -n $(NAMESPACE) --tail=50 2>/dev/null || true
	@echo ""
	@echo "=== Queue Logs ==="
	kubectl logs -l app=ticketing-queue -n $(NAMESPACE) --tail=50 2>/dev/null || true

logs-api:
	kubectl logs -l app=ticketing-api -n $(NAMESPACE) -f

logs-admin:
	kubectl logs -l app=ticketing-admin -n $(NAMESPACE) -f

logs-queue:
	kubectl logs -l app=ticketing-queue -n $(NAMESPACE) -f

template:
	@echo "Rendering templates..."
	helm template $(RELEASE_NAME) $(CHART_DIR) \
		--namespace $(NAMESPACE) \
		--set global.env.SPRING_DATASOURCE_PASSWORD=$(DB_PASSWORD) \
		--set global.env.JWT_SECRET=$(JWT_SECRET)

dry-run: kubeconfig
	@echo "Dry-run install..."
	helm install $(RELEASE_NAME) $(CHART_DIR) \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--set global.env.SPRING_DATASOURCE_PASSWORD=$(DB_PASSWORD) \
		--set global.env.JWT_SECRET=$(JWT_SECRET) \
		--dry-run --debug

restart:
	@echo "Restarting all deployments..."
	kubectl rollout restart deployment -n $(NAMESPACE)
	@$(MAKE) status

# ============================================================================
# NGINX Ingress Controller
# ============================================================================
ingress-install: kubeconfig
	@echo "Adding ingress-nginx helm repo..."
	@helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
	@helm repo update
	@echo ""
	@echo "Installing NGINX Ingress Controller..."
	helm install $(INGRESS_RELEASE) ingress-nginx/ingress-nginx \
		--namespace $(INGRESS_NAMESPACE) \
		--create-namespace \
		--set controller.service.type=LoadBalancer \
		--set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"=nlb \
		--set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"=internet-facing \
		--wait --timeout 300s
	@echo ""
	@echo "=== NLB Endpoint ==="
	@kubectl get svc -n $(INGRESS_NAMESPACE) $(INGRESS_RELEASE)-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
	@echo ""

ingress-uninstall: kubeconfig
	@echo "Uninstalling NGINX Ingress Controller..."
	helm uninstall $(INGRESS_RELEASE) --namespace $(INGRESS_NAMESPACE) || true
	kubectl delete namespace $(INGRESS_NAMESPACE) --ignore-not-found
	@echo "NGINX Ingress Controller uninstalled."

ingress-status: kubeconfig
	@echo "=== NGINX Ingress Controller Status ==="
	@kubectl get svc -n $(INGRESS_NAMESPACE) $(INGRESS_RELEASE)-controller 2>/dev/null || echo "Not installed"
	@echo ""
	@echo "=== IngressClass ==="
	@kubectl get ingressclass 2>/dev/null || echo "No IngressClass found"

# ============================================================================
# Full Setup / Teardown
# ============================================================================
setup: kubeconfig ingress-install install
	@echo ""
	@echo "=== Full Setup Complete ==="
	@$(MAKE) status

uninstall-all: uninstall ingress-uninstall
	@echo "Full teardown complete."

# ============================================================================
# Velero Backup/Restore (Cross-region DR)
# ============================================================================
# 전체 클러스터 백업 (kube-system, velero 제외)
BACKUP_EXCLUDE_NAMESPACES := kube-system,kube-public,kube-node-lease,velero
BACKUP_NAME ?= ticketing-backup-$(shell date +%Y%m%d-%H%M%S)

backup: kubeconfig
	@echo "=== Creating Velero backup (full cluster with cluster resources) ==="
	@echo "Backup name: $(BACKUP_NAME)"
	@echo "Excluding: $(BACKUP_EXCLUDE_NAMESPACES)"
	velero backup create $(BACKUP_NAME) \
		--exclude-namespaces $(BACKUP_EXCLUDE_NAMESPACES) \
		--include-cluster-resources=true \
		--wait
	@echo ""
	velero backup describe $(BACKUP_NAME)

backup-status:
	@echo "=== Recent Backups ==="
	velero backup get | head -10

backup-sync:
	@echo "=== Syncing backup repository from S3 ==="
	velero backup-location get
	@echo ""
	@echo "Triggering sync..."
	kubectl -n velero annotate backupstoragelocation default \
		velero.io/last-sync-check=$$(date +%s) --overwrite
	@echo "Waiting for sync (10s)..."
	@sleep 10
	@echo ""
	@echo "=== Updated Backup List ==="
	velero backup get | head -15

restore:
	@if [ -z "$(FROM)" ]; then \
		echo "Usage: make restore FROM=<backup-name>"; \
		echo ""; \
		echo "Available backups:"; \
		velero backup get | head -10; \
		exit 1; \
	fi
	@echo "=== Restoring from backup: $(FROM) ==="
	velero restore create --from-backup $(FROM) --wait
	@echo ""
	@echo "Restore complete. Checking status..."
	@$(MAKE) status

# ============================================================================
# Database Management (works across regions via PHZ)
# ============================================================================
DB_HOST := db.ddcn41-eks.internal
DB_USER := postgres
DB_NAME := ticketing
DB_SNAPSHOT := db-snapshot.sql

reset-db: kubeconfig
	@echo "=== Resetting database to snapshot state ==="
	@kubectl delete configmap db-snapshot -n $(NAMESPACE) --ignore-not-found
	kubectl create configmap db-snapshot --from-file=$(DB_SNAPSHOT) -n $(NAMESPACE)
	@kubectl delete pod psql-reset -n $(NAMESPACE) --ignore-not-found
	kubectl run psql-reset --image=postgres:17 --restart=Never -n $(NAMESPACE) \
		--env="PGPASSWORD=$(DB_PASSWORD)" \
		--overrides='{"spec":{"volumes":[{"name":"sql","configMap":{"name":"db-snapshot"}}],"containers":[{"name":"psql-reset","image":"postgres:17","env":[{"name":"PGPASSWORD","value":"$(DB_PASSWORD)"}],"command":["/bin/sh","-c","psql -h $(DB_HOST) -U $(DB_USER) -d $(DB_NAME) -f /sql/$(DB_SNAPSHOT)"],"volumeMounts":[{"name":"sql","mountPath":"/sql"}]}]}}'
	@echo "Waiting for database reset..."
	@sleep 15
	@kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/psql-reset -n $(NAMESPACE) --timeout=300s 2>/dev/null || true
	@kubectl logs psql-reset -n $(NAMESPACE) | tail -20
	@kubectl delete pod psql-reset -n $(NAMESPACE)
	@kubectl delete configmap db-snapshot -n $(NAMESPACE)
	@echo "Database reset complete!"

clean-db: kubeconfig
	@echo "=== Cleaning database (dropping all tables) ==="
	@kubectl delete pod psql-clean -n $(NAMESPACE) --ignore-not-found
	kubectl run psql-clean --image=postgres:17 --restart=Never -n $(NAMESPACE) \
		--env="PGPASSWORD=$(DB_PASSWORD)" \
		-- psql -h $(DB_HOST) -U $(DB_USER) -d $(DB_NAME) -c "\
			DROP TABLE IF EXISTS system_metrics CASCADE; \
			DROP TABLE IF EXISTS refunds CASCADE; \
			DROP TABLE IF EXISTS payments CASCADE; \
			DROP TABLE IF EXISTS booking_seats CASCADE; \
			DROP TABLE IF EXISTS bookings CASCADE; \
			DROP TABLE IF EXISTS seat_locks CASCADE; \
			DROP TABLE IF EXISTS schedule_seats CASCADE; \
			DROP TABLE IF EXISTS performance_schedules CASCADE; \
			DROP TABLE IF EXISTS performances CASCADE; \
			DROP TABLE IF EXISTS venues CASCADE; \
			DROP TABLE IF EXISTS users CASCADE; \
			DROP TABLE IF EXISTS queue_tokens CASCADE;"
	@sleep 5
	@kubectl logs psql-clean -n $(NAMESPACE) 2>/dev/null || true
	@kubectl delete pod psql-clean -n $(NAMESPACE) --ignore-not-found
	@echo "Database cleaned!"

dump-db: kubeconfig
	@echo "=== Creating database dump ==="
	@kubectl delete pod pg-dump-job -n $(NAMESPACE) --ignore-not-found
	kubectl run pg-dump-job --image=postgres:17 --restart=Never -n $(NAMESPACE) \
		--env="PGPASSWORD=$(DB_PASSWORD)" \
		-- pg_dump -h $(DB_HOST) -U $(DB_USER) -d $(DB_NAME) --no-owner --no-acl --clean --if-exists
	@echo "Waiting for dump..."
	@sleep 30
	@kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/pg-dump-job -n $(NAMESPACE) --timeout=120s 2>/dev/null || true
	@kubectl logs pg-dump-job -n $(NAMESPACE) > $(DB_SNAPSHOT)
	@kubectl delete pod pg-dump-job -n $(NAMESPACE)
	@echo "Dump saved to $(DB_SNAPSHOT)"
	@ls -lh $(DB_SNAPSHOT)

# ============================================================================
# Velero Installation
# ============================================================================
VELERO_BUCKET := ddcn41-eks-velero-prod-$(REGION)
VELERO_VERSION := 1.14.0
VELERO_AWS_PLUGIN := 1.10.0

velero-install: kubeconfig
	@echo "=== Installing Velero ($(REGION)) ==="
	@echo "Bucket: $(VELERO_BUCKET)"
	velero install \
		--provider aws \
		--plugins velero/velero-plugin-for-aws:v$(VELERO_AWS_PLUGIN) \
		--bucket $(VELERO_BUCKET) \
		--backup-location-config region=$(REGION) \
		--use-node-agent \
		--default-volumes-to-fs-backup=false \
		--use-volume-snapshots=false \
		--wait
	@echo ""
	@$(MAKE) velero-status REGION=$(REGION)

velero-uninstall: kubeconfig
	@echo "=== Uninstalling Velero ==="
	velero uninstall --force || true
	kubectl delete namespace velero --ignore-not-found
	@echo "Velero uninstalled."

velero-status: kubeconfig
	@echo "=== Velero Status ==="
	@kubectl get pods -n velero 2>/dev/null || echo "Velero not installed"
	@echo ""
	@velero backup-location get 2>/dev/null || echo "No backup location configured"

