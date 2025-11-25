# ============================================================================
# S3 Bucket Outputs
# ============================================================================
output "bucket_name" {
  description = "Name of the Velero S3 bucket"
  value       = local.bucket_id
}

output "bucket_arn" {
  description = "ARN of the Velero S3 bucket"
  value       = local.bucket_arn
}

output "bucket_region" {
  description = "Region of the Velero S3 bucket"
  value       = var.create_bucket ? aws_s3_bucket.velero[0].region : var.aws_region
}

output "replica_bucket_name" {
  description = "Name of the replica S3 bucket (if cross-region replication is enabled)"
  value       = var.create_bucket && var.enable_cross_region_replication ? aws_s3_bucket.velero_replica[0].id : null
}

output "replica_bucket_arn" {
  description = "ARN of the replica S3 bucket (if cross-region replication is enabled)"
  value       = var.create_bucket && var.enable_cross_region_replication ? aws_s3_bucket.velero_replica[0].arn : null
}

# ============================================================================
# IAM Outputs
# ============================================================================
output "velero_role_arn" {
  description = "ARN of the Velero IAM role for IRSA"
  value       = local.velero_role_arn
}

output "velero_role_name" {
  description = "Name of the Velero IAM role"
  value       = local.velero_role_name
}

output "velero_policy_arn" {
  description = "ARN of the Velero IAM policy"
  value       = var.create_iam_role ? aws_iam_policy.velero[0].arn : null
}

# ============================================================================
# KMS Outputs
# ============================================================================
output "kms_key_id" {
  description = "ID of the KMS key for Velero encryption"
  value       = var.create_bucket ? aws_kms_key.velero[0].key_id : null
}

output "kms_key_arn" {
  description = "ARN of the KMS key for Velero encryption"
  value       = var.create_bucket ? aws_kms_key.velero[0].arn : null
}

output "kms_key_alias" {
  description = "Alias of the KMS key"
  value       = var.create_bucket ? aws_kms_alias.velero[0].name : null
}

# ============================================================================
# Velero Installation Values
# ============================================================================
output "velero_helm_values" {
  description = "Helm values for Velero installation"
  value = {
    configuration = {
      backupStorageLocation = [{
        name     = "default"
        provider = "aws"
        bucket   = local.bucket_id
        config = {
          region = var.aws_region
        }
      }]
      volumeSnapshotLocation = [{
        name     = "default"
        provider = "aws"
        config = {
          region = var.aws_region
        }
      }]
    }
    serviceAccount = {
      server = {
        annotations = {
          "eks.amazonaws.com/role-arn" = local.velero_role_arn
        }
      }
    }
  }
}

# ============================================================================
# Migration Helper Outputs
# ============================================================================
output "velero_install_command" {
  description = "Velero CLI install command for this cluster"
  value       = <<-EOT
    velero install \
      --provider aws \
      --plugins velero/velero-plugin-for-aws:v1.10.0 \
      --bucket ${local.bucket_id} \
      --backup-location-config region=${var.aws_region} \
      --snapshot-location-config region=${var.aws_region} \
      --secret-file ./credentials-velero \
      --use-node-agent
  EOT
}

output "velero_restore_cluster_command" {
  description = "Command to create a read-only backup location on target cluster"
  value       = <<-EOT
    # On target cluster (after installing Velero):
    velero backup-location create source-cluster \
      --provider aws \
      --bucket ${local.bucket_id} \
      --config region=${var.aws_region} \
      --access-mode=ReadOnly

    # List available backups:
    velero backup get

    # Restore from backup:
    velero restore create --from-backup <BACKUP-NAME>
  EOT
}
