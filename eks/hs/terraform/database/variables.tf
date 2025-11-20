# General Variables
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "hs-eks"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner of the infrastructure"
  type        = string
  default     = "kimhxsong"
}

# Remote State Configuration
variable "core_infra_state_bucket" {
  description = "S3 bucket name for core-infra remote state"
  type        = string
}

# RDS Variables
variable "rds_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.15"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GB for RDS"
  type        = number
  default     = 20
}

variable "rds_database_name" {
  description = "Name of the initial database"
  type        = string
  default     = "ticketdb"
}

variable "rds_username" {
  description = "Master username for RDS"
  type        = string
  default     = "ticket"
  sensitive   = true
}

variable "rds_password" {
  description = "Master password for RDS"
  type        = string
  default     = "ticketpass"
  sensitive   = true
}

# Database ports (keep in sync with core-infra/terraform.tfvars)
variable "rds_port" {
  description = "Port for RDS PostgreSQL"
  type        = number
  default     = 5432
}

variable "rds_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}

# ElastiCache Variables
variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 1
}

# Database ports (keep in sync with core-infra/terraform.tfvars)
variable "redis_port" {
  description = "Port for Redis"
  type        = number
  default     = 6379
}

variable "redis_parameter_group_family" {
  description = "Redis parameter group family"
  type        = string
  default     = "redis7"
}

# Cognito Variables
variable "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  type        = string
  default     = "ap-northeast-2_U5OVPrFCS"
  sensitive   = true
}

variable "cognito_client_id" {
  description = "Cognito Client ID"
  type        = string
  default     = "3v51kgfg28ku4r5onf9lfijsfj"
  sensitive   = true
}

# Tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

