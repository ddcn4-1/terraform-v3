# # modules/database/monitoring.tf
# # CloudWatch Alarms

# # ==========================================
# # RDS CloudWatch Alarms
# # ==========================================

# # CPU 사용률 알람
# resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
#   count = var.enable_cloudwatch_alarms ? 1 : 0

#   alarm_name          = "${local.rds_identifier}-high-cpu"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "CPUUtilization"
#   namespace           = "AWS/RDS"
#   period              = 300 # 5분
#   statistic           = "Average"
#   threshold           = var.rds_cpu_threshold
#   alarm_description   = "RDS CPU > ${var.rds_cpu_threshold}%"

#   dimensions = {
#     DBInstanceIdentifier = aws_db_instance.main.identifier
#   }

#   alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
#   ok_actions    = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

#   tags = local.common_tags
# }

# # 사용 가능한 메모리 알람
# resource "aws_cloudwatch_metric_alarm" "rds_memory" {
#   count = var.enable_cloudwatch_alarms ? 1 : 0

#   alarm_name          = "${local.rds_identifier}-low-memory"
#   comparison_operator = "LessThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "FreeableMemory"
#   namespace           = "AWS/RDS"
#   period              = 300
#   statistic           = "Average"
#   threshold           = var.rds_memory_threshold * 1024 * 1024 # MB to Bytes
#   alarm_description   = "RDS Freeable Memory < ${var.rds_memory_threshold}MB"

#   dimensions = {
#     DBInstanceIdentifier = aws_db_instance.main.identifier
#   }

#   alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
#   ok_actions    = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

#   tags = local.common_tags
# }

# # 디스크 큐 깊이 알람
# resource "aws_cloudwatch_metric_alarm" "rds_disk_queue" {
#   count = var.enable_cloudwatch_alarms ? 1 : 0

#   alarm_name          = "${local.rds_identifier}-high-disk-queue"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "DiskQueueDepth"
#   namespace           = "AWS/RDS"
#   period              = 300
#   statistic           = "Average"
#   threshold           = var.rds_disk_queue_depth_threshold
#   alarm_description   = "RDS Disk Queue Depth > ${var.rds_disk_queue_depth_threshold}"

#   dimensions = {
#     DBInstanceIdentifier = aws_db_instance.main.identifier
#   }

#   alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
#   ok_actions    = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

#   tags = local.common_tags
# }

# # 스토리지 공간 알람
# resource "aws_cloudwatch_metric_alarm" "rds_storage" {
#   count = var.enable_cloudwatch_alarms ? 1 : 0

#   alarm_name          = "${local.rds_identifier}-low-storage"
#   comparison_operator = "LessThanThreshold"
#   evaluation_periods  = 1
#   metric_name         = "FreeStorageSpace"
#   namespace           = "AWS/RDS"
#   period              = 300
#   statistic           = "Average"
#   threshold           = 2 * 1024 * 1024 * 1024 # 2GB
#   alarm_description   = "RDS Free Storage < 2GB"

#   dimensions = {
#     DBInstanceIdentifier = aws_db_instance.main.identifier
#   }

#   alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
#   ok_actions    = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

#   tags = local.common_tags
# }

# # 연결 수 알람
# resource "aws_cloudwatch_metric_alarm" "rds_connections" {
#   count = var.enable_cloudwatch_alarms ? 1 : 0

#   alarm_name          = "${local.rds_identifier}-high-connections"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "DatabaseConnections"
#   namespace           = "AWS/RDS"
#   period              = 300
#   statistic           = "Average"
#   threshold           = 80 # max_connections의 80%
#   alarm_description   = "RDS Database Connections > 80"

#   dimensions = {
#     DBInstanceIdentifier = aws_db_instance.main.identifier
#   }

#   alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
#   ok_actions    = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

#   tags = local.common_tags
# }

# # ==========================================
# # ElastiCache CloudWatch Alarms
# # ==========================================

# # CPU 사용률 알람
# resource "aws_cloudwatch_metric_alarm" "redis_cpu" {
#   count = var.enable_cloudwatch_alarms ? 1 : 0

#   alarm_name          = "${local.redis_cluster_id}-high-cpu"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "CPUUtilization"
#   namespace           = "AWS/ElastiCache"
#   period              = 300
#   statistic           = "Average"
#   threshold           = 75
#   alarm_description   = "Redis CPU > 75%"

#   dimensions = {
#     CacheClusterId = local.redis_cluster_id
#   }

#   alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
#   ok_actions    = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

#   tags = local.common_tags
# }

# # 메모리 사용률 알람
# resource "aws_cloudwatch_metric_alarm" "redis_memory" {
#   count = var.enable_cloudwatch_alarms ? 1 : 0

#   alarm_name          = "${local.redis_cluster_id}-high-memory"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "DatabaseMemoryUsagePercentage"
#   namespace           = "AWS/ElastiCache"
#   period              = 300
#   statistic           = "Average"
#   threshold           = 80
#   alarm_description   = "Redis Memory Usage > 80%"

#   dimensions = {
#     CacheClusterId = local.redis_cluster_id
#   }

#   alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
#   ok_actions    = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

#   tags = local.common_tags
# }

# # Eviction 알람 (메모리 부족으로 키 제거)
# resource "aws_cloudwatch_metric_alarm" "redis_evictions" {
#   count = var.enable_cloudwatch_alarms ? 1 : 0

#   alarm_name          = "${local.redis_cluster_id}-evictions"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 1
#   metric_name         = "Evictions"
#   namespace           = "AWS/ElastiCache"
#   period              = 300
#   statistic           = "Sum"
#   threshold           = 1000 # 5분간 1000개 이상 제거
#   alarm_description   = "Redis Evictions > 1000 (5min)"

#   dimensions = {
#     CacheClusterId = local.redis_cluster_id
#   }

#   alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
#   ok_actions    = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

#   tags = local.common_tags
# }

# # Swap 사용량 알람
# resource "aws_cloudwatch_metric_alarm" "redis_swap" {
#   count = var.enable_cloudwatch_alarms ? 1 : 0

#   alarm_name          = "${local.redis_cluster_id}-swap-usage"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "SwapUsage"
#   namespace           = "AWS/ElastiCache"
#   period              = 300
#   statistic           = "Average"
#   threshold           = 50 * 1024 * 1024 # 50MB
#   alarm_description   = "Redis Swap Usage > 50MB"

#   dimensions = {
#     CacheClusterId = local.redis_cluster_id
#   }

#   alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
#   ok_actions    = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

#   tags = local.common_tags
# }
