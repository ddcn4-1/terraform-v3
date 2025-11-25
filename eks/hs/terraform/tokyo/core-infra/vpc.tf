# VPC Module
# Creates VPC with public, private, and database subnets across multiple AZs
# Reference: https://github.com/terraform-aws-modules/terraform-aws-vpc

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  # Use first 2 available AZs in the region
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # Subnet configuration
  public_subnets   = var.public_subnet_cidrs
  private_subnets  = var.private_subnet_cidrs
  database_subnets = var.database_subnet_cidrs

  # NAT Gateway configuration
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  # DNS configuration
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Database subnet group
  create_database_subnet_group           = true
  create_database_subnet_route_table     = true
  create_database_internet_gateway_route = false

  # VPC Flow Logs (optional, can be enabled for production)
  # enable_flow_log                      = true
  # create_flow_log_cloudwatch_iam_role  = true
  # create_flow_log_cloudwatch_log_group = true

  # Tags for EKS (required for AWS Load Balancer Controller)
  public_subnet_tags = {
    "kubernetes.io/role/elb"                           = "1"
    "kubernetes.io/cluster/${var.project_name}-cluster" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                  = "1"
    "kubernetes.io/cluster/${var.project_name}-cluster" = "shared"
  }

  database_subnet_tags = {
    Name = "${var.project_name}-database"
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-vpc"
      Environment = var.environment
    }
  )
}

# VPC Endpoint for S3 (cost optimization for pulling container images from ECR)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = module.vpc.vpc_id
  service_name = "com.amazonaws.${var.aws_region}.s3"

  route_table_ids = concat(
    module.vpc.private_route_table_ids,
    module.vpc.public_route_table_ids
  )

  tags = {
    Name        = "${var.project_name}-s3-endpoint"
    Environment = var.environment
  }
}

# VPC Endpoint for ECR API (recommended for EKS)
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = module.vpc.private_subnets

  security_group_ids = [
    aws_security_group.vpc_endpoints.id
  ]

  tags = {
    Name        = "${var.project_name}-ecr-api-endpoint"
    Environment = var.environment
  }
}

# VPC Endpoint for ECR Docker registry (recommended for EKS)
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = module.vpc.private_subnets

  security_group_ids = [
    aws_security_group.vpc_endpoints.id
  ]

  tags = {
    Name        = "${var.project_name}-ecr-dkr-endpoint"
    Environment = var.environment
  }
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.project_name}-vpc-endpoints-"
  description = "Security group for VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-vpc-endpoints-sg"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}
