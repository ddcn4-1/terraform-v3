# AWS Backup Module
# Provides automated backup for RDS, EBS, and other AWS resources
# Supports cross-region backup copy for disaster recovery

locals {
  backup_vault_name = "${var.project_name}-backup-vault-${var.environment}"

  # Resource resolution (create or reference existing)
  backup_role_arn  = var.create_iam_role ? aws_iam_role.backup[0].arn : var.existing_backup_role_arn
  backup_role_name = var.create_iam_role ? aws_iam_role.backup[0].name : split("/", var.existing_backup_role_arn)[1]
}

# ============================================================================
# KMS Key for Backup Encryption
# ============================================================================
resource "aws_kms_key" "backup" {
  description             = "KMS key for AWS Backup encryption"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Backup Service"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:CallerAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-backup-kms"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "backup" {
  name          = "alias/${var.project_name}-backup-${var.environment}"
  target_key_id = aws_kms_key.backup.key_id
}

data "aws_caller_identity" "current" {}

# ============================================================================
# Backup Vault (Primary Region)
# ============================================================================
resource "aws_backup_vault" "main" {
  name        = local.backup_vault_name
  kms_key_arn = aws_kms_key.backup.arn

  tags = {
    Name        = local.backup_vault_name
    Environment = var.environment
  }
}

# Vault Lock Policy (Optional - for compliance)
resource "aws_backup_vault_lock_configuration" "main" {
  count = var.enable_vault_lock ? 1 : 0

  backup_vault_name   = aws_backup_vault.main.name
  min_retention_days  = var.vault_lock_min_retention_days
  max_retention_days  = var.vault_lock_max_retention_days
  changeable_for_days = var.vault_lock_changeable_days
}

# ============================================================================
# Backup Vault (DR Region) - for cross-region copies
# ============================================================================
resource "aws_backup_vault" "dr" {
  count    = var.enable_cross_region_backup ? 1 : 0
  provider = aws.dr

  name        = "${local.backup_vault_name}-dr"
  kms_key_arn = var.dr_kms_key_arn

  tags = {
    Name        = "${local.backup_vault_name}-dr"
    Environment = var.environment
    Region      = var.dr_region
  }
}

# ============================================================================
# IAM Role for AWS Backup (only created when create_iam_role is true)
# ============================================================================
resource "aws_iam_role" "backup" {
  count = var.create_iam_role ? 1 : 0
  name  = "${var.project_name}-aws-backup-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${var.project_name}-aws-backup-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "backup" {
  count      = var.create_iam_role ? 1 : 0
  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore" {
  count      = var.create_iam_role ? 1 : 0
  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# Additional policy for S3 backups
resource "aws_iam_role_policy_attachment" "s3_backup" {
  count      = var.create_iam_role && var.enable_s3_backup ? 1 : 0
  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Backup"
}

resource "aws_iam_role_policy_attachment" "s3_restore" {
  count      = var.create_iam_role && var.enable_s3_backup ? 1 : 0
  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Restore"
}

# ============================================================================
# Backup Plan - Daily Backups
# ============================================================================
resource "aws_backup_plan" "daily" {
  name = "${var.project_name}-daily-backup-${var.environment}"

  rule {
    rule_name         = "daily-backup-rule"
    target_vault_name = aws_backup_vault.main.name
    schedule          = var.daily_backup_schedule
    start_window      = var.backup_start_window
    completion_window = var.backup_completion_window

    lifecycle {
      cold_storage_after = var.cold_storage_after_days
      delete_after       = var.daily_backup_retention_days
    }

    # Cross-region copy (if enabled)
    dynamic "copy_action" {
      for_each = var.enable_cross_region_backup ? [1] : []
      content {
        destination_vault_arn = aws_backup_vault.dr[0].arn
        lifecycle {
          delete_after = var.dr_backup_retention_days
        }
      }
    }

    recovery_point_tags = {
      Environment = var.environment
      BackupType  = "daily"
    }
  }

  # Weekly backup rule with longer retention
  rule {
    rule_name         = "weekly-backup-rule"
    target_vault_name = aws_backup_vault.main.name
    schedule          = var.weekly_backup_schedule
    start_window      = var.backup_start_window
    completion_window = var.backup_completion_window

    lifecycle {
      cold_storage_after = var.cold_storage_after_days
      delete_after       = var.weekly_backup_retention_days
    }

    dynamic "copy_action" {
      for_each = var.enable_cross_region_backup ? [1] : []
      content {
        destination_vault_arn = aws_backup_vault.dr[0].arn
        lifecycle {
          delete_after = var.dr_backup_retention_days
        }
      }
    }

    recovery_point_tags = {
      Environment = var.environment
      BackupType  = "weekly"
    }
  }

  # Monthly backup rule for long-term retention
  rule {
    rule_name         = "monthly-backup-rule"
    target_vault_name = aws_backup_vault.main.name
    schedule          = var.monthly_backup_schedule
    start_window      = var.backup_start_window
    completion_window = var.backup_completion_window

    lifecycle {
      cold_storage_after = 30
      delete_after       = var.monthly_backup_retention_days
    }

    dynamic "copy_action" {
      for_each = var.enable_cross_region_backup ? [1] : []
      content {
        destination_vault_arn = aws_backup_vault.dr[0].arn
        lifecycle {
          delete_after = var.monthly_backup_retention_days
        }
      }
    }

    recovery_point_tags = {
      Environment = var.environment
      BackupType  = "monthly"
    }
  }

  advanced_backup_setting {
    backup_options = {
      WindowsVSS = "disabled"
    }
    resource_type = "EC2"
  }

  tags = {
    Name        = "${var.project_name}-backup-plan"
    Environment = var.environment
  }
}

# ============================================================================
# Backup Selection - Tag-based Resource Selection
# ============================================================================
resource "aws_backup_selection" "main" {
  name         = "${var.project_name}-backup-selection-${var.environment}"
  plan_id      = aws_backup_plan.daily.id
  iam_role_arn = local.backup_role_arn

  # Select resources by tag
  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "true"
  }

  # Also select by environment tag
  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Environment"
    value = var.environment
  }
}

# Additional selection for specific resource ARNs
resource "aws_backup_selection" "specific_resources" {
  count = length(var.backup_resource_arns) > 0 ? 1 : 0

  name         = "${var.project_name}-specific-backup-${var.environment}"
  plan_id      = aws_backup_plan.daily.id
  iam_role_arn = local.backup_role_arn

  resources = var.backup_resource_arns
}

# ============================================================================
# SNS Topic for Backup Notifications
# ============================================================================
resource "aws_sns_topic" "backup_notifications" {
  count = var.enable_backup_notifications ? 1 : 0
  name  = "${var.project_name}-backup-notifications-${var.environment}"

  tags = {
    Name        = "${var.project_name}-backup-notifications"
    Environment = var.environment
  }
}

resource "aws_sns_topic_policy" "backup_notifications" {
  count  = var.enable_backup_notifications ? 1 : 0
  arn    = aws_sns_topic.backup_notifications[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
      Action   = "SNS:Publish"
      Resource = aws_sns_topic.backup_notifications[0].arn
    }]
  })
}

resource "aws_backup_vault_notifications" "main" {
  count = var.enable_backup_notifications ? 1 : 0

  backup_vault_name   = aws_backup_vault.main.name
  sns_topic_arn       = aws_sns_topic.backup_notifications[0].arn
  backup_vault_events = [
    "BACKUP_JOB_STARTED",
    "BACKUP_JOB_COMPLETED",
    "BACKUP_JOB_FAILED",
    "RESTORE_JOB_STARTED",
    "RESTORE_JOB_COMPLETED",
    "RESTORE_JOB_FAILED",
    "COPY_JOB_STARTED",
    "COPY_JOB_SUCCESSFUL",
    "COPY_JOB_FAILED"
  ]
}
