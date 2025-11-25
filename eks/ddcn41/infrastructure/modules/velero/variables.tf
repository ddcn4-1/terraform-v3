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

variable "aws_region" {
  description = "AWS region for the primary Velero bucket"
  type        = string
}

variable "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN for IRSA"
  type        = string
}

# ============================================================================
# Backup Retention Configuration
# ============================================================================
variable "backup_retention_days" {
  description = "Number of days to retain backups before deletion"
  type        = number
  default     = 90
}

variable "backup_transition_glacier_days" {
  description = "Number of days before transitioning backups to Glacier storage"
  type        = number
  default     = 30
}

variable "kms_deletion_window_days" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 30
}

# ============================================================================
# Cross-Region Replication Configuration
# ============================================================================
variable "enable_cross_region_replication" {
  description = "Enable cross-region replication for disaster recovery"
  type        = bool
  default     = false
}

variable "replication_region" {
  description = "AWS region for backup replication (e.g., ap-northeast-1 for Tokyo)"
  type        = string
  default     = "ap-northeast-1"
}

# ============================================================================
# Resource Creation Configuration (for multi-region deployments)
# ============================================================================
variable "create_bucket" {
  description = "Whether to create S3 bucket (set to false in DR region where bucket is created by replication)"
  type        = bool
  default     = true
}

variable "create_iam_role" {
  description = "Whether to create IAM role (set to false in DR region to reuse existing role)"
  type        = bool
  default     = true
}

variable "existing_velero_role_arn" {
  description = "ARN of existing Velero IAM role (required when create_iam_role is false)"
  type        = string
  default     = null
}

variable "existing_bucket_arn" {
  description = "ARN of existing S3 bucket (required when create_bucket is false)"
  type        = string
  default     = null
}

variable "existing_bucket_id" {
  description = "ID/name of existing S3 bucket (required when create_bucket is false)"
  type        = string
  default     = null
}

# ============================================================================
# Multi-Region IRSA Configuration
# ============================================================================
variable "additional_oidc_providers" {
  description = "Additional EKS OIDC provider ARNs to allow AssumeRoleWithWebIdentity (for multi-region IRSA)"
  type        = list(string)
  default     = []
}
