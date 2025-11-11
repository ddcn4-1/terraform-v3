#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is installed
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
}

# Check if namespaces exist
check_namespace() {
    local app_exists=false
    local data_exists=false

    if kubectl get namespace mini-msa-app &> /dev/null; then
        app_exists=true
    fi

    if kubectl get namespace mini-msa-data &> /dev/null; then
        data_exists=true
    fi

    if [ "$app_exists" = "false" ] && [ "$data_exists" = "false" ]; then
        print_warning "Namespaces 'mini-msa-app' and 'mini-msa-data' do not exist. Nothing to clean up."
        exit 0
    fi

    if [ "$app_exists" = "true" ]; then
        print_info "Found namespace: mini-msa-app"
    fi
    if [ "$data_exists" = "true" ]; then
        print_info "Found namespace: mini-msa-data"
    fi
}

# Delete application resources
delete_app_resources() {
    print_info "Deleting application resources..."

    cd "$(dirname "$0")/.."

    print_info "Deleting Kubernetes manifests..."

    # Delete application namespace resources
    if kubectl get namespace mini-msa-app &> /dev/null; then
        print_info "Deleting resources from mini-msa-app namespace..."
        kubectl delete -f k8s/base/core-service/ --ignore-not-found=true
        kubectl delete -f k8s/base/queue-service/ --ignore-not-found=true
        kubectl delete -f k8s/base/shared-secrets.yaml --ignore-not-found=true
    fi

    # Delete data namespace resources
    if kubectl get namespace mini-msa-data &> /dev/null; then
        print_info "Deleting resources from mini-msa-data namespace..."
        kubectl delete -f k8s/base/redis/ --ignore-not-found=true
        kubectl delete -f k8s/base/postgres/ --ignore-not-found=true
    fi

    print_success "Application resources deleted"
}

# Delete namespaces
delete_namespace() {
    # Delete application namespace
    if kubectl get namespace mini-msa-app &> /dev/null; then
        print_info "Deleting namespace 'mini-msa-app'..."
        kubectl delete namespace mini-msa-app --ignore-not-found=true
        print_info "Waiting for namespace to be fully deleted..."
        kubectl wait --for=delete namespace/mini-msa-app --timeout=120s 2>/dev/null || true
        print_success "Namespace mini-msa-app deleted"
    fi

    # Delete data namespace
    if kubectl get namespace mini-msa-data &> /dev/null; then
        print_info "Deleting namespace 'mini-msa-data'..."
        kubectl delete namespace mini-msa-data --ignore-not-found=true
        print_info "Waiting for namespace to be fully deleted..."
        kubectl wait --for=delete namespace/mini-msa-data --timeout=120s 2>/dev/null || true
        print_success "Namespace mini-msa-data deleted"
    fi
}

# Delete PVCs (optional)
delete_pvcs() {
    print_info "Checking for PersistentVolumeClaims..."

    local app_pvcs=0
    local data_pvcs=0

    # Check mini-msa-app namespace
    if kubectl get namespace mini-msa-app &> /dev/null; then
        app_pvcs=$(kubectl get pvc -n mini-msa-app --no-headers 2>/dev/null | wc -l || echo "0")
        if [ "$app_pvcs" -gt 0 ]; then
            print_warning "Found $app_pvcs PersistentVolumeClaims in mini-msa-app namespace"
            print_info "Deleting PVCs from mini-msa-app..."
            kubectl delete pvc --all -n mini-msa-app --ignore-not-found=true
        fi
    fi

    # Check mini-msa-data namespace
    if kubectl get namespace mini-msa-data &> /dev/null; then
        data_pvcs=$(kubectl get pvc -n mini-msa-data --no-headers 2>/dev/null | wc -l || echo "0")
        if [ "$data_pvcs" -gt 0 ]; then
            print_warning "Found $data_pvcs PersistentVolumeClaims in mini-msa-data namespace"
            print_info "Deleting PVCs from mini-msa-data..."
            kubectl delete pvc --all -n mini-msa-data --ignore-not-found=true
        fi
    fi

    local total_pvcs=$((app_pvcs + data_pvcs))
    if [ "$total_pvcs" -gt 0 ]; then
        print_success "PVCs deleted"
    else
        print_info "No PVCs found"
    fi
}

# Clean up Docker images (optional)
cleanup_docker_images() {
    local cleanup_images=$1

    if [ "$cleanup_images" = "true" ]; then
        print_info "Cleaning up Docker images..."

        if docker images queue-service:latest -q 2>/dev/null | grep -q .; then
            print_info "Removing queue-service:latest..."
            docker rmi queue-service:latest 2>/dev/null || true
        fi

        if docker images core-service:latest -q 2>/dev/null | grep -q .; then
            print_info "Removing core-service:latest..."
            docker rmi core-service:latest 2>/dev/null || true
        fi

        print_success "Docker images cleaned up"
    fi
}

# Print summary
print_summary() {
    echo ""
    print_success "=========================================="
    print_success "Mini MSA Kubernetes Cleanup Complete!"
    print_success "=========================================="
    echo ""
    print_info "Resources cleaned up:"
    echo "  ✓ Deployments (core-service, queue-service)"
    echo "  ✓ StatefulSets (postgres, redis)"
    echo "  ✓ Services"
    echo "  ✓ ConfigMaps"
    echo "  ✓ Secrets"
    echo "  ✓ PersistentVolumeClaims"
    echo "  ✓ Namespace (mini-msa-app)"
    echo "  ✓ Namespace (mini-msa-data)"
    echo ""
}

# Main function
main() {
    local cleanup_images=false
    local force=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --images)
                cleanup_images=true
                shift
                ;;
            --force|-f)
                force=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --images         Also remove Docker images (queue-service:latest, core-service:latest)"
                echo "  --force, -f      Skip confirmation prompt"
                echo "  --help, -h       Show this help message"
                echo ""
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    print_info "Starting Mini MSA Kubernetes cleanup..."
    echo ""

    # Check prerequisites
    check_kubectl
    check_namespace

    # Confirmation prompt
    if [ "$force" != "true" ]; then
        print_warning "This will delete all resources in the following namespaces:"
        print_warning "  - mini-msa-app (application services)"
        print_warning "  - mini-msa-data (databases and cache)"
        if [ "$cleanup_images" = "true" ]; then
            print_warning "Docker images will also be removed."
        fi
        echo ""
        read -p "Are you sure you want to continue? (yes/no): " -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            print_info "Cleanup cancelled."
            exit 0
        fi
    fi

    # Perform cleanup (correct order: resources -> PVCs -> namespace)
    delete_app_resources
    delete_pvcs
    delete_namespace
    cleanup_docker_images "$cleanup_images"
    print_summary

    print_info "You can recreate the environment with: ./scripts/k8s-setup.sh"
}

# Run main function
main "$@"
