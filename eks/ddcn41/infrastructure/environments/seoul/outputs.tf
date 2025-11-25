# ============================================================================
# VPC Outputs
# ============================================================================
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

# ============================================================================
# EKS Outputs
# ============================================================================
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_ca_certificate" {
  description = "EKS cluster CA certificate"
  value       = module.eks.cluster_ca_certificate
  sensitive   = true
}

output "eks_cluster_iam_role_arn" {
  description = "EKS cluster IAM role ARN (for multi-region reuse)"
  value       = module.eks.cluster_iam_role_arn
}

output "eks_node_iam_role_arn" {
  description = "EKS node IAM role ARN (for multi-region reuse)"
  value       = module.eks.node_iam_role_arn
}

# ============================================================================
# RDS Outputs
# ============================================================================
output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.endpoint
}

# ============================================================================
# Redis Outputs
# ============================================================================
output "redis_endpoint" {
  description = "Redis endpoint"
  value       = module.redis.endpoint
}

# ============================================================================
# ECR Outputs
# ============================================================================
output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}

# ============================================================================
# Velero Outputs
# ============================================================================
output "velero_bucket_name" {
  description = "Velero S3 bucket name"
  value       = module.velero.bucket_name
}

output "velero_role_arn" {
  description = "Velero IAM role ARN for IRSA"
  value       = module.velero.velero_role_arn
}

output "velero_install_command" {
  description = "Velero CLI install command"
  value       = module.velero.velero_install_command
}

# ============================================================================
# AWS Backup Outputs
# ============================================================================
output "backup_vault_name" {
  description = "AWS Backup vault name"
  value       = module.aws_backup.backup_vault_name
}

output "backup_plan_id" {
  description = "AWS Backup plan ID"
  value       = module.aws_backup.backup_plan_id
}

output "backup_role_arn" {
  description = "AWS Backup IAM role ARN (for multi-region reuse)"
  value       = module.aws_backup.backup_role_arn
}

# ============================================================================
# PHZ Outputs (for DR automation)
# ============================================================================
output "phz_zone_id" {
  description = "Private Hosted Zone ID"
  value       = module.phz.zone_id
}

output "phz_domain" {
  description = "Private Hosted Zone domain name"
  value       = module.phz.zone_name
}

output "phz_rds_dns" {
  description = "RDS DNS endpoint (use this in app config)"
  value       = module.phz.rds_dns
}

output "phz_redis_dns" {
  description = "Redis DNS endpoint (use this in app config)"
  value       = module.phz.redis_dns
}

# ============================================================================
# Migration Helper Outputs
# ============================================================================
output "migration_info" {
  description = "Information needed for cluster migration"
  value = {
    region               = "ap-northeast-2"
    eks_cluster_name     = module.eks.cluster_name
    velero_bucket        = module.velero.bucket_name
    velero_bucket_region = module.velero.bucket_region
    ecr_registry         = module.ecr.repository_registry_id
  }
}

output "dr_dns_info" {
  description = "DNS information for DR failover automation"
  value = {
    phz_zone_id      = module.phz.zone_id
    phz_domain       = module.phz.zone_name
    rds_record_name  = module.phz.rds_record_name
    redis_record_name = module.phz.redis_record_name
    rds_endpoint     = module.rds.endpoint
    redis_endpoint   = module.redis.endpoint
  }
}
