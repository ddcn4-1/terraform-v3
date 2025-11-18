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
  name_prefix = "${local.owner}-${local.project_name}-${local.environment}"

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

# ==========================================
# IAM Roles 및 Policies
# ==========================================

module "iam" {
  source = "./modules/iam"

  # 기본 설정
  environment = local.environment
  name_prefix = "${local.owner}-${local.project_name}-${local.environment}"

  # # S3 버킷 (Frontend)
  # s3_bucket_names = values(var.s3_bucket_names)

  # # CloudFront (생성 후 업데이트)
  # cloudfront_distribution_arn = "*" # 초기에는 와일드카드

  # # ECR Repository (생성 후 업데이트)
  # ecr_repository_arns = []

  # # GitHub Actions OIDC
  # github_org      = var.github_org
  # github_repo     = var.github_repo
  # github_branches = var.github_branches

  # Kubernetes
  k8s_cluster_name = var.k8s_cluster_name
  vpc_id           = module.vpc.vpc_id

  # Route 53 (생성 후 업데이트)
  route53_zone_id = "*"

  depends_on = [module.vpc]

  # 태그
  tags = local.common_tags
}

# ==========================================
# EC2 인스턴스
# ==========================================

module "ec2" {
  source = "./modules/ec2"

  # 기본 설정
  environment = local.environment
  name_prefix = "${local.owner}-${local.project_name}-${local.environment}"

  # VPC 및 Subnet
  vpc_id                  = module.vpc.vpc_id
  public_subnet_a_id      = module.vpc.public_subnet_a_id
  public_subnet_b_id      = module.vpc.public_subnet_b_id
  private_subnet_a_id     = module.vpc.private_subnet_a_id
  private_subnet_b_id     = module.vpc.private_subnet_b_id
  private_route_table_ids = module.vpc.private_route_table_ids

  # Security Groups
  nat_instance_security_group_id  = module.security_groups.nat_instance_security_group_id
  bastion_security_group_id       = module.security_groups.bastion_security_group_id
  control_plane_security_group_id = module.security_groups.control_plane_security_group_id
  worker_node_security_group_id   = module.security_groups.worker_node_security_group_id

  # SSH Key
  key_pair_name = var.key_pair_name

  # Instance Types
  nat_instance_type           = local.instance_types.nat
  bastion_instance_type       = local.instance_types.bastion
  control_plane_instance_type = local.instance_types.control_plane
  worker_node_instance_type   = local.instance_types.worker

  # Kubernetes 설정
  k8s_cluster_name  = var.k8s_cluster_name
  k8s_version       = var.k8s_version
  kubespray_version = var.kubespray_version
  worker_node_count = var.worker_node_count

  # IAM
  ec2_kubernetes_instance_profile_name = module.iam.ec2_kubernetes_instance_profile_name

  # EBS
  root_volume_size      = var.root_volume_size
  root_volume_type      = var.root_volume_type
  enable_ebs_encryption = true

  # 태그
  tags = local.common_tags

  # 의존성
  depends_on = [
    module.vpc,
    module.security_groups,
    module.iam
  ]
}

# ==========================================
# 데이터베이스 (RDS & ElastiCache)
# ==========================================

module "database" {
  source = "./modules/database"

  # 기본 설정
  environment = local.environment
  name_prefix = "${local.owner}-${local.project_name}-${local.environment}"

  # 네트워크
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # Security Groups
  rds_security_group_id         = module.security_groups.rds_security_group_id
  elasticache_security_group_id = module.security_groups.elasticache_security_group_id

  # RDS 설정
  rds_instance_class      = local.rds_config.instance_class
  rds_allocated_storage   = local.rds_config.allocated_storage
  rds_storage_type        = local.rds_config.storage_type
  rds_engine_version      = local.rds_config.engine_version
  db_name                 = var.db_name
  db_username             = var.db_username
  db_password             = var.db_password
  rds_multi_az            = var.db_multi_az
  rds_deletion_protection = var.environment == "prod" ? true : false
  rds_skip_final_snapshot = var.environment == "prod" ? false : true

  # ElastiCache 설정
  redis_node_type       = local.elasticache_config.node_type
  redis_num_cache_nodes = var.redis_num_cache_nodes
  redis_engine_version  = "7.0"

  # 모니터링
  # enable_cloudwatch_alarms = true
  # sns_topic_arn            = "" # SNS Topic 생성 후 추가

  # 태그
  tags = local.common_tags

  # 의존성
  depends_on = [
    module.vpc,
    module.security_groups
  ]
}
