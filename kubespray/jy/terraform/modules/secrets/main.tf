# modules/secrets/main.tf
# AWS Secrets Manager 리소스

# ==========================================
# Database Credentials Secret
# ==========================================

resource "aws_secretsmanager_secret" "database" {
  name                    = "${var.name_prefix}/database/credentials"
  description             = "Database credentials for ${var.name_prefix}"
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-database-credentials"
      Type = "database"
    }
  )
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id

  secret_string = jsonencode({
    username = var.db_master_username
    password = var.db_master_password
    host     = var.db_host
    port     = var.db_port
    dbname   = var.db_name
    url      = local.database_url
  })
}

# ==========================================
# Redis Credentials Secret
# ==========================================

resource "aws_secretsmanager_secret" "redis" {
  name                    = "${var.name_prefix}/redis/credentials"
  description             = "Redis credentials for ${var.name_prefix}"
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-redis-credentials"
      Type = "redis"
    }
  )
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id = aws_secretsmanager_secret.redis.id

  secret_string = jsonencode({
    host = var.redis_host
    port = var.redis_port
    url  = local.redis_url
  })
}

# ==========================================
# API Keys Secret
# ==========================================

resource "aws_secretsmanager_secret" "api_keys" {
  count = length(var.api_keys) > 0 ? 1 : 0

  name                    = "${var.name_prefix}/application/api-keys"
  description             = "External API keys for ${var.name_prefix}"
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-api-keys"
      Type = "application"
    }
  )
}

resource "aws_secretsmanager_secret_version" "api_keys" {
  count = length(var.api_keys) > 0 ? 1 : 0

  secret_id     = aws_secretsmanager_secret.api_keys[0].id
  secret_string = jsonencode(var.api_keys)
}
