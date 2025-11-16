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

