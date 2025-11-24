# Day3-4 Development Environment
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "ticketing-terraform-state-guk"
    key            = "dev/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-northeast-2"
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# VPC 모듈 호출
module "vpc" {
  source = "../../modules/vpc"
  
  project_name             = var.project_name
  environment             = var.environment
  vpc_cidr                = var.vpc_cidr
  availability_zones      = var.availability_zones
  public_subnet_cidrs     = var.public_subnet_cidrs
  private_subnet_cidrs    = var.private_subnet_cidrs
  database_subnet_cidrs   = var.database_subnet_cidrs
}

# ALB 모듈
module "alb" {
  source = "../../modules/alb"
  
  project_name           = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.vpc.alb_security_group_id
}

# EKS 모듈
module "eks" {
  source = "../../modules/eks"
  
  project_name           = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  node_security_group_id = module.vpc.eks_nodes_security_group_id
  
  kubernetes_version = var.kubernetes_version
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
}

# RDS 모듈
module "rds" {
  source = "../../modules/rds"
  
  project_name            = var.project_name
  environment            = var.environment
  database_subnet_ids    = module.vpc.database_subnet_ids
  rds_security_group_id  = module.vpc.rds_security_group_id
  
  db_instance_class      = var.db_instance_class
  db_allocated_storage   = var.db_allocated_storage
  db_password           = var.db_password
}

# Redis 모듈
module "redis" {
  source = "../../modules/redis"
  
  project_name             = var.project_name
  environment             = var.environment
  database_subnet_ids     = module.vpc.database_subnet_ids
  redis_security_group_id = module.vpc.redis_security_group_id
  
  redis_node_type = var.redis_node_type
}
