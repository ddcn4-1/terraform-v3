#!/bin/bash

# ECR Push Script for Mini MSA
# This script builds Docker images and pushes them to ECR

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/../terraform/core-infra"

# Default values
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
SERVICES=("core-service" "queue-service")

# Functions
print_header() {
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

print_info() {
  echo -e "${YELLOW}→ $1${NC}"
}

# Get ECR repository URLs from Terraform outputs
get_ecr_urls() {
  print_header "Getting ECR Repository URLs from Terraform"

  if [ ! -d "${TERRAFORM_DIR}" ]; then
    print_error "Terraform directory not found: ${TERRAFORM_DIR}"
    exit 1
  fi

  cd "${TERRAFORM_DIR}"

  # Check if terraform is initialized
  if [ ! -d ".terraform" ]; then
    print_error "Terraform not initialized. Run 'terraform init' first."
    exit 1
  fi

  # Get outputs
  print_info "Fetching Terraform outputs..."

  ECR_CORE_URL=$(terraform output -raw ecr_core_service_url 2>/dev/null)
  ECR_QUEUE_URL=$(terraform output -raw ecr_queue_service_url 2>/dev/null)
  AWS_ACCOUNT_ID=$(terraform output -raw aws_account_id 2>/dev/null)

  if [ -z "${ECR_CORE_URL}" ] || [ -z "${ECR_QUEUE_URL}" ]; then
    print_error "Failed to get ECR URLs from Terraform outputs"
    print_info "Make sure ECR resources are created with 'terraform apply'"
    exit 1
  fi

  print_success "ECR URLs retrieved successfully"
  echo "  Core Service: ${ECR_CORE_URL}"
  echo "  Queue Service: ${ECR_QUEUE_URL}"
  echo ""

  cd "${PROJECT_ROOT}"
}

# ECR Login
ecr_login() {
  print_header "Logging in to ECR"

  print_info "Authenticating with ECR..."
  aws ecr get-login-password --region "${AWS_REGION}" | \
    docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

  print_success "Successfully logged in to ECR"
  echo ""
}

# Build and push Docker image
build_and_push() {
  local service=$1
  local ecr_url=$2

  print_header "Building and Pushing ${service}"

  # Check if Dockerfile exists
  if [ ! -f "${PROJECT_ROOT}/${service}/Dockerfile" ]; then
    print_error "Dockerfile not found for ${service}"
    return 1
  fi

  # Build Docker image
  print_info "Building Docker image for ${service}..."
  docker build --platform linux/amd64 -t "${service}:${IMAGE_TAG}" "${PROJECT_ROOT}/${service}"
  print_success "Image built: ${service}:${IMAGE_TAG}"

  # Tag image for ECR
  print_info "Tagging image for ECR..."
  docker tag "${service}:${IMAGE_TAG}" "${ecr_url}:${IMAGE_TAG}"
  print_success "Image tagged: ${ecr_url}:${IMAGE_TAG}"

  # Push to ECR
  print_info "Pushing image to ECR..."
  docker push "${ecr_url}:${IMAGE_TAG}"
  print_success "Image pushed to ECR"
  echo ""
}

# Main execution
main() {
  print_header "Mini MSA - ECR Push Script"

  echo "Configuration:"
  echo "  AWS Region: ${AWS_REGION}"
  echo "  Image Tag: ${IMAGE_TAG}"
  echo "  Services: ${SERVICES[*]}"
  echo ""

  # Get ECR URLs
  get_ecr_urls

  # ECR Login
  ecr_login

  # Build and push each service
  build_and_push "core-service" "${ECR_CORE_URL}"
  build_and_push "queue-service" "${ECR_QUEUE_URL}"

  # Summary
  print_header "Push Complete!"

  echo "Images pushed successfully:"
  echo "  ${ECR_CORE_URL}:${IMAGE_TAG}"
  echo "  ${ECR_QUEUE_URL}:${IMAGE_TAG}"
  echo ""

  print_info "Next steps:"
  echo "  1. Update Helm values file with ECR image URLs"
  echo "  2. Deploy with: cd helm/mini-msa && helm upgrade --install mini-msa ."
  echo ""
}

# Run main function
main "$@"
