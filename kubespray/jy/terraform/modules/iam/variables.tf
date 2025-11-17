# modules/iam/variables.tf
# IAM 모듈 입력 변수

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
# S3 버킷 설정
# ==========================================

# variable "s3_bucket_names" {
#   description = "Frontend S3 버킷 이름 목록"
#   type        = list(string)
# }

# variable "cloudfront_distribution_arn" {
#   description = "CloudFront Distribution ARN (캐시 무효화용)"
#   type        = string
#   default     = "*" # CloudFront 생성 전에는 와일드카드
# }

# ==========================================
# ECR 설정
# ==========================================

# variable "ecr_repository_arns" {
#   description = "ECR Repository ARN 목록"
#   type        = list(string)
#   default     = []
# }

# ==========================================
# GitHub Actions OIDC
# ==========================================

# variable "github_org" {
#   description = "GitHub Organization 또는 사용자 이름"
#   type        = string
# }

# variable "github_repo" {
#   description = "GitHub Repository 이름"
#   type        = string
# }

# variable "github_branches" {
#   description = "GitHub Actions 실행을 허용할 브랜치 목록"
#   type        = list(string)
#   default     = ["main", "develop"]
# }

# ==========================================
# Kubernetes 설정
# ==========================================

variable "k8s_cluster_name" {
  description = "Kubernetes 클러스터 이름"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (ALB 생성용)"
  type        = string
}

# ==========================================
# Route 53 설정
# ==========================================

variable "route53_zone_id" {
  description = "Route 53 Hosted Zone ID"
  type        = string
  default     = "*" # Route 53 생성 전에는 와일드카드
}

# ==========================================
# 태그
# ==========================================

variable "tags" {
  description = "리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}
