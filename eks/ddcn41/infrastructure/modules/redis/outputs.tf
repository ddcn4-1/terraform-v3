output "redis_endpoint" {
  description = "Redis endpoint"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_replication_group.main.port
}

output "redis_cluster_id" {
  description = "Redis cluster ID"
  value       = aws_elasticache_replication_group.main.replication_group_id
}

output "endpoint" {
  description = "Redis endpoint (alias for redis_endpoint)"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}
