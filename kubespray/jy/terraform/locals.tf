# locals.tf
# 목적: 계산된 값, 공통 태그, 자주 사용되는 값 정의
# Best Practice: 코드 중복 제거 및 중앙 집중식 관리

locals {
  # 프로젝트 식별자
  project_name = "ticket"
  owner        = "pjy"

  # 환경 설정 (변수에서 가져옴)
  environment = var.environment

  # 공통 태그 정의 (모든 리소스에 적용)
  common_tags = {
    Owner       = local.owner
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
    Team        = "kubespray"
    CostCenter  = "Engineering"
  }

  # 네트워크 설정
  vpc_cidr = "10.0.0.0/16"

  azs = {
    a = "ap-northeast-2a"
    b = "ap-northeast-2b"
  }

  # Subnet CIDR 블록 (계산된 값)
  public_subnet_cidrs = {
    a = "10.0.1.0/24" # AZ-A Public
    b = "10.0.2.0/24" # AZ-B Public
  }

  private_subnet_cidrs = {
    a = "10.0.11.0/24" # AZ-A Private
    b = "10.0.12.0/24" # AZ-B Private
  }

  # 도메인 설정
  domain_name = "kbsp.ddcn41.com"

  # Frontend 서브도메인
  frontend_domains = [
    "kbsp.ddcn41.com",
    "accounts.kbsp.ddcn41.com",
    "admin.kbsp.ddcn41.com"
  ]

  # Backend 서브도메인
  backend_domains = [
    "api.kbsp.ddcn41.com",
    "admin.api.kbsp.ddcn41.com",
    "queue.api.kbsp.ddcn41.com"
  ]

  # Auth 도메인
  auth_domain = "auth.api.kbsp.ddcn41.com"

  # EC2 인스턴스 타입
  instance_types = {
    control_plane = "t3.small"
    worker        = "t3.medium"
    bastion       = "t3.micro"
    nat           = "t3.micro"
  }

  # RDS 설정
  rds_config = {
    instance_class    = "db.t3.micro"
    allocated_storage = 20
    storage_type      = "gp2"
    engine_version    = "17.6" # PostgreSQL 17.6
  }

  # ElastiCache 설정
  elasticache_config = {
    node_type = "cache.t3.micro"
  }
}
