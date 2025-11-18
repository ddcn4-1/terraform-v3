# modules/database/outputs.tf
# 데이터베이스 모듈 출력값

# ==========================================
# RDS 출력
# ==========================================

output "rds_instance_id" {
  description = "RDS Instance ID"
  value       = aws_db_instance.main.id
}

output "rds_instance_arn" {
  description = "RDS Instance ARN"
  value       = aws_db_instance.main.arn
}

output "rds_endpoint" {
  description = "RDS 엔드포인트 (호스트:포트)"
  value       = aws_db_instance.main.endpoint
}

output "rds_address" {
  description = "RDS 호스트 주소"
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "RDS 포트"
  value       = aws_db_instance.main.port
}

output "rds_database_name" {
  description = "데이터베이스 이름"
  value       = aws_db_instance.main.db_name
}

output "rds_connection_string" {
  description = "RDS 연결 문자열 (비밀번호 제외)"
  value       = "postgresql://${var.db_username}:PASSWORD@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
  sensitive   = true
}

# ==========================================
# ElastiCache 출력
# ==========================================

output "redis_cluster_id" {
  description = "Redis Cluster ID"
  value       = aws_elasticache_replication_group.main.id
}

output "redis_primary_endpoint" {
  description = "Redis Primary 엔드포인트"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Redis Reader 엔드포인트"
  value       = aws_elasticache_replication_group.main.reader_endpoint_address
}

output "redis_port" {
  description = "Redis 포트"
  value       = var.redis_port
}

output "redis_connection_string" {
  description = "Redis 연결 문자열"
  value       = "redis://${aws_elasticache_replication_group.main.primary_endpoint_address}:${var.redis_port}"
}
