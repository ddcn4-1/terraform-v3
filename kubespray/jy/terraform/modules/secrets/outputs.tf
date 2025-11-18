# modules/secrets/outputs.tf
# Secrets Manager 모듈 출력값

# ==========================================
# Secret ARNs
# ==========================================

output "database_secret_arn" {
  description = "Database Secret ARN"
  value       = aws_secretsmanager_secret.database.arn
}

output "redis_secret_arn" {
  description = "Redis Secret ARN"
  value       = aws_secretsmanager_secret.redis.arn
}

output "api_keys_secret_arn" {
  description = "API Keys Secret ARN"
  value       = length(var.api_keys) > 0 ? aws_secretsmanager_secret.api_keys[0].arn : ""
}

# ==========================================
# Secret Names
# ==========================================

output "database_secret_name" {
  description = "Database Secret 이름"
  value       = aws_secretsmanager_secret.database.name
}

output "redis_secret_name" {
  description = "Redis Secret 이름"
  value       = aws_secretsmanager_secret.redis.name
}

output "api_keys_secret_name" {
  description = "API Key Secret 이름"
  value       = aws_secretsmanager_secret.redis.name
}
