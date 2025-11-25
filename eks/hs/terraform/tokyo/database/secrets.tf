# Kubernetes Secrets for Database and Redis Credentials
# These secrets are created after the RDS and ElastiCache resources are ready

# Database Credentials Secret
resource "kubernetes_secret" "database_credentials" {
  metadata {
    name      = "${var.project_name}-database-credentials"
    namespace = "ddcn41"

    labels = {
      app         = "backend-v3"
      environment = var.environment
      managed-by  = "terraform"
    }
  }

  data = {
    # PostgreSQL connection details (standardized naming)
    DATABASE_HOST     = aws_db_instance.postgres.address
    DATABASE_PORT     = tostring(aws_db_instance.postgres.port)
    DATABASE_NAME     = aws_db_instance.postgres.db_name
    DATABASE_USERNAME = aws_db_instance.postgres.username
    DATABASE_PASSWORD = var.rds_password

    # Legacy naming for backward compatibility (can be removed after migration)
    DB_HOST     = aws_db_instance.postgres.address
    DB_PORT     = tostring(aws_db_instance.postgres.port)
    DB_NAME     = aws_db_instance.postgres.db_name
    DB_USERNAME = aws_db_instance.postgres.username
    DB_PASSWORD = var.rds_password

    # Connection string (without password for logging)
    DB_CONNECTION_STRING = "postgresql://${aws_db_instance.postgres.username}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${aws_db_instance.postgres.db_name}"

    # Full connection string with password
    DATABASE_URL = "jdbc:postgresql://${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${aws_db_instance.postgres.db_name}?sslmode=require"
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
    namespace = "ddcn41"

    labels = {
      app         = "backend-v3"
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
    namespace = "ddcn41"

    labels = {
      app         = "backend-v3"
      environment = var.environment
      managed-by  = "terraform"
    }
  }

  data = {
    # Database configuration (standardized naming)
    DATABASE_HOST     = aws_db_instance.postgres.address
    DATABASE_PORT     = tostring(aws_db_instance.postgres.port)
    DATABASE_NAME     = aws_db_instance.postgres.db_name
    DATABASE_USERNAME = aws_db_instance.postgres.username
    DATABASE_PASSWORD = var.rds_password
    DATABASE_URL      = "jdbc:postgresql://${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${aws_db_instance.postgres.db_name}?sslmode=require"

    # Legacy naming for backward compatibility
    DB_HOST      = aws_db_instance.postgres.address
    DB_PORT      = tostring(aws_db_instance.postgres.port)
    DB_NAME      = aws_db_instance.postgres.db_name
    DB_USERNAME  = aws_db_instance.postgres.username
    DB_PASSWORD  = var.rds_password

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

# Random password for JWT Secret
resource "random_password" "jwt_secret" {
  length  = 64
  special = true
}

# JWT and Cognito Secrets
resource "kubernetes_secret" "jwt_cognito_secrets" {
  metadata {
    name      = "${var.project_name}-jwt-cognito-secrets"
    namespace = "ddcn41"

    labels = {
      app         = "backend-v3"
      environment = var.environment
      managed-by  = "terraform"
    }
  }

  data = {
    # JWT Configuration
    JWT_SECRET = random_password.jwt_secret.result

    # Cognito Configuration
    # TODO: Update these values with your actual Cognito User Pool ID and Client ID
    # These should be moved to variables or AWS Secrets Manager
    COGNITO_USER_POOL_ID = var.cognito_user_pool_id
    COGNITO_CLIENT_ID    = var.cognito_client_id
  }

  type = "Opaque"
}
