# modules/secrets/variables.tf
# Secrets Manager 모듈 입력 변수

# ==========================================
# 기본 설정
# ==========================================

variable "environment" {
  description = "환경 (dev, staging, prod)"
  type        = string
}

variable "name_prefix" {
  description = "리소스 이름 접두사"
  type        = string
}

# ==========================================
# Database Credentials
# ==========================================

variable "db_master_username" {
  description = "DB 마스터 사용자 이름"
  type        = string
  sensitive   = true
}

variable "db_master_password" {
  description = "DB 마스터 비밀번호"
  type        = string
  sensitive   = true
}

variable "db_host" {
  description = "DB 호스트"
  type        = string
}

variable "db_port" {
  description = "DB 포트"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "DB 이름"
  type        = string
}

# ==========================================
# Redis Credentials
# ==========================================

variable "redis_host" {
  description = "Redis 호스트"
  type        = string
}

variable "redis_port" {
  description = "Redis 포트"
  type        = number
  default     = 6379
}

# ==========================================
# Application Secrets
# ==========================================

variable "api_keys" {
  description = "외부 API 키 맵"
  type        = map(string)
  sensitive   = true
  default     = {}
}

# ==========================================
# Secrets 설정
# ==========================================

variable "recovery_window_in_days" {
  description = "Secret 삭제 후 복구 가능 기간 (일)"
  type        = number
  default     = 7

  validation {
    condition     = var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30
    error_message = "복구 기간은 7~30일 사이여야 합니다."
  }
}

variable "enable_rotation" {
  description = "자동 rotation 활성화"
  type        = bool
  default     = false # Lambda 함수 필요
}

# ==========================================
# 태그
# ==========================================

variable "tags" {
  description = "리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}
