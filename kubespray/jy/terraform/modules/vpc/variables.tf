# modules/vpc/variables.tf
# VPC 모듈 입력 변수 정의

# ==========================================
# VPC 기본 설정
# ==========================================

variable "vpc_name" {
  description = "VPC 이름"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "올바른 CIDR 형식이어야 합니다. (예: 10.0.0.0/16)"
  }
}

variable "environment" {
  description = "환경 (dev, staging, prod)"
  type        = string
}

# ==========================================
# Availability Zones 설정
# ==========================================

variable "azs" {
  description = "사용할 Availability Zones"
  type        = map(string)
  default = {
    a = "ap-northeast-2a"
    b = "ap-northeast-2b"
  }
}

# ==========================================
# Subnet CIDR 설정
# ==========================================

variable "public_subnet_cidrs" {
  description = "Public Subnet CIDR 블록"
  type        = map(string)
  default = {
    a = "10.0.1.0/24"
    b = "10.0.2.0/24"
  }
}

variable "private_subnet_cidrs" {
  description = "Private Subnet CIDR 블록"
  type        = map(string)
  default = {
    a = "10.0.11.0/24"
    b = "10.0.12.0/24"
  }
}

# ==========================================
# 기능 토글
# ==========================================

variable "enable_dns_hostnames" {
  description = "VPC DNS 호스트네임 활성화"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "VPC DNS 지원 활성화"
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "NAT Gateway 사용 여부 (false면 NAT Instance 사용)"
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "단일 NAT Gateway 사용 여부 (비용 절감)"
  type        = bool
  default     = true
}

# ==========================================
# 태그
# ==========================================

variable "tags" {
  description = "리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}