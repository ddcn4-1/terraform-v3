# modules/database/variables.tf
# 데이터베이스 모듈 입력 변수

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
# VPC 및 네트워크 설정
# ==========================================

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private Subnet IDs (DB용)"
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "RDS Security Group ID"
  type        = string
}

variable "elasticache_security_group_id" {
  description = "ElastiCache Security Group ID"
  type        = string
}

# ==========================================
# RDS 설정
# ==========================================

variable "rds_instance_class" {
  description = "RDS 인스턴스 클래스"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "RDS 스토리지 크기 (GB)"
  type        = number
  default     = 20
}

# variable "rds_max_allocated_storage" {
#   description = "RDS 최대 스토리지 크기 (GB) - Auto Scaling"
#   type        = number
#   default     = 100
# }

variable "rds_storage_type" {
  description = "RDS 스토리지 타입 (gp2, gp3, io1)"
  type        = string
  default     = "gp2"
}

variable "rds_engine_version" {
  description = "PostgreSQL 엔진 버전"
  type        = string
  default     = "17.6"
}

variable "db_name" {
  description = "데이터베이스 이름"
  type        = string
}

variable "db_username" {
  description = "마스터 사용자 이름"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "마스터 비밀번호"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "비밀번호는 최소 8자 이상이어야 합니다."
  }
}

variable "rds_multi_az" {
  description = "Multi-AZ 배포 여부"
  type        = bool
  default     = false
}

variable "rds_backup_retention_period" {
  description = "백업 보관 기간 (일)"
  type        = number
  default     = 7
}

variable "rds_backup_window" {
  description = "백업 시간대 (UTC)"
  type        = string
  default     = "03:00-04:00" # 한국 시간 12:00-13:00
}

variable "rds_maintenance_window" {
  description = "유지보수 시간대 (UTC)"
  type        = string
  default     = "mon:04:00-mon:05:00" # 한국 시간 월요일 13:00-14:00
}

variable "rds_deletion_protection" {
  description = "삭제 방지 활성화"
  type        = bool
  default     = false # 개발 환경에서는 false
}

variable "rds_skip_final_snapshot" {
  description = "최종 스냅샷 건너뛰기"
  type        = bool
  default     = true # 개발 환경에서는 true
}

variable "rds_storage_encrypted" {
  description = "스토리지 암호화 활성화"
  type        = bool
  default     = true
}

variable "rds_performance_insights_enabled" {
  description = "Performance Insights 활성화"
  type        = bool
  default     = false # t3.micro는 지원 안 함
}

# ==========================================
# ElastiCache Redis 설정
# ==========================================

variable "redis_node_type" {
  description = "Redis 노드 타입"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  description = "Redis 노드 개수"
  type        = number
  default     = 1
}

variable "redis_parameter_group_family" {
  description = "Redis 파라미터 그룹 패밀리"
  type        = string
  default     = "redis7"
}

variable "redis_engine_version" {
  description = "Redis 엔진 버전"
  type        = string
  default     = "7.0"
}

variable "redis_port" {
  description = "Redis 포트"
  type        = number
  default     = 6379
}

variable "redis_automatic_failover_enabled" {
  description = "자동 장애 조치 활성화 (Cluster Mode)"
  type        = bool
  default     = false
}

variable "redis_at_rest_encryption_enabled" {
  description = "저장 데이터 암호화"
  type        = bool
  default     = true
}

variable "redis_transit_encryption_enabled" {
  description = "전송 중 암호화 (TLS)"
  type        = bool
  default     = false # 애플리케이션 호환성 고려
}

variable "redis_snapshot_retention_limit" {
  description = "스냅샷 보관 기간 (일)"
  type        = number
  default     = 5
}

variable "redis_snapshot_window" {
  description = "스냅샷 시간대 (UTC)"
  type        = string
  default     = "03:00-05:00"
}

variable "redis_maintenance_window" {
  description = "유지보수 시간대 (UTC)"
  type        = string
  default     = "mon:05:00-mon:07:00"
}

# ==========================================
# 태그
# ==========================================

variable "tags" {
  description = "리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}
