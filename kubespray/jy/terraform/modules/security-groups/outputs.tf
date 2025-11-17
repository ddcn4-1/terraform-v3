# modules/security-groups/outputs.tf
# Security Groups 모듈 출력값

# ==========================================
# Security Group IDs
# ==========================================

output "alb_security_group_id" {
  description = "ALB Security Group ID"
  value       = aws_security_group.alb.id
}

output "bastion_security_group_id" {
  description = "Bastion Host Security Group ID"
  value       = aws_security_group.bastion.id
}

output "nat_instance_security_group_id" {
  description = "NAT Instance Security Group ID"
  value       = aws_security_group.nat_instance.id
}

output "control_plane_security_group_id" {
  description = "Control Plane Security Group ID"
  value       = aws_security_group.control_plane.id
}

output "worker_node_security_group_id" {
  description = "Worker Node Security Group ID"
  value       = aws_security_group.worker_node.id
}

output "rds_security_group_id" {
  description = "RDS Security Group ID"
  value       = aws_security_group.rds.id
}

output "elasticache_security_group_id" {
  description = "ElastiCache Security Group ID"
  value       = aws_security_group.elasticache.id
}

# ==========================================
# Security Group Map (모든 SG ID를 맵으로)
# ==========================================

output "security_group_ids" {
  description = "모든 Security Group ID 맵"
  value = {
    alb           = aws_security_group.alb.id
    bastion       = aws_security_group.bastion.id
    nat_instance  = aws_security_group.nat_instance.id
    control_plane = aws_security_group.control_plane.id
    worker_node   = aws_security_group.worker_node.id
    rds           = aws_security_group.rds.id
    elasticache   = aws_security_group.elasticache.id
  }
}
