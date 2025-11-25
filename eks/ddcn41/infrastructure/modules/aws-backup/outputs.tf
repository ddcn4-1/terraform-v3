# ============================================================================
# Vault Outputs
# ============================================================================
output "backup_vault_name" {
  description = "Name of the primary backup vault"
  value       = aws_backup_vault.main.name
}

output "backup_vault_arn" {
  description = "ARN of the primary backup vault"
  value       = aws_backup_vault.main.arn
}

output "dr_backup_vault_name" {
  description = "Name of the DR backup vault (if cross-region backup is enabled)"
  value       = var.enable_cross_region_backup ? aws_backup_vault.dr[0].name : null
}

output "dr_backup_vault_arn" {
  description = "ARN of the DR backup vault (if cross-region backup is enabled)"
  value       = var.enable_cross_region_backup ? aws_backup_vault.dr[0].arn : null
}

# ============================================================================
# Backup Plan Outputs
# ============================================================================
output "backup_plan_id" {
  description = "ID of the backup plan"
  value       = aws_backup_plan.daily.id
}

output "backup_plan_arn" {
  description = "ARN of the backup plan"
  value       = aws_backup_plan.daily.arn
}

output "backup_plan_version" {
  description = "Version of the backup plan"
  value       = aws_backup_plan.daily.version
}

# ============================================================================
# IAM Outputs
# ============================================================================
output "backup_role_arn" {
  description = "ARN of the AWS Backup IAM role"
  value       = local.backup_role_arn
}

output "backup_role_name" {
  description = "Name of the AWS Backup IAM role"
  value       = local.backup_role_name
}

# ============================================================================
# KMS Outputs
# ============================================================================
output "backup_kms_key_id" {
  description = "ID of the KMS key for backup encryption"
  value       = aws_kms_key.backup.key_id
}

output "backup_kms_key_arn" {
  description = "ARN of the KMS key for backup encryption"
  value       = aws_kms_key.backup.arn
}

# ============================================================================
# Notification Outputs
# ============================================================================
output "backup_notification_topic_arn" {
  description = "ARN of the SNS topic for backup notifications"
  value       = var.enable_backup_notifications ? aws_sns_topic.backup_notifications[0].arn : null
}

# ============================================================================
# Helper Outputs
# ============================================================================
output "resource_tagging_instructions" {
  description = "Instructions for tagging resources to include in backup"
  value       = <<-EOT
    To include resources in the backup plan, add the following tags:

    Required tags (both must be present):
    - Backup = "true"
    - Environment = "${var.environment}"

    Example for RDS:
    aws rds add-tags-to-resource \
      --resource-name <rds-arn> \
      --tags Key=Backup,Value=true Key=Environment,Value=${var.environment}

    Example for EBS volumes:
    aws ec2 create-tags \
      --resources <volume-id> \
      --tags Key=Backup,Value=true Key=Environment,Value=${var.environment}
  EOT
}

output "backup_schedule_summary" {
  description = "Summary of backup schedules"
  value = {
    daily = {
      schedule  = var.daily_backup_schedule
      retention = "${var.daily_backup_retention_days} days"
    }
    weekly = {
      schedule  = var.weekly_backup_schedule
      retention = "${var.weekly_backup_retention_days} days"
    }
    monthly = {
      schedule  = var.monthly_backup_schedule
      retention = "${var.monthly_backup_retention_days} days"
    }
    cross_region = var.enable_cross_region_backup ? {
      enabled   = true
      dr_region = var.dr_region
      retention = "${var.dr_backup_retention_days} days"
    } : { enabled = false }
  }
}
