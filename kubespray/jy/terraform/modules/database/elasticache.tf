# modules/database/elasticache.tf
# ElastiCache Redis 리소스

# ==========================================
# ElastiCache Subnet Group
# ==========================================

resource "aws_elasticache_subnet_group" "main" {
  name       = local.redis_subnet_group_name
  subnet_ids = var.private_subnet_ids

  tags = merge(
    local.common_tags,
    {
      Name = local.redis_subnet_group_name
    }
  )
}

# ==========================================
# ElastiCache Parameter Group
# ==========================================

resource "aws_elasticache_parameter_group" "main" {
  name   = local.redis_parameter_group_name
  family = var.redis_parameter_group_family

  description = "Custom parameter group for ${var.name_prefix}"

  # 메모리 정책
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru" # LRU 방식으로 키 제거
  }

  # 타임아웃 설정
  parameter {
    name  = "timeout"
    value = "300" # 5분
  }

  # Slowlog 설정
  parameter {
    name  = "slowlog-log-slower-than"
    value = "10000" # 10ms 이상 느린 명령어 로깅
  }

  parameter {
    name  = "slowlog-max-len"
    value = "128"
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.redis_parameter_group_name
    }
  )
}

# ==========================================
# ElastiCache Replication Group (Redis)
# ==========================================

resource "aws_elasticache_replication_group" "main" {
  # 식별자
  replication_group_id = local.redis_cluster_id
  description          = "Redis cluster for ${var.name_prefix}"

  # 엔진 설정
  engine               = "redis"
  engine_version       = var.redis_engine_version
  port                 = var.redis_port
  parameter_group_name = aws_elasticache_parameter_group.main.name

  # 노드 설정
  node_type                  = var.redis_node_type
  num_cache_clusters         = var.redis_num_cache_nodes
  automatic_failover_enabled = var.redis_automatic_failover_enabled && var.redis_num_cache_nodes > 1

  # 네트워크 설정
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [var.elasticache_security_group_id]

  # 보안
  at_rest_encryption_enabled = var.redis_at_rest_encryption_enabled
  transit_encryption_enabled = var.redis_transit_encryption_enabled
  #   auth_token_enabled         = false # 선택적 인증

  # 백업
  snapshot_retention_limit = var.redis_snapshot_retention_limit
  snapshot_window          = var.redis_snapshot_window

  # 유지보수
  maintenance_window         = var.redis_maintenance_window
  auto_minor_version_upgrade = true

  # 알림
  #   notification_topic_arn = var.sns_topic_arn != "" ? var.sns_topic_arn : null

  # 로그
  #   log_delivery_configuration {
  #     destination      = aws_cloudwatch_log_group.redis_slow_log.name
  #     destination_type = "cloudwatch-logs"
  #     log_format       = "json"
  #     log_type         = "slow-log"
  #   }

  #   log_delivery_configuration {
  #     destination      = aws_cloudwatch_log_group.redis_engine_log.name
  #     destination_type = "cloudwatch-logs"
  #     log_format       = "json"
  #     log_type         = "engine-log"
  #   }

  # 태그
  tags = merge(
    local.common_tags,
    {
      Name = local.redis_cluster_id
    }
  )

  lifecycle {
    # 노드 수 변경 시 재생성 방지
    ignore_changes = [num_cache_clusters]
  }
}

# ==========================================
# CloudWatch Log Groups for Redis
# ==========================================

# resource "aws_cloudwatch_log_group" "redis_slow_log" {
#   name              = "/aws/elasticache/${local.redis_cluster_id}/slow-log"
#   retention_in_days = 7

#   tags = local.common_tags
# }

# resource "aws_cloudwatch_log_group" "redis_engine_log" {
#   name              = "/aws/elasticache/${local.redis_cluster_id}/engine-log"
#   retention_in_days = 7

#   tags = local.common_tags
# }
