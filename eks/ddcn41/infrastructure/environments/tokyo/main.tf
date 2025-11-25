# Tokyo Region (ap-northeast-1) - DR/Secondary Cluster
# Designed for Velero restore and disaster recovery failover

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # 기존 dev 환경과 분리된 상태 관리
  # State는 서울에 유지 (단일 상태 저장소)
  backend "s3" {
    bucket         = "ticketing-terraform-state-guk"
    key            = "multiregion/tokyo/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

# Tokyo region provider (primary for this environment)
provider "aws" {
  region = "ap-northeast-1"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Region      = "tokyo"
      ManagedBy   = "terraform"
      Owner       = "kimhxsong"
      Purpose     = "disaster-recovery"
    }
  }
}

# Seoul region provider for cross-region access
provider "aws" {
  alias  = "seoul"
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

# Dummy replication provider (required by velero module, not used in DR site)
provider "aws" {
  alias  = "replication"
  region = "ap-northeast-2"  # Points to Seoul, but not used since CRR is disabled

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "kimhxsong"
    }
  }
}

# Dummy DR provider (required by aws-backup module, not used in DR site)
provider "aws" {
  alias  = "dr"
  region = "ap-northeast-2"  # Points to Seoul, but not used since cross-region backup is disabled

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

# Seoul 상태에서 IAM Role ARN 자동 참조
data "terraform_remote_state" "seoul" {
  backend = "s3"
  config = {
    bucket = "ticketing-terraform-state-guk"
    key    = "multiregion/seoul/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Reference the replicated Velero bucket in Tokyo (created by Seoul's cross-region replication)
# Seoul 버킷: ddcn41-eks-velero-prod-ap-northeast-2
# Tokyo 복제 버킷: ddcn41-eks-velero-prod-ap-northeast-1
data "aws_s3_bucket" "tokyo_replica_velero" {
  bucket = "${var.project_name}-velero-${var.environment}-ap-northeast-1"
}

# Seoul 원본 버킷 참조 (restore 명령어 출력용)
data "aws_s3_bucket" "seoul_velero" {
  provider = aws.seoul
  bucket   = "${var.project_name}-velero-${var.environment}-ap-northeast-2"
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
# EKS Module (reuse IAM roles from Seoul)
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

  # Reuse IAM roles from Seoul (IAM is global)
  create_iam_roles          = false
  existing_cluster_role_arn = data.terraform_remote_state.seoul.outputs.eks_cluster_iam_role_arn
  existing_node_role_arn    = data.terraform_remote_state.seoul.outputs.eks_node_iam_role_arn
}

# ============================================================================
# RDS Module (Standby - can be promoted during DR)
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
# Velero Module (reference Seoul's replicated bucket, no new IAM/bucket creation)
# ============================================================================
module "velero" {
  source = "../../modules/velero"

  providers = {
    aws             = aws
    aws.replication = aws.replication  # Not used, but required by module
  }

  project_name          = var.project_name
  environment           = var.environment
  aws_region            = "ap-northeast-1"
  eks_oidc_provider_arn = module.eks.oidc_provider_arn

  backup_retention_days           = var.velero_backup_retention_days
  backup_transition_glacier_days  = var.velero_glacier_transition_days
  enable_cross_region_replication = false  # Tokyo is the DR site

  # Don't create new bucket or IAM role - use Seoul's replicated bucket and reference existing role
  create_bucket            = false
  create_iam_role          = false
  existing_bucket_arn      = data.aws_s3_bucket.tokyo_replica_velero.arn
  existing_bucket_id       = data.aws_s3_bucket.tokyo_replica_velero.id
  existing_velero_role_arn = data.terraform_remote_state.seoul.outputs.velero_role_arn
}

# ============================================================================
# Additional IAM Policy for Tokyo Replica Bucket Access
# Seoul에서 복제된 Tokyo 버킷에 대한 접근 권한
# ============================================================================
resource "aws_iam_role_policy" "velero_replica_bucket_access" {
  name = "${var.project_name}-velero-replica-access"
  role = module.velero.velero_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TokyoReplicaBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = [
          data.aws_s3_bucket.tokyo_replica_velero.arn,
          "${data.aws_s3_bucket.tokyo_replica_velero.arn}/*"
        ]
      }
    ]
  })
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
# AWS Backup Module (Local backups, reuse IAM role from Seoul)
# ============================================================================
module "aws_backup" {
  source = "../../modules/aws-backup"

  providers = {
    aws    = aws
    aws.dr = aws.dr  # Not used, but required by module
  }

  project_name = var.project_name
  environment  = var.environment

  daily_backup_retention_days   = 7
  weekly_backup_retention_days  = 35
  monthly_backup_retention_days = 365

  enable_cross_region_backup  = false  # No further replication from DR site
  enable_backup_notifications = true

  # Reuse IAM role from Seoul (IAM is global)
  create_iam_role          = false
  existing_backup_role_arn = data.terraform_remote_state.seoul.outputs.backup_role_arn

  backup_resource_arns = [
    module.rds.db_instance_arn
  ]
}
