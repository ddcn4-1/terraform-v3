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
# Velero Outputs
# ============================================================================
output "velero_bucket_name" {
  description = "Velero S3 bucket name (Tokyo local)"
  value       = module.velero.bucket_name
}

output "velero_role_arn" {
  description = "Velero IAM role ARN for IRSA"
  value       = module.velero.velero_role_arn
}

# ============================================================================
# AWS Backup Outputs
# ============================================================================
output "backup_vault_name" {
  description = "AWS Backup vault name"
  value       = module.aws_backup.backup_vault_name
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
# DR/Migration Helper Outputs
# ============================================================================
output "restore_from_seoul_commands" {
  description = "Commands to restore from Seoul cluster backup (using Tokyo replica bucket)"
  value       = <<-EOT
    # ============================================================
    # DR Restore Procedure - Seoul 장애 시 Tokyo에서 복구
    # ============================================================
    #
    # S3 복제 구조:
    #   Seoul 원본: ${data.aws_s3_bucket.seoul_velero.id}
    #   Tokyo 복제: ${data.aws_s3_bucket.tokyo_replica_velero.id}
    #
    # ============================================================

    # 1. Install Velero on Tokyo cluster (using Tokyo replica bucket)
    velero install \
      --provider aws \
      --plugins velero/velero-plugin-for-aws:v1.10.0 \
      --bucket ${data.aws_s3_bucket.tokyo_replica_velero.id} \
      --backup-location-config region=ap-northeast-1 \
      --snapshot-location-config region=ap-northeast-1 \
      --use-node-agent \
      --sa-annotations "eks.amazonaws.com/role-arn=${module.velero.velero_role_arn}"

    # 2. Wait for backup sync and list available backups
    sleep 30
    velero backup get

    # 3. Restore from backup (Seoul에서 생성된 백업이 Tokyo 버킷에 복제됨)
    velero restore create tokyo-restore --from-backup <BACKUP-NAME>

    # 4. Verify restore status
    velero restore describe tokyo-restore
    velero restore logs tokyo-restore
  EOT
}

output "migration_info" {
  description = "Information for DR migration"
  value = {
    region                  = "ap-northeast-1"
    eks_cluster_name        = module.eks.cluster_name
    local_velero_bucket     = module.velero.bucket_name
    tokyo_replica_bucket    = data.aws_s3_bucket.tokyo_replica_velero.id
    seoul_source_bucket     = data.aws_s3_bucket.seoul_velero.id
    velero_role_arn         = module.velero.velero_role_arn
  }
}

output "dr_dns_info" {
  description = "DNS information for DR failover automation"
  value = {
    phz_zone_id       = module.phz.zone_id
    phz_domain        = module.phz.zone_name
    rds_record_name   = module.phz.rds_record_name
    redis_record_name = module.phz.redis_record_name
    rds_endpoint      = module.rds.endpoint
    redis_endpoint    = module.redis.endpoint
  }
}
