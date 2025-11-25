# ============================================================================
# Required Variables
# ============================================================================
variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

# ============================================================================
# KMS Configuration
# ============================================================================
variable "kms_deletion_window_days" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 30
}

# ============================================================================
# Backup Schedule Configuration
# ============================================================================
variable "daily_backup_schedule" {
  description = "Cron expression for daily backups (UTC)"
  type        = string
  default     = "cron(0 18 * * ? *)"  # 18:00 UTC = 03:00 KST (next day)
}

variable "weekly_backup_schedule" {
  description = "Cron expression for weekly backups (UTC)"
  type        = string
  default     = "cron(0 18 ? * SUN *)"  # Sunday 18:00 UTC
}

variable "monthly_backup_schedule" {
  description = "Cron expression for monthly backups (UTC)"
  type        = string
  default     = "cron(0 18 1 * ? *)"  # 1st of month 18:00 UTC
}

variable "backup_start_window" {
  description = "Minutes before backup job starts (1-480)"
  type        = number
  default     = 60
}

variable "backup_completion_window" {
  description = "Minutes backup job must complete within (minimum 60)"
  type        = number
  default     = 180
}

# ============================================================================
# Retention Configuration
# ============================================================================
variable "daily_backup_retention_days" {
  description = "Number of days to retain daily backups"
  type        = number
  default     = 7
}

variable "weekly_backup_retention_days" {
  description = "Number of days to retain weekly backups"
  type        = number
  default     = 35
}

variable "monthly_backup_retention_days" {
  description = "Number of days to retain monthly backups"
  type        = number
  default     = 365
}

variable "cold_storage_after_days" {
  description = "Days after which backups are moved to cold storage (0 to disable)"
  type        = number
  default     = 0  # Disabled by default (cold storage has 90-day minimum)
}

# ============================================================================
# Cross-Region Backup Configuration
# ============================================================================
variable "enable_cross_region_backup" {
  description = "Enable cross-region backup copy for disaster recovery"
  type        = bool
  default     = false
}

variable "dr_region" {
  description = "DR region for cross-region backup copies"
  type        = string
  default     = "ap-northeast-1"  # Tokyo
}

variable "dr_kms_key_arn" {
  description = "KMS key ARN in DR region for backup encryption"
  type        = string
  default     = null
}

variable "dr_backup_retention_days" {
  description = "Number of days to retain DR region backups"
  type        = number
  default     = 30
}

# ============================================================================
# Vault Lock Configuration (Compliance)
# ============================================================================
variable "enable_vault_lock" {
  description = "Enable vault lock for compliance (WORM protection)"
  type        = bool
  default     = false
}

variable "vault_lock_min_retention_days" {
  description = "Minimum retention period for vault lock"
  type        = number
  default     = 7
}

variable "vault_lock_max_retention_days" {
  description = "Maximum retention period for vault lock"
  type        = number
  default     = 365
}

variable "vault_lock_changeable_days" {
  description = "Days during which vault lock can be changed (0 for immediate lock)"
  type        = number
  default     = 3
}

# ============================================================================
# Resource Selection Configuration
# ============================================================================
variable "backup_resource_arns" {
  description = "List of specific resource ARNs to backup"
  type        = list(string)
  default     = []
}

variable "enable_s3_backup" {
  description = "Enable S3 backup support"
  type        = bool
  default     = false
}

# ============================================================================
# Notification Configuration
# ============================================================================
variable "enable_backup_notifications" {
  description = "Enable SNS notifications for backup events"
  type        = bool
  default     = true
}

# ============================================================================
# Resource Creation Configuration (for multi-region deployments)
# ============================================================================
variable "create_iam_role" {
  description = "Whether to create IAM role (set to false in DR region to reuse existing role)"
  type        = bool
  default     = true
}

variable "existing_backup_role_arn" {
  description = "ARN of existing AWS Backup IAM role (required when create_iam_role is false)"
  type        = string
  default     = null
}
