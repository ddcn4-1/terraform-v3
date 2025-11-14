#!/usr/bin/env bash
# Pre-flight checks for Helm deployment
# Validates environment before installation to prevent failures

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
log_error() { echo -e "${RED}[✗]${NC} $1"; ERRORS=$((ERRORS + 1)); }

# Check if command exists
check_command() {
    local cmd=$1
    local version_flag=${2:-"--version"}

    if command -v "${cmd}" &>/dev/null; then
        local version=$(${cmd} ${version_flag} 2>&1 | head -n1 || echo "unknown")
        log_success "${cmd} is installed (${version})"
        return 0
    else
        log_error "${cmd} is not installed"
        return 1
    fi
}

# Check Kubernetes cluster
check_k8s_cluster() {
    log_info "Checking Kubernetes cluster..."

    if kubectl cluster-info &>/dev/null; then
        local context=$(kubectl config current-context)
        log_success "Connected to cluster: ${context}"

        # Check cluster version
        local version=$(kubectl version --short 2>/dev/null | grep Server || echo "unknown")
        log_info "Cluster version: ${version}"

        return 0
    else
        log_error "Cannot connect to Kubernetes cluster"
        return 1
    fi
}

# Check namespace conflicts
check_namespace_conflicts() {
    log_info "Checking for namespace conflicts..."

    local namespaces=("mini-msa-app" "mini-msa-data")
    local conflicts=0

    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "${ns}" &>/dev/null; then
            # Check if managed by Helm
            local managed_by=$(kubectl get namespace "${ns}" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null || echo "")

            if [ "${managed_by}" != "Helm" ]; then
                log_warning "Namespace ${ns} exists but not managed by Helm"
                log_info "  → Run 'make helm-reset' to clean up"
                conflicts=$((conflicts + 1))
            else
                log_info "Namespace ${ns} exists and is Helm-managed"
            fi
        fi
    done

    if [ $conflicts -eq 0 ]; then
        log_success "No namespace conflicts"
        return 0
    else
        return 1
    fi
}

# Check Helm release
check_helm_release() {
    log_info "Checking for existing Helm release..."

    if helm list -q | grep -q "^mini-msa$"; then
        local status=$(helm list -o json | jq -r '.[] | select(.name=="mini-msa") | .status')
        log_info "Existing release found with status: ${status}"

        if [ "${status}" != "deployed" ]; then
            log_warning "Release is in '${status}' state"
            log_info "  → Consider running 'helm uninstall mini-msa'"
        fi
    else
        log_success "No existing release found"
    fi
}

# Check Docker images (for local development)
check_docker_images() {
    log_info "Checking for local Docker images..."

    local images=("core-service:latest" "queue-service:latest")
    local missing=0

    # Check if using Minikube
    if kubectl config current-context | grep -q "minikube"; then
        log_info "Detected Minikube environment"
        eval $(minikube docker-env 2>/dev/null) || true
    fi

    for img in "${images[@]}"; do
        if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${img}$"; then
            log_success "Image found: ${img}"
        else
            log_warning "Image not found: ${img}"
            log_info "  → Run: docker build -t ${img%%:*}:latest ./services/${img%%:*} (adjust path as needed)"
            missing=$((missing + 1))
        fi
    done

    if [ $missing -eq 0 ]; then
        log_success "All required images are available"
    fi
}

# Check resource availability
check_resources() {
    log_info "Checking cluster resources..."

    # Check nodes
    local node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    if [ "${node_count}" -gt 0 ]; then
        log_success "${node_count} node(s) available"

        # Check node resources
        kubectl top nodes &>/dev/null || log_info "Metrics not available (metrics-server may not be installed)"
    else
        log_error "No nodes available"
    fi

    # Check storage classes
    local sc_count=$(kubectl get storageclass --no-headers 2>/dev/null | wc -l)
    if [ "${sc_count}" -gt 0 ]; then
        log_success "${sc_count} storage class(es) available"
    else
        log_warning "No storage classes found (PVC provisioning may fail)"
    fi
}

# Check Helm chart validity
check_helm_chart() {
    log_info "Validating Helm chart..."

    if [ ! -f "helm/mini-msa/Chart.yaml" ]; then
        log_error "Chart.yaml not found in helm/mini-msa/"
        return 1
    fi

    # Run helm lint
    if helm lint helm/mini-msa &>/dev/null; then
        log_success "Helm chart passes lint checks"
    else
        log_error "Helm chart has lint errors"
        log_info "  → Run 'helm lint helm/mini-msa' for details"
        return 1
    fi

    # Check dependencies
    if [ -f "helm/mini-msa/Chart.lock" ]; then
        log_success "Dependencies are locked"
    else
        log_warning "Dependencies not locked (will be updated on install)"
        log_info "  → Run 'helm dependency update helm/mini-msa'"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Mini MSA - Pre-flight Validation          ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo ""

    # Required tools
    log_info "=== Checking Required Tools ==="
    check_command "kubectl"
    check_command "helm"
    check_command "docker"
    check_command "jq"
    echo ""

    # Kubernetes cluster
    log_info "=== Checking Kubernetes Cluster ==="
    check_k8s_cluster
    echo ""

    # Resources
    log_info "=== Checking Cluster Resources ==="
    check_resources
    echo ""

    # Helm chart
    log_info "=== Validating Helm Chart ==="
    check_helm_chart
    echo ""

    # Namespace conflicts
    log_info "=== Checking for Conflicts ==="
    check_namespace_conflicts
    check_helm_release
    echo ""

    # Docker images
    log_info "=== Checking Docker Images ==="
    check_docker_images
    echo ""

    # Summary
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              Validation Summary                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"

    if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
        log_success "All checks passed! Ready to deploy."
        exit 0
    elif [ $ERRORS -eq 0 ]; then
        echo -e "${YELLOW}⚠ Passed with ${WARNINGS} warning(s)${NC}"
        echo "Deployment may proceed but review warnings above."
        exit 0
    else
        echo -e "${RED}✗ Found ${ERRORS} error(s) and ${WARNINGS} warning(s)${NC}"
        echo "Please fix errors before deployment."
        exit 1
    fi
}

main "$@"
