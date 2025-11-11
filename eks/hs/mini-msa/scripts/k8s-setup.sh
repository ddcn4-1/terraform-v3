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

# Detect Kubernetes cluster type
detect_k8s_cluster() {
    print_info "Detecting Kubernetes cluster..."

    local context
    context=$(kubectl config current-context 2>/dev/null || echo "")

    if echo "$context" | grep -q "docker-desktop"; then
        echo "docker-desktop"
    elif echo "$context" | grep -q "kind"; then
        echo "kind"
    elif echo "$context" | grep -q "minikube"; then
        echo "minikube"
    else
        echo "unknown"
    fi
}

# Check if kubectl is installed
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    print_success "kubectl is installed"
}

# Check if cluster is accessible
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot access Kubernetes cluster. Please ensure your cluster is running."
        print_info "For Docker Desktop: Enable Kubernetes in Docker Desktop Settings"
        print_info "For kind: kind create cluster"
        print_info "For minikube: minikube start"
        exit 1
    fi
    print_success "Kubernetes cluster is accessible"
}

# Install NGINX Ingress Controller
install_nginx_ingress() {
    local cluster_type=$1
    print_info "Installing NGINX Ingress Controller..."

    if kubectl get namespace ingress-nginx &> /dev/null; then
        print_warning "NGINX Ingress Controller namespace already exists. Skipping installation."
        return
    fi

    case $cluster_type in
        "docker-desktop")
            print_info "Docker Desktop detected. Installing NGINX Ingress..."
            kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml
            ;;
        "kind")
            print_info "kind detected. Installing NGINX Ingress for kind..."
            kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/kind/deploy.yaml
            ;;
        "minikube")
            print_info "minikube detected. Enabling ingress addon..."
            minikube addons enable ingress
            ;;
        *)
            print_info "Installing generic NGINX Ingress Controller..."
            kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml
            ;;
    esac

    print_info "Waiting for NGINX Ingress Controller to be ready..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s || true

    print_success "NGINX Ingress Controller installed"
}

# Setup local storage class
setup_storage_class() {
    local cluster_type=$1
    print_info "Setting up storage class..."

    case $cluster_type in
        "docker-desktop")
            print_info "Docker Desktop has built-in hostpath provisioner"
            ;;
        "kind")
            print_info "kind has built-in standard storage class"
            kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' || true
            ;;
        "minikube")
            print_info "minikube has built-in standard storage class"
            ;;
    esac

    print_success "Storage class configured"
}

# Build Docker images
build_docker_images() {
    local cluster_type=$1
    print_info "Building Docker images..."

    cd "$(dirname "$0")/.."

    print_info "Building queue-service..."
    docker build -t queue-service:latest ./queue-service

    print_info "Building core-service..."
    docker build -t core-service:latest ./core-service

    # Load images into cluster if needed
    case $cluster_type in
        "docker-desktop")
            print_info "Docker Desktop uses local Docker daemon, images are already available"
            ;;
        "kind")
            print_info "Loading images into kind cluster..."
            kind load docker-image queue-service:latest
            kind load docker-image core-service:latest
            ;;
        "minikube")
            print_info "Loading images into minikube..."
            minikube image load queue-service:latest
            minikube image load core-service:latest
            ;;
    esac

    print_success "Docker images built and loaded"
}

# Deploy application
deploy_app() {
    print_info "Deploying mini-msa application..."

    cd "$(dirname "$0")/.."

    print_info "Applying Kubernetes manifests..."
    kubectl apply -f k8s/base/namespace-app.yaml
    kubectl apply -f k8s/base/namespace-data.yaml
    kubectl apply -f k8s/base/shared-secrets.yaml
    kubectl apply -f k8s/base/postgres/
    kubectl apply -f k8s/base/redis/
    kubectl apply -f k8s/base/queue-service/
    kubectl apply -f k8s/base/core-service/

    print_success "Application deployed"
}

# Wait for pods to be ready
wait_for_pods() {
    print_info "Waiting for pods to be ready..."

    print_info "Waiting for PostgreSQL..."
    kubectl wait --for=condition=ready pod -l app=postgres -n mini-msa-data --timeout=300s || true

    print_info "Waiting for Redis..."
    kubectl wait --for=condition=ready pod -l app=redis -n mini-msa-data --timeout=300s || true

    print_info "Waiting for Queue Service..."
    kubectl wait --for=condition=ready pod -l app=queue-service -n mini-msa-app --timeout=300s || true

    print_info "Waiting for Core Service..."
    kubectl wait --for=condition=ready pod -l app=core-service -n mini-msa-app --timeout=300s || true

    print_success "All pods are ready"
}

# Setup local DNS (optional)
setup_local_dns() {
    print_info "Setting up local DNS..."

    local ingress_ip
    local cluster_type
    cluster_type=$1

    case $cluster_type in
        "minikube")
            ingress_ip=$(minikube ip)
            ;;
        "docker-desktop")
            ingress_ip="127.0.0.1"
            ;;
        *)
            # Try to get LoadBalancer or NodePort IP
            ingress_ip=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "127.0.0.1")
            ;;
    esac

    print_info "Add the following to your /etc/hosts file:"
    echo ""
    echo "    $ingress_ip mini-msa.local"
    echo ""
    print_warning "You may need to run: sudo sh -c 'echo \"$ingress_ip mini-msa.local\" >> /etc/hosts'"
}

# Print access information
print_access_info() {
    local cluster_type=$1

    echo ""
    print_success "=========================================="
    print_success "Mini MSA Kubernetes Setup Complete!"
    print_success "=========================================="
    echo ""

    print_info "Access URLs:"
    echo ""

    case $cluster_type in
        "minikube")
            local minikube_ip
            minikube_ip=$(minikube ip)
            echo "  Core Service (NodePort): http://$minikube_ip:30002"
            echo "  Core Service (Ingress):  http://mini-msa.local (requires /etc/hosts entry)"
            ;;
        "docker-desktop")
            echo "  Core Service (NodePort): http://localhost:30002"
            echo "  Core Service (Ingress):  http://mini-msa.local (requires /etc/hosts entry)"
            echo ""
            print_info "For Docker Desktop, you can access directly via:"
            echo "  curl http://localhost:30002/health"
            ;;
        *)
            echo "  Core Service (NodePort): http://localhost:30002"
            echo "  Core Service (Ingress):  http://mini-msa.local (requires /etc/hosts entry)"
            ;;
    esac

    echo ""
    print_info "Useful commands:"
    echo "  kubectl get all -n mini-msa-app          # View application resources"
    echo "  kubectl get all -n mini-msa-data         # View data resources"
    echo "  kubectl logs -f -l app=core-service -n mini-msa-app    # View logs"
    echo "  kubectl port-forward -n mini-msa-app svc/core-service 3002:3002  # Port forward"
    echo "  ./scripts/k8s-test.sh                    # Run tests"
    echo ""
}

# Main function
main() {
    print_info "Starting Mini MSA Kubernetes setup..."
    echo ""

    # Check prerequisites
    check_kubectl
    check_cluster

    # Detect cluster type
    CLUSTER_TYPE=$(detect_k8s_cluster)
    print_info "Detected cluster type: $CLUSTER_TYPE"
    echo ""

    # Setup components
    install_nginx_ingress "$CLUSTER_TYPE"
    setup_storage_class "$CLUSTER_TYPE"
    build_docker_images "$CLUSTER_TYPE"
    deploy_app
    wait_for_pods
    setup_local_dns "$CLUSTER_TYPE"
    print_access_info "$CLUSTER_TYPE"
}

# Run main function
main
