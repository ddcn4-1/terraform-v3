# Seoul Region (ap-northeast-2) - Primary Cluster
# Multi-region EKS infrastructure with Velero migration support

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # 기존 dev 환경과 분리된 상태 관리
  # dev: dev/terraform.tfstate (기존 클러스터)
  # seoul: multiregion/seoul/terraform.tfstate (새 프로덕션)
  # tokyo: multiregion/tokyo/terraform.tfstate (DR)
  backend "s3" {
    bucket         = "ticketing-terraform-state-guk"
    key            = "multiregion/seoul/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

# Primary region provider
provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Region      = "seoul"
      ManagedBy   = "terraform"
      Owner       = "kimhxsong"
    }
  }
}

# DR region provider for cross-region resources
provider "aws" {
  alias  = "tokyo"
  region = "ap-northeast-1"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Region      = "tokyo"
      ManagedBy   = "terraform"
      Owner       = "kimhxsong"
    }
  }
}

# Replication provider alias for Velero module
provider "aws" {
  alias  = "replication"
  region = "ap-northeast-1"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "kimhxsong"
    }
  }
}

# ============================================================================
# Data Sources
# ============================================================================
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Tokyo EKS OIDC Provider for multi-region Velero IRSA
# This allows Tokyo cluster to use Seoul's Velero IAM Role
data "aws_eks_cluster" "tokyo" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.tokyo
  name     = "${var.project_name}-cluster"
}

data "aws_iam_openid_connect_provider" "tokyo" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.tokyo
  url      = data.aws_eks_cluster.tokyo[0].identity[0].oidc[0].issuer
}

# ============================================================================
# VPC Module
# ============================================================================
module "vpc" {
  source = "../../modules/vpc"

  project_name           = var.project_name
  environment            = var.environment
  vpc_cidr               = var.vpc_cidr
  availability_zones     = var.availability_zones
  public_subnet_cidrs    = var.public_subnet_cidrs
  private_subnet_cidrs   = var.private_subnet_cidrs
  database_subnet_cidrs  = var.database_subnet_cidrs
}

# ============================================================================
# ALB Module
# ============================================================================
module "alb" {
  source = "../../modules/alb"

  project_name           = var.project_name
  environment            = var.environment
  vpc_id                 = module.vpc.vpc_id
  public_subnet_ids      = module.vpc.public_subnet_ids
  alb_security_group_id  = module.vpc.alb_security_group_id
}

# ============================================================================
# EKS Module
# ============================================================================
module "eks" {
  source = "../../modules/eks"

  project_name           = var.project_name
  environment            = var.environment
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  node_security_group_id = module.vpc.eks_nodes_security_group_id

  kubernetes_version = var.kubernetes_version
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
}

# ============================================================================
# RDS Module
# ============================================================================
module "rds" {
  source = "../../modules/rds"

  project_name           = var.project_name
  environment            = var.environment
  database_subnet_ids    = module.vpc.database_subnet_ids
  rds_security_group_id  = module.vpc.rds_security_group_id

  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  db_password          = var.db_password
}

# ============================================================================
# Redis Module
# ============================================================================
module "redis" {
  source = "../../modules/redis"

  project_name             = var.project_name
  environment              = var.environment
  database_subnet_ids      = module.vpc.database_subnet_ids
  redis_security_group_id  = module.vpc.redis_security_group_id

  redis_node_type = var.redis_node_type
}

# ============================================================================
# ECR Module with Cross-Region Replication
# ============================================================================
module "ecr" {
  source = "../../modules/ecr"

  project_name     = var.project_name
  environment      = var.environment
  repository_names = var.ecr_repository_names

  enable_cross_region_replication = var.enable_dr
  replication_regions             = ["ap-northeast-1"]  # Tokyo

  scan_on_push     = true
  image_count_to_keep = 30
}

# ============================================================================
# Velero Module for Cluster Migration
# ============================================================================
module "velero" {
  source = "../../modules/velero"

  providers = {
    aws             = aws
    aws.replication = aws.replication
  }

  project_name          = var.project_name
  environment           = var.environment
  aws_region            = "ap-northeast-2"
  eks_oidc_provider_arn = module.eks.oidc_provider_arn

  # Add Tokyo OIDC provider for multi-region IRSA (allows Tokyo to use Seoul's IAM Role)
  additional_oidc_providers = var.enable_dr ? [data.aws_iam_openid_connect_provider.tokyo[0].arn] : []

  backup_retention_days           = var.velero_backup_retention_days
  backup_transition_glacier_days  = var.velero_glacier_transition_days
  enable_cross_region_replication = var.enable_dr
  replication_region              = "ap-northeast-1"
}

# ============================================================================
# Private Hosted Zone for DNS Abstraction
# ============================================================================
module "phz" {
  source = "../../modules/phz"

  project_name = var.project_name
  environment  = var.environment
  domain_name  = "${var.project_name}.internal"
  vpc_id       = module.vpc.vpc_id

  rds_endpoint   = module.rds.endpoint
  redis_endpoint = module.redis.endpoint

  dns_ttl = 300  # 5 minutes for DR failover balance
}

# ============================================================================
# AWS Backup Module
# ============================================================================
module "aws_backup" {
  source = "../../modules/aws-backup"

  providers = {
    aws    = aws
    aws.dr = aws.tokyo
  }

  project_name = var.project_name
  environment  = var.environment

  daily_backup_retention_days   = 7
  weekly_backup_retention_days  = 35
  monthly_backup_retention_days = 365

  enable_cross_region_backup = var.enable_dr
  dr_region                  = "ap-northeast-1"
  dr_kms_key_arn             = var.tokyo_backup_kms_key_arn

  enable_backup_notifications = true

  # Tag RDS and EBS for backup
  backup_resource_arns = [
    module.rds.db_instance_arn
  ]
}
