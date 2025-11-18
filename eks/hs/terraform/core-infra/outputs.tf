# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnets" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "database_subnets" {
  description = "IDs of database subnets"
  value       = module.vpc.database_subnets
}

output "database_subnet_group_name" {
  description = "Name of the database subnet group"
  value       = module.vpc.database_subnet_group_name
}

# EKS Outputs
output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority_data" {
  description = "Certificate authority data (base64) for the EKS cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "eks_cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = module.eks.cluster_version
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "eks_oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = module.eks.oidc_provider_arn
}

output "eks_node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = module.eks.node_security_group_id
}

# Security Group Outputs (for database module)
output "eks_worker_security_group_id" {
  description = "Additional security group ID for EKS worker nodes"
  value       = aws_security_group.eks_worker_additional.id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS"
  value       = aws_security_group.rds.id
}

output "redis_security_group_id" {
  description = "Security group ID for ElastiCache Redis"
  value       = aws_security_group.redis.id
}

output "alb_security_group_id" {
  description = "Security group ID for Application Load Balancer"
  value       = aws_security_group.alb.id
}

# IAM Role Outputs (for database module)
output "application_irsa_role_arn" {
  description = "ARN of the application IRSA role"
  value       = module.application_irsa_role.iam_role_arn
}

output "application_irsa_role_name" {
  description = "Name of the application IRSA role"
  value       = module.application_irsa_role.iam_role_name
}

# ConfigMap Output
output "application_config_map_name" {
  description = "Name of the application ConfigMap"
  value       = kubernetes_config_map.application_config.metadata[0].name
}

# Kubeconfig Command
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# Region and Account Info
output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

# ECR Outputs
output "ecr_repository_urls" {
  description = "ECR repository URLs for services"
  value = {
    for k, v in aws_ecr_repository.mini_msa : k => v.repository_url
  }
}

output "ecr_core_service_url" {
  description = "ECR repository URL for core-service"
  value       = aws_ecr_repository.mini_msa["core-service"].repository_url
}

output "ecr_queue_service_url" {
  description = "ECR repository URL for queue-service"
  value       = aws_ecr_repository.mini_msa["queue-service"].repository_url
}

# Remote State Access Info
output "remote_state_config" {
  description = "Configuration for accessing this remote state from database module"
  value = {
    bucket = "REPLACE_WITH_BOOTSTRAP_OUTPUT"
    key    = "eks/core-infra/terraform.tfstate"
    region = var.aws_region
  }
}
