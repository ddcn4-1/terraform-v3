# main.tf (Root Module)

# ==========================================
# VPC 및 네트워킹
# ==========================================

module "vpc" {
  source = "./modules/vpc"

  # VPC 기본 설정
  vpc_name    = local.project_name
  vpc_cidr    = local.vpc_cidr
  environment = local.environment

  # Availability Zones
  azs = local.azs

  # Subnet CIDR 블록
  public_subnet_cidrs  = local.public_subnet_cidrs
  private_subnet_cidrs = local.private_subnet_cidrs

  # 기능 활성화
  enable_nat_gateway = var.enable_nat_gateway

  # 태그
  tags = local.common_tags
}

# ==========================================
# Security Groups
# ==========================================

module "security_groups" {
  source = "./modules/security-groups"

  # VPC 정보
  vpc_id   = module.vpc.vpc_id
  vpc_cidr = module.vpc.vpc_cidr_block

  # 환경 설정
  environment = local.environment
  name_prefix = "${local.project_name}-${local.environment}"

  # Private Subnet CIDR 리스트
  private_subnet_cidrs = values(local.private_subnet_cidrs)

  # SSH 접근 제어
  allowed_ssh_cidr = var.allowed_ssh_cidr

  # 포트 설정
  application_port = 8080
  rds_port         = 5432
  redis_port       = 6379

  # 태그
  tags = local.common_tags

  # VPC 모듈에 의존
  depends_on = [module.vpc]
}
