# ============================================================================
# Common Variables
# ============================================================================
variable "project_name" {
  description = "Project name (same as Seoul for DR consistency)"
  type        = string
  default     = "ticket-hs"
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
  default     = "10.1.0.0/16"  # Different CIDR from Seoul for potential VPC peering
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.1.10.0/24", "10.1.11.0/24"]
}

variable "database_subnet_cidrs" {
  description = "Database subnet CIDR blocks"
  type        = list(string)
  default     = ["10.1.20.0/24", "10.1.21.0/24"]
}

# ============================================================================
# EKS Variables
# ============================================================================
variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "node_instance_type" {
  description = "EKS node instance type"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "EKS node desired size (smaller for DR standby)"
  type        = number
  default     = 1
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
  description = "RDS instance class (smaller for DR standby)"
  type        = string
  default     = "db.t3.micro"
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
# Velero Variables
# ============================================================================
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
