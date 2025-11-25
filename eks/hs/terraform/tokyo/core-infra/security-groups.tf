# Security Groups for EKS, RDS, ElastiCache, and ALB

# Additional Security Group for EKS Worker Nodes
# This allows for custom ingress/egress rules beyond the default EKS-managed security group
resource "aws_security_group" "eks_worker_additional" {
  name_prefix = "${var.project_name}-eks-worker-additional-"
  description = "Additional security group for EKS worker nodes"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name        = "${var.project_name}-eks-worker-additional"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Allow worker nodes to communicate with each other
resource "aws_security_group_rule" "eks_worker_ingress_self" {
  description              = "Allow worker nodes to communicate with each other"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_worker_additional.id
  source_security_group_id = aws_security_group.eks_worker_additional.id
}

# Allow all outbound traffic from worker nodes
resource "aws_security_group_rule" "eks_worker_egress_all" {
  description       = "Allow all outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_worker_additional.id
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name        = "${var.project_name}-rds"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Allow PostgreSQL access from EKS worker nodes
resource "aws_security_group_rule" "rds_ingress_eks" {
  description              = "Allow PostgreSQL access from EKS worker nodes"
  type                     = "ingress"
  from_port                = var.rds_port
  to_port                  = var.rds_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.eks_worker_additional.id
}

# Allow PostgreSQL access from within the database subnet (for maintenance)
resource "aws_security_group_rule" "rds_ingress_database_subnet" {
  description       = "Allow PostgreSQL access from database subnet"
  type              = "ingress"
  from_port         = var.rds_port
  to_port           = var.rds_port
  protocol          = "tcp"
  cidr_blocks       = var.database_subnet_cidrs
  security_group_id = aws_security_group.rds.id
}

# ElastiCache Security Group
resource "aws_security_group" "redis" {
  name_prefix = "${var.project_name}-redis-"
  description = "Security group for ElastiCache Redis"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name        = "${var.project_name}-redis"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Allow Redis access from EKS worker nodes
resource "aws_security_group_rule" "redis_ingress_eks" {
  description              = "Allow Redis access from EKS worker nodes"
  type                     = "ingress"
  from_port                = var.redis_port
  to_port                  = var.redis_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = aws_security_group.eks_worker_additional.id
}

# Allow Redis access from within the database subnet (for maintenance)
resource "aws_security_group_rule" "redis_ingress_database_subnet" {
  description       = "Allow Redis access from database subnet"
  type              = "ingress"
  from_port         = var.redis_port
  to_port           = var.redis_port
  protocol          = "tcp"
  cidr_blocks       = var.database_subnet_cidrs
  security_group_id = aws_security_group.redis.id
}

# Application Load Balancer Security Group
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Allow HTTP from anywhere
resource "aws_security_group_rule" "alb_ingress_http" {
  description       = "Allow HTTP from anywhere"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

# Allow HTTPS from anywhere
resource "aws_security_group_rule" "alb_ingress_https" {
  description       = "Allow HTTPS from anywhere"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

# Allow all outbound traffic from ALB
resource "aws_security_group_rule" "alb_egress_all" {
  description       = "Allow all outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

# Allow traffic from ALB to EKS worker nodes on application ports
resource "aws_security_group_rule" "eks_worker_ingress_alb_core" {
  description              = "Allow traffic from ALB to core-service"
  type                     = "ingress"
  from_port                = var.core_service_port
  to_port                  = var.core_service_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_worker_additional.id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "eks_worker_ingress_alb_queue" {
  description              = "Allow traffic from ALB to queue-service"
  type                     = "ingress"
  from_port                = var.queue_service_port
  to_port                  = var.queue_service_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_worker_additional.id
  source_security_group_id = aws_security_group.alb.id
}

# Allow NodePort range from ALB (for Kubernetes services)
resource "aws_security_group_rule" "eks_worker_ingress_alb_nodeport" {
  description              = "Allow NodePort range from ALB"
  type                     = "ingress"
  from_port                = 30000
  to_port                  = 32767
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_worker_additional.id
  source_security_group_id = aws_security_group.alb.id
}
