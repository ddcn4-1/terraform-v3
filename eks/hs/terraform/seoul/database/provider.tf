# AWS Provider Configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Module      = "database"
      Owner       = var.owner
    }
  }
}

# Kubernetes Provider (uses local values for cleanup)
# Note: Using dummy values since EKS cluster no longer exists
provider "kubernetes" {
  host                   = local.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(local.eks_cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", local.eks_cluster_name,
      "--region", var.aws_region
    ]
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Remote state data source for core-infra
data "terraform_remote_state" "core_infra" {
  backend = "s3"

  config = {
    bucket = var.core_infra_state_bucket
    key    = "eks/core-infra/terraform.tfstate"
    region = var.aws_region
  }
}
