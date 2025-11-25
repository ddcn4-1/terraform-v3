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

variable "repository_names" {
  description = "List of ECR repository names to create"
  type        = list(string)
  default     = ["backend", "frontend"]
}

# ============================================================================
# Repository Configuration
# ============================================================================
variable "image_tag_mutability" {
  description = "Image tag mutability setting (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be either MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Enable image vulnerability scanning on push"
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "Encryption type for the repository (AES256 or KMS)"
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "KMS"], var.encryption_type)
    error_message = "encryption_type must be either AES256 or KMS."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN for repository encryption (required if encryption_type is KMS)"
  type        = string
  default     = null
}

# ============================================================================
# Lifecycle Policy Configuration
# ============================================================================
variable "image_count_to_keep" {
  description = "Number of production images to keep"
  type        = number
  default     = 30
}

variable "dev_image_count_to_keep" {
  description = "Number of dev/staging images to keep"
  type        = number
  default     = 10
}

variable "untagged_image_retention_days" {
  description = "Number of days to keep untagged images"
  type        = number
  default     = 14
}

# ============================================================================
# Cross-Region Replication Configuration
# ============================================================================
variable "enable_cross_region_replication" {
  description = "Enable cross-region replication for ECR repositories"
  type        = bool
  default     = false
}

variable "replication_regions" {
  description = "List of AWS regions to replicate images to"
  type        = list(string)
  default     = ["ap-northeast-1"]  # Tokyo as default DR region
}

variable "replication_repository_filter" {
  description = "Repository prefix filter for replication (null for all repositories)"
  type        = string
  default     = null
}

# ============================================================================
# Pull Through Cache Configuration
# ============================================================================
variable "enable_pull_through_cache" {
  description = "Enable ECR pull through cache for upstream registries"
  type        = bool
  default     = false
}

variable "enable_quay_cache" {
  description = "Enable pull through cache for Quay.io"
  type        = bool
  default     = false
}

variable "enable_k8s_cache" {
  description = "Enable pull through cache for Kubernetes registry"
  type        = bool
  default     = true
}

variable "dockerhub_credential_secret_arn" {
  description = "ARN of Secrets Manager secret containing Docker Hub credentials"
  type        = string
  default     = null
}

# ============================================================================
# Cross-Account Access Configuration
# ============================================================================
variable "cross_account_arns" {
  description = "List of AWS account ARNs that can pull images"
  type        = list(string)
  default     = null
}
