variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
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
# ALB 관련 변수들
variable "alb_enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false
}

variable "alb_health_check_path" {
  description = "Health check path for target groups"
  type        = string
  default     = "/actuator/health"
}

variable "alb_health_check_port" {
  description = "Health check port for target groups"
  type        = number
  default     = 8080
}

# EKS 변수들
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
  description = "EKS node desired size"
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
  default     = 3
}

# RDS 변수들
variable "db_instance_class" {
  description = "RDS instance class"
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

# Redis 변수들  
variable "redis_node_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.t3.micro"
}
