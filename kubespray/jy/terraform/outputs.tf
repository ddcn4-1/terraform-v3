# outputs.tf
# 목적: Terraform 실행 후 필요한 정보 출력
# Best Practice: 다른 시스템 또는 팀원과 정보 공유

# ==========================================
# VPC 정보
# ==========================================

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR 블록"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "Public Subnet ID 목록"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private Subnet ID 목록"
  value       = module.vpc.private_subnet_ids
}

# ==========================================
# EC2 인스턴스 정보
# ==========================================

# output "bastion_host_public_ip" {
#   description = "Bastion Host 퍼블릭 IP (SSH 접근용)"
#   value       = module.ec2.bastion_public_ip
# }

# output "k8s_control_plane_private_ip" {
#   description = "Kubernetes Control Plane Private IP"
#   value       = module.ec2.control_plane_private_ip
# }

# output "k8s_worker_nodes_private_ips" {
#   description = "Kubernetes Worker Nodes Private IPs"
#   value       = module.ec2.worker_nodes_private_ips
# }

# output "nat_instance_public_ip" {
#   description = "NAT Instance 퍼블릭 IP"
#   value       = module.ec2.nat_instance_public_ip
# }

# # ==========================================
# # RDS 정보
# # ==========================================

# output "rds_endpoint" {
#   description = "RDS 엔드포인트 (애플리케이션 연결용)"
#   value       = module.rds.db_instance_endpoint
#   sensitive   = false  # 엔드포인트는 공개 가능
# }

# output "rds_port" {
#   description = "RDS 포트"
#   value       = module.rds.db_instance_port
# }

# # ==========================================
# # ElastiCache 정보
# # ==========================================

# output "redis_endpoint" {
#   description = "Redis 엔드포인트"
#   value       = module.elasticache.redis_endpoint
# }

# output "redis_port" {
#   description = "Redis 포트"
#   value       = module.elasticache.redis_port
# }

# # ==========================================
# # S3 및 CloudFront 정보
# # ==========================================

# output "s3_bucket_names" {
#   description = "Frontend S3 버킷 이름들"
#   value = {
#     main     = module.s3.main_bucket_name
#     accounts = module.s3.accounts_bucket_name
#     admin    = module.s3.admin_bucket_name
#   }
# }

# output "cloudfront_distribution_id" {
#   description = "CloudFront Distribution ID (캐시 무효화용)"
#   value       = module.cloudfront.distribution_id
# }

# output "cloudfront_domain_name" {
#   description = "CloudFront 도메인 이름"
#   value       = module.cloudfront.distribution_domain_name
# }

# # ==========================================
# # Route 53 정보
# # ==========================================

# output "route53_zone_id" {
#   description = "Route 53 Hosted Zone ID"
#   value       = module.route53.zone_id
# }

# output "route53_name_servers" {
#   description = "Route 53 Name Servers (도메인 등록기관에 설정)"
#   value       = module.route53.name_servers
# }

# # ==========================================
# # IAM Role ARN (GitHub Actions OIDC용)
# # ==========================================

# output "github_actions_role_arn" {
#   description = "GitHub Actions OIDC Role ARN"
#   value       = module.iam.github_actions_role_arn
# }

# # ==========================================
# # Secrets Manager 정보
# # ==========================================

# output "secrets_manager_arns" {
#   description = "Secrets Manager Secret ARN들"
#   value = {
#     db_credentials = module.secrets_manager.db_credentials_arn
#     ssh_keys       = module.secrets_manager.ssh_keys_arn
#   }
#   sensitive = true  # ARN은 민감 정보로 처리
# }