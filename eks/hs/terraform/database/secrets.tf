# Kubernetes Secrets for Database and Redis Credentials
# These secrets are created after the RDS and ElastiCache resources are ready

# Database Credentials Secret
resource "kubernetes_secret" "database_credentials" {
  metadata {
    name      = "${var.project_name}-database-credentials"
    namespace = "default"

    labels = {
      app         = "mini-msa"
      environment = var.environment
      managed-by  = "terraform"
    }
  }

  data = {
    # PostgreSQL connection details
    DB_HOST     = aws_db_instance.postgres.address
    DB_PORT     = tostring(aws_db_instance.postgres.port)
    DB_NAME     = aws_db_instance.postgres.db_name
    DB_USERNAME = aws_db_instance.postgres.username
    DB_PASSWORD = random_password.rds_master_password.result

    # Connection string (without password for logging)
    DB_CONNECTION_STRING = "postgresql://${aws_db_instance.postgres.username}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${aws_db_instance.postgres.db_name}"

    # Full connection string with password
    DATABASE_URL = "postgresql://${aws_db_instance.postgres.username}:${random_password.rds_master_password.result}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${aws_db_instance.postgres.db_name}?sslmode=require"
  }

  type = "Opaque"

  depends_on = [
    aws_db_instance.postgres
  ]
}

# Redis Credentials Secret
resource "kubernetes_secret" "redis_credentials" {
  metadata {
    name      = "${var.project_name}-redis-credentials"
    namespace = "default"

    labels = {
      app         = "mini-msa"
      environment = var.environment
      managed-by  = "terraform"
    }
  }

  data = {
    # Redis connection details
    REDIS_HOST     = aws_elasticache_cluster.redis.cache_nodes[0].address
    REDIS_PORT     = tostring(aws_elasticache_cluster.redis.cache_nodes[0].port)
    REDIS_PASSWORD = random_password.redis_auth_token.result
    REDIS_USE_TLS  = "true"

    # Connection string (without password for logging)
    REDIS_CONNECTION_STRING = "redis://${aws_elasticache_cluster.redis.cache_nodes[0].address}:${aws_elasticache_cluster.redis.cache_nodes[0].port}"

    # Full connection string with password and TLS
    REDIS_URL = "rediss://:${random_password.redis_auth_token.result}@${aws_elasticache_cluster.redis.cache_nodes[0].address}:${aws_elasticache_cluster.redis.cache_nodes[0].port}"
  }

  type = "Opaque"

  depends_on = [
    aws_elasticache_cluster.redis
  ]
}

# Application Configuration Secret (combines both DB and Redis)
resource "kubernetes_secret" "application_config" {
  metadata {
    name      = "${var.project_name}-application-config"
    namespace = "default"

    labels = {
      app         = "mini-msa"
      environment = var.environment
      managed-by  = "terraform"
    }
  }

  data = {
    # Database configuration
    DB_HOST      = aws_db_instance.postgres.address
    DB_PORT      = tostring(aws_db_instance.postgres.port)
    DB_NAME      = aws_db_instance.postgres.db_name
    DB_USERNAME  = aws_db_instance.postgres.username
    DB_PASSWORD  = random_password.rds_master_password.result
    DATABASE_URL = "postgresql://${aws_db_instance.postgres.username}:${random_password.rds_master_password.result}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${aws_db_instance.postgres.db_name}?sslmode=require"

    # Redis configuration
    REDIS_HOST     = aws_elasticache_cluster.redis.cache_nodes[0].address
    REDIS_PORT     = tostring(aws_elasticache_cluster.redis.cache_nodes[0].port)
    REDIS_PASSWORD = random_password.redis_auth_token.result
    REDIS_USE_TLS  = "true"
    REDIS_URL      = "rediss://:${random_password.redis_auth_token.result}@${aws_elasticache_cluster.redis.cache_nodes[0].address}:${aws_elasticache_cluster.redis.cache_nodes[0].port}"

    # Application configuration
    NODE_ENV = var.environment
  }

  type = "Opaque"

  depends_on = [
    aws_db_instance.postgres,
    aws_elasticache_cluster.redis
  ]
}
