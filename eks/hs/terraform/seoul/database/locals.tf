# Temporary locals to replace remote state outputs for cleanup
# This file provides hardcoded values from the existing resources
# to allow terraform destroy to work when core-infra state is unavailable

locals {
  # Database subnets from existing subnet group
  database_subnets = [
    "subnet-09758eb8ea09f7dff",
    "subnet-0b6716588e4f78893",
  ]

  # Security group IDs from existing resources
  rds_security_group_id   = "sg-0c31139e04874b0ce"
  redis_security_group_id = "sg-0299f0abd07dcbb6c"

  # EKS cluster configuration (not needed for destroy but required by provider)
  # These are dummy values since Kubernetes resources will be destroyed first
  eks_cluster_endpoint                       = "https://dummy.eks.amazonaws.com"
  eks_cluster_name                           = "dummy-cluster"
  eks_cluster_certificate_authority_data     = base64encode("dummy-ca-data")
}
