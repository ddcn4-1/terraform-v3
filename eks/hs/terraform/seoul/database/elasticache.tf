# ElastiCache Redis Configuration
# Creates a Redis cluster in private subnets

# ElastiCache Subnet Group (uses core-infra database subnets)
resource "aws_elasticache_subnet_group" "redis" {
  name        = "${var.project_name}-redis-subnet-group"
  description = "Subnet group for ElastiCache Redis"
  subnet_ids  = local.database_subnets

  tags = {
    Name        = "${var.project_name}-redis-subnet-group"
    Environment = var.environment
  }
}

# ElastiCache Parameter Group
resource "aws_elasticache_parameter_group" "redis" {
  name        = "${var.project_name}-redis-params"
  family      = var.redis_parameter_group_family
  description = "Custom parameter group for Redis ${var.redis_engine_version}"

  # Redis configuration parameters
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru" # Evict least recently used keys when memory limit is reached
  }

  parameter {
    name  = "timeout"
    value = "300" # Close idle connections after 5 minutes
  }

  parameter {
    name  = "tcp-keepalive"
    value = "300"
  }

  tags = {
    Name        = "${var.project_name}-redis-params"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Generate random auth token for Redis
resource "random_password" "redis_auth_token" {
  length  = 32
  special = false # Auth token cannot contain special characters
  upper   = true
  lower   = true
  numeric = true
}

# Store Redis auth token in AWS Secrets Manager
resource "aws_secretsmanager_secret" "redis_auth_token" {
  name_prefix             = "${var.project_name}-redis-token-"
  description             = "ElastiCache Redis auth token"
  recovery_window_in_days = 7

  tags = {
    Name        = "${var.project_name}-redis-token"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "redis_auth_token" {
  secret_id     = aws_secretsmanager_secret.redis_auth_token.id
  secret_string = random_password.redis_auth_token.result
}

# ElastiCache Redis Cluster
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project_name}-redis"
  engine               = "redis"
  engine_version       = var.redis_engine_version
  node_type            = var.redis_node_type
  num_cache_nodes      = var.redis_num_cache_nodes
  parameter_group_name = aws_elasticache_parameter_group.redis.name
  port                 = var.redis_port

  # Network configuration
  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [local.redis_security_group_id]

  # Security configuration
  transit_encryption_enabled = false
  # at_rest_encryption_enabled = true
  # auth_token_enabled         = true
  # auth_token                 = random_password.redis_auth_token.result

  # Maintenance configuration
  maintenance_window       = "sun:05:00-sun:06:00"
  snapshot_window          = "03:00-04:00"
  snapshot_retention_limit = 5 # Keep 5 daily snapshots

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  # Notification configuration (optional)
  # notification_topic_arn = aws_sns_topic.elasticache_events.arn

  # Logging (requires CloudWatch Logs)
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_engine_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  tags = {
    Name        = "${var.project_name}-redis"
    Environment = var.environment
  }

  # lifecycle {
  #   ignore_changes = [
  #     auth_token, # Auth token managed by Secrets Manager
  #   ]
  # }
}

# CloudWatch Log Groups for Redis
resource "aws_cloudwatch_log_group" "redis_slow_log" {
  name_prefix       = "/aws/elasticache/${var.project_name}/redis/slow-log-"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-redis-slow-log"
    Environment = var.environment
  }

  # Add lifecycle to handle transient errors
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "redis_engine_log" {
  name_prefix       = "/aws/elasticache/${var.project_name}/redis/engine-log-"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-redis-engine-log"
    Environment = var.environment
  }

  # Add lifecycle to handle transient errors
  lifecycle {
    create_before_destroy = true
  }
}

# CloudWatch Alarms for Redis monitoring
resource "aws_cloudwatch_metric_alarm" "redis_cpu" {
  alarm_name          = "${var.project_name}-redis-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "75"
  alarm_description   = "This metric monitors Redis CPU utilization"

  dimensions = {
    CacheClusterId = aws_elasticache_cluster.redis.id
  }

  tags = {
    Name        = "${var.project_name}-redis-cpu-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "redis_memory" {
  alarm_name          = "${var.project_name}-redis-database-memory-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors Redis memory usage"

  dimensions = {
    CacheClusterId = aws_elasticache_cluster.redis.id
  }

  tags = {
    Name        = "${var.project_name}-redis-memory-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "redis_connections" {
  alarm_name          = "${var.project_name}-redis-current-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CurrConnections"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "100"
  alarm_description   = "This metric monitors Redis current connections"

  dimensions = {
    CacheClusterId = aws_elasticache_cluster.redis.id
  }

  tags = {
    Name        = "${var.project_name}-redis-connections-alarm"
    Environment = var.environment
  }
}

# SNS Topic for ElastiCache events (optional)
# Uncomment if you want to receive notifications
# resource "aws_sns_topic" "elasticache_events" {
#   name_prefix = "${var.project_name}-elasticache-events-"
#
#   tags = {
#     Name        = "${var.project_name}-elasticache-events"
#     Environment = var.environment
#   }
# }
#
# resource "aws_sns_topic_subscription" "elasticache_events_email" {
#   topic_arn = aws_sns_topic.elasticache_events.arn
#   protocol  = "email"
#   endpoint  = "your-email@example.com"
# }
