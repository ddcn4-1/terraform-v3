#!/usr/bin/env bash
# Automated Helm environment reset script
# Eliminates manual intervention and ensures clean state

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RELEASE_NAME="mini-msa"
NAMESPACES=("mini-msa-app" "mini-msa-data")
HELM_CHART="helm/mini-msa"
VALUES_FILE="helm/mini-msa/values-dev.yaml"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Helm release exists
check_release_exists() {
    helm list -q | grep -q "^${RELEASE_NAME}$"
}

# Check if namespace exists
check_namespace_exists() {
    local namespace=$1
    kubectl get namespace "${namespace}" &>/dev/null
}

# Remove Helm release
remove_helm_release() {
    log_info "Checking for existing Helm release..."
    if check_release_exists; then
        log_info "Uninstalling Helm release: ${RELEASE_NAME}"
        helm uninstall "${RELEASE_NAME}" || log_warning "Failed to uninstall release (may not exist)"
        log_success "Helm release removed"
    else
        log_info "No existing Helm release found"
    fi
}

# Remove namespaces with proper cleanup
remove_namespaces() {
    for namespace in "${NAMESPACES[@]}"; do
        if check_namespace_exists "${namespace}"; then
            log_info "Removing namespace: ${namespace}"

            # Remove finalizers if stuck
            kubectl get namespace "${namespace}" -o json | \
                jq '.spec.finalizers = []' | \
                kubectl replace --raw "/api/v1/namespaces/${namespace}/finalize" -f - &>/dev/null || true

            # Delete namespace
            kubectl delete namespace "${namespace}" --timeout=60s || log_warning "Namespace ${namespace} deletion timeout"

            # Wait for complete removal
            local count=0
            while check_namespace_exists "${namespace}" && [ $count -lt 30 ]; do
                sleep 2
                count=$((count + 1))
            done

            if check_namespace_exists "${namespace}"; then
                log_warning "Namespace ${namespace} still exists, forcing deletion..."
                kubectl delete namespace "${namespace}" --grace-period=0 --force || true
            else
                log_success "Namespace ${namespace} removed"
            fi
        else
            log_info "Namespace ${namespace} does not exist"
        fi
    done
}

# Verify clean state
verify_clean_state() {
    log_info "Verifying clean state..."

    local issues=0

    # Check Helm release
    if check_release_exists; then
        log_error "Helm release still exists"
        issues=$((issues + 1))
    fi

    # Check namespaces
    for namespace in "${NAMESPACES[@]}"; do
        if check_namespace_exists "${namespace}"; then
            log_error "Namespace ${namespace} still exists"
            issues=$((issues + 1))
        fi
    done

    if [ $issues -eq 0 ]; then
        log_success "Environment is clean"
        return 0
    else
        log_error "Found ${issues} issue(s) during verification"
        return 1
    fi
}

# Update Helm dependencies
update_dependencies() {
    log_info "Updating Helm dependencies..."
    cd "${HELM_CHART}" && helm dependency update
    cd - > /dev/null
    log_success "Dependencies updated"
}

# Install Helm chart
install_helm_chart() {
    log_info "Installing Helm chart..."
    helm install "${RELEASE_NAME}" "${HELM_CHART}" \
        -f "${VALUES_FILE}" \
        --create-namespace \
        --wait \
        --timeout 5m
    log_success "Helm chart installed"
}

# Wait for pods to be ready
wait_for_pods() {
    log_info "Waiting for pods to be ready..."

    for namespace in "${NAMESPACES[@]}"; do
        log_info "Checking namespace: ${namespace}"
        if kubectl wait --for=condition=ready pod \
            --all \
            -n "${namespace}" \
            --timeout=300s 2>/dev/null; then
            log_success "All pods ready in ${namespace}"
        else
            log_warning "Some pods not ready in ${namespace}"
        fi
    done
}

# Display status
display_status() {
    log_info "Current status:"
    echo ""
    helm list
    echo ""

    for namespace in "${NAMESPACES[@]}"; do
        echo -e "${BLUE}=== Namespace: ${namespace} ===${NC}"
        kubectl get pods -n "${namespace}" 2>/dev/null || echo "No pods found"
        echo ""
    done
}

# Main execution
main() {
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Mini MSA - Automated Helm Reset & Install    ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo ""

    # Step 1: Clean environment
    log_info "Step 1: Cleaning environment..."
    remove_helm_release
    remove_namespaces

    # Step 2: Verify clean state
    log_info "Step 2: Verifying clean state..."
    if ! verify_clean_state; then
        log_error "Failed to achieve clean state"
        exit 1
    fi

    # Step 3: Update dependencies
    log_info "Step 3: Updating dependencies..."
    update_dependencies

    # Step 4: Install chart
    log_info "Step 4: Installing Helm chart..."
    install_helm_chart

    # Step 5: Wait for readiness
    log_info "Step 5: Waiting for pods..."
    wait_for_pods

    # Step 6: Display status
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║        Installation Complete!                  ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    display_status

    echo ""
    log_success "Access the application:"
    echo "  - Core Service: http://localhost:30002"
    echo "  - With Ingress: http://mini-msa.local"
    echo ""
}

# Run main function
main "$@"
