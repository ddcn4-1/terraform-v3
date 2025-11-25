# VPC 출력값들
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  description = "Database subnet IDs"
  value       = module.vpc.database_subnet_ids
}

output "alb_security_group_id" {
  description = "ALB Security Group ID"
  value       = module.vpc.alb_security_group_id
}

output "eks_nodes_security_group_id" {
  description = "EKS Nodes Security Group ID"
  value       = module.vpc.eks_nodes_security_group_id
}

output "rds_security_group_id" {
  description = "RDS Security Group ID"
  value       = module.vpc.rds_security_group_id
}

output "redis_security_group_id" {
  description = "Redis Security Group ID"
  value       = module.vpc.redis_security_group_id
}

# ALB 출력값
output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "ALB ARN"
  value       = module.alb.alb_arn
}

output "api_target_group_arn" {
  description = "API target group ARN"
  value       = module.alb.api_target_group_arn
}

output "queue_target_group_arn" {
  description = "Queue target group ARN"
  value       = module.alb.queue_target_group_arn
}
# EKS 출력값
output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

# RDS 출력값
output "db_endpoint" {
  description = "Database endpoint"
  value       = module.rds.db_instance_endpoint
}

# Redis 출력값  
output "redis_endpoint" {
  description = "Redis endpoint"
  value       = module.redis.redis_endpoint
}

# Admin 출력값
output "admin_target_group_arn" {
  description = "Admin target group ARN"
  value       = module.alb.admin_target_group_arn
}
