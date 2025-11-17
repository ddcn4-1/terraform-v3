# variables.tf
# 목적: 외부에서 입력받을 수 있는 변수 정의
# Best Practice: 유연성과 재사용성 향상

# ==========================================
# 기본 설정
# ==========================================

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS 리전 형식이 올바르지 않습니다. (예: ap-northeast-2)"
  }
}

variable "environment" {
  description = "환경 (dev, staging, prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "환경은 dev, staging, prod 중 하나여야 합니다."
  }
}

# ==========================================
# 네트워크 설정
# ==========================================

variable "allowed_ssh_cidr" {
  description = "Bastion Host SSH 접근 허용 IP (관리자 IP)"
  type        = string

  # 보안을 위해 기본값 없음 - 반드시 명시적으로 설정
  # terraform.tfvars에서 설정 필요

  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "올바른 CIDR 형식이어야 합니다. (예: 1.2.3.4/32)"
  }
}

variable "enable_nat_gateway" {
  description = "NAT Gateway 사용 여부 (false면 NAT Instance 사용)"
  type        = bool
  default     = false # 교육 목적으로 NAT Instance 사용
}

# ==========================================
# EC2 설정
# ==========================================

variable "key_pair_name" {
  description = "EC2 SSH 접근용 Key Pair 이름"
  type        = string

  # 사전에 AWS에서 생성된 Key Pair 이름
  # aws ec2 create-key-pair --key-name ddcn41-key 로 생성
}

variable "k8s_cluster_name" {
  description = "Kubernetes 클러스터 이름"
  type        = string
  default     = "kubernetes-pjy"
}

variable "worker_node_count" {
  description = "Kubernetes Worker Node 개수"
  type        = number
  default     = 2

  validation {
    condition     = var.worker_node_count >= 1 && var.worker_node_count <= 10
    error_message = "Worker Node는 1~10개 사이여야 합니다."
  }
}

variable "k8s_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.34.1"
}

variable "kubespray_version" {
  description = "Kubespray version"
  type        = string
  default     = "2.29"
}

variable "root_volume_size" {
  description = "EC2 EBS volume size (GB)"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "EC2 EBS volume type"
  type        = string
  default     = "gp3"
}
# ==========================================
# RDS 설정
# ==========================================

variable "db_name" {
  description = "RDS 데이터베이스 이름"
  type        = string
  default     = "ticket"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "데이터베이스 이름은 문자로 시작하고 영숫자와 _만 포함해야 합니다."
  }
}

variable "db_username" {
  description = "RDS 마스터 사용자 이름"
  type        = string
  default     = "ticket"
  sensitive   = true # 로그에 출력되지 않음
}

variable "db_password" {
  description = "RDS 마스터 비밀번호 (최소 8자)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "비밀번호는 최소 8자 이상이어야 합니다."
  }
}

variable "db_multi_az" {
  description = "RDS Multi-AZ 배포 여부"
  type        = bool
  default     = false # 비용 절감을 위해 Single AZ
}

# ==========================================
# ElastiCache 설정
# ==========================================

variable "redis_num_cache_nodes" {
  description = "Redis 노드 개수"
  type        = number
  default     = 1
}

# ==========================================
# S3 설정
# ==========================================

variable "s3_bucket_names" {
  description = "Frontend용 S3 버킷 이름들"
  type = object({
    main     = string
    accounts = string
    admin    = string
  })
  default = {
    main     = "ddcn41-main-frontend"
    accounts = "ddcn41-accounts-frontend"
    admin    = "ddcn41-admin-frontend"
  }
}

# ==========================================
# Route 53 설정
# ==========================================

variable "domain_name" {
  description = "Route 53 도메인 이름"
  type        = string
  default     = "pjy.ddcn41.com"
}

# ==========================================
# 기능 토글 (Feature Flags)
# ==========================================

variable "enable_waf" {
  description = "WAF 활성화 여부"
  type        = bool
  default     = true
}

variable "enable_cloudtrail" {
  description = "CloudTrail 활성화 여부"
  type        = bool
  default     = true
}
