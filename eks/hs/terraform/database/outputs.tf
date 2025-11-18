# RDS Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_address" {
  description = "RDS instance address"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.postgres.port
}

output "rds_database_name" {
  description = "Name of the database"
  value       = aws_db_instance.postgres.db_name
}

output "rds_username" {
  description = "Master username for RDS"
  value       = aws_db_instance.postgres.username
  sensitive   = true
}

output "rds_password_secret_arn" {
  description = "ARN of the RDS password secret in Secrets Manager"
  value       = aws_secretsmanager_secret.rds_password.arn
}

# ElastiCache Outputs
output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "redis_port" {
  description = "ElastiCache Redis port"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].port
}

output "redis_configuration_endpoint" {
  description = "Configuration endpoint for ElastiCache cluster"
  value       = aws_elasticache_cluster.redis.configuration_endpoint
}

output "redis_auth_token_secret_arn" {
  description = "ARN of the Redis auth token secret in Secrets Manager"
  value       = aws_secretsmanager_secret.redis_auth_token.arn
}

# Kubernetes Secret Names
output "db_secret_name" {
  description = "Name of Kubernetes secret containing database credentials"
  value       = kubernetes_secret.database_credentials.metadata[0].name
}

output "redis_secret_name" {
  description = "Name of Kubernetes secret containing Redis credentials"
  value       = kubernetes_secret.redis_credentials.metadata[0].name
}

output "app_secret_name" {
  description = "Name of Kubernetes secret containing application config"
  value       = kubernetes_secret.application_config.metadata[0].name
}

# Connection Information
output "database_connection_string" {
  description = "PostgreSQL connection string (without password)"
  value       = "postgresql://${aws_db_instance.postgres.username}@${aws_db_instance.postgres.endpoint}/${aws_db_instance.postgres.db_name}"
  sensitive   = true
}

output "redis_connection_string" {
  description = "Redis connection string"
  value       = "redis://${aws_elasticache_cluster.redis.cache_nodes[0].address}:${aws_elasticache_cluster.redis.cache_nodes[0].port}"
}

# Summary
output "deployment_summary" {
  description = "Summary of deployed database resources"
  value = <<-EOT

    ========================================
    Database Resources Deployed
    ========================================

    RDS PostgreSQL:
      Endpoint: ${aws_db_instance.postgres.endpoint}
      Database: ${aws_db_instance.postgres.db_name}
      Secret: ${kubernetes_secret.database_credentials.metadata[0].name}

    ElastiCache Redis:
      Endpoint: ${aws_elasticache_cluster.redis.cache_nodes[0].address}:${aws_elasticache_cluster.redis.cache_nodes[0].port}
      Secret: ${kubernetes_secret.redis_credentials.metadata[0].name}

    Kubernetes Secrets:
      kubectl get secret ${kubernetes_secret.database_credentials.metadata[0].name}
      kubectl get secret ${kubernetes_secret.redis_credentials.metadata[0].name}
      kubectl get secret ${kubernetes_secret.application_config.metadata[0].name}

    ========================================
  EOT
}
