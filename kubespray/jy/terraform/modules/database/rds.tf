# modules/database/rds.tf
# RDS PostgreSQL 리소스

# ==========================================
# RDS Subnet Group
# ==========================================

resource "aws_db_subnet_group" "main" {
  name       = local.rds_subnet_group_name
  subnet_ids = var.private_subnet_ids

  tags = merge(
    local.common_tags,
    {
      Name = local.rds_subnet_group_name
    }
  )
}

# ==========================================
# RDS Parameter Group
# ==========================================

# resource "aws_db_parameter_group" "main" {
#   name   = local.rds_parameter_group_name
#   family = "postgres17" # PostgreSQL 17

#   description = "Custom parameter group for ${var.name_prefix}"

#   # 로그 설정
#   parameter {
#     name  = "log_connections"
#     value = "1"
#   }

#   parameter {
#     name  = "log_disconnections"
#     value = "1"
#   }

#   parameter {
#     name  = "log_duration"
#     value = "1"
#   }

#   parameter {
#     name  = "log_statement"
#     value = "all" # all, ddl, mod, none
#   }

#   # 성능 최적화
#   parameter {
#     name  = "shared_preload_libraries"
#     value = "pg_stat_statements"
#   }

#   parameter {
#     name  = "max_connections"
#     value = "100"
#   }

#   # 한국 시간대
#   parameter {
#     name  = "timezone"
#     value = "Asia/Seoul"
#   }

#   tags = merge(
#     local.common_tags,
#     {
#       Name = local.rds_parameter_group_name
#     }
#   )
# }

# ==========================================
# RDS Instance
# ==========================================

resource "aws_db_instance" "main" {
  # 식별자
  identifier = local.rds_identifier

  # 엔진 설정
  engine         = "postgres"
  engine_version = var.rds_engine_version

  # 인스턴스 설정
  instance_class    = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage
  #   max_allocated_storage = var.rds_max_allocated_storage # Auto Scaling
  storage_type      = var.rds_storage_type
  storage_encrypted = var.rds_storage_encrypted

  # 데이터베이스 설정
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  # 네트워크 설정
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_security_group_id]
  publicly_accessible    = false # Private Subnet에만 배치

  # 가용성
  multi_az = var.rds_multi_az

  # Parameter Group
  #   parameter_group_name = aws_db_parameter_group.main.name

  # 백업 설정
  backup_retention_period   = var.rds_backup_retention_period
  backup_window             = var.rds_backup_window
  copy_tags_to_snapshot     = true
  skip_final_snapshot       = var.rds_skip_final_snapshot
  final_snapshot_identifier = local.final_snapshot_identifier

  # 유지보수
  maintenance_window         = var.rds_maintenance_window
  auto_minor_version_upgrade = true

  # 삭제 방지
  deletion_protection = var.rds_deletion_protection

  # 모니터링
  #   enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  #   monitoring_interval             = 60 # 60초 간격 (Enhanced Monitoring)
  #   monitoring_role_arn             = aws_iam_role.rds_enhanced_monitoring.arn

  # Performance Insights (t3.micro는 지원 안 함)
  #   performance_insights_enabled = var.rds_performance_insights_enabled

  # 태그
  tags = merge(
    local.common_tags,
    {
      Name = local.rds_identifier
    }
  )

  lifecycle {
    # 비밀번호 변경 시 재생성 방지
    ignore_changes = [password]
  }
}

# ==========================================
# Enhanced Monitoring IAM Role
# ==========================================

# resource "aws_iam_role" "rds_enhanced_monitoring" {
#   name = "${var.name_prefix}-rds-enhanced-monitoring"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "monitoring.rds.amazonaws.com"
#         }
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })

#   tags = local.common_tags
# }

# resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
#   role       = aws_iam_role.rds_enhanced_monitoring.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
# }
