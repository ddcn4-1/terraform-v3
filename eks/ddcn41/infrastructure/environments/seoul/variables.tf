# ============================================================================
# Common Variables
# ============================================================================
variable "project_name" {
  description = "Project name (differs from dev to avoid resource conflicts)"
  type        = string
  default     = "ddcn41-eks"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

# ============================================================================
# VPC Variables
# ============================================================================
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "database_subnet_cidrs" {
  description = "Database subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

# ============================================================================
# EKS Variables
# ============================================================================
variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.32"
}

variable "node_instance_type" {
  description = "EKS node instance type"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "EKS node desired size"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "EKS node min size"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "EKS node max size"
  type        = number
  default     = 5
}

# ============================================================================
# RDS Variables
# ============================================================================
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.small"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage"
  type        = number
  default     = 20
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

# ============================================================================
# Redis Variables
# ============================================================================
variable "redis_node_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

# ============================================================================
# ECR Variables
# ============================================================================
variable "ecr_repository_names" {
  description = "List of ECR repository names"
  type        = list(string)
  default     = ["backend", "frontend"]
}

# ============================================================================
# Disaster Recovery Variables
# ============================================================================
variable "enable_dr" {
  description = "Enable disaster recovery features (S3/ECR cross-region replication)"
  type        = bool
  default     = true  # S3/ECR Cross-Region Replication (Seoul → Tokyo)
}

variable "tokyo_cluster_exists" {
  description = "Whether Tokyo EKS cluster exists for OIDC cross-reference. Set false before destroying Tokyo."
  type        = bool
  default     = false  # 도쿄 클러스터 생성 후 true로 변경
}

variable "velero_backup_retention_days" {
  description = "Number of days to retain Velero backups"
  type        = number
  default     = 90
}

variable "velero_glacier_transition_days" {
  description = "Days before moving Velero backups to Glacier"
  type        = number
  default     = 30
}

variable "tokyo_backup_kms_key_arn" {
  description = "KMS key ARN in Tokyo region for cross-region backup encryption"
  type        = string
  default     = null
}
