# modules/security-groups/variables.tf
# Security Groups 모듈 입력 변수

# ==========================================
# 기본 설정
# ==========================================

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
}

variable "environment" {
  description = "환경 (dev, staging, prod)"
  type        = string
}

variable "name_prefix" {
  description = "Security Group 이름 접두사"
  type        = string
}

# ==========================================
# 네트워크 설정
# ==========================================

variable "private_subnet_cidrs" {
  description = "Private Subnet CIDR 블록 리스트"
  type        = list(string)
}

# ==========================================
# 접근 제어 설정
# ==========================================

variable "allowed_ssh_cidr" {
  description = "Bastion Host SSH 접근 허용 IP (관리자 IP)"
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "올바른 CIDR 형식이어야 합니다. (예: 1.2.3.4/32)"
  }
}

variable "allowed_ssh_cidrs" {
  description = "SSH 접근 허용 IP 리스트 (여러 관리자)"
  type        = list(string)
  default     = []
}

# ==========================================
# Kubernetes 설정
# ==========================================

variable "k8s_api_port" {
  description = "Kubernetes API Server 포트"
  type        = number
  default     = 6443
}

variable "k8s_node_port_range" {
  description = "Kubernetes NodePort 범위"
  type = object({
    from = number
    to   = number
  })
  default = {
    from = 30000
    to   = 32767
  }
}

variable "application_port" {
  description = "애플리케이션 포트 (Spring Boot)"
  type        = number
  default     = 8080
}

# ==========================================
# 데이터베이스 설정
# ==========================================

variable "rds_port" {
  description = "RDS PostgreSQL 포트"
  type        = number
  default     = 5432
}

variable "redis_port" {
  description = "Redis 포트"
  type        = number
  default     = 6379
}

# ==========================================
# 태그
# ==========================================

variable "tags" {
  description = "리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}
