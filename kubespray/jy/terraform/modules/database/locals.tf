# modules/database/locals.tf
# 데이터베이스 모듈 로컬 변수

locals {
  # 공통 태그
  common_tags = merge(
    var.tags,
    {
      Module = "database"
    }
  )

  # RDS 식별자
  rds_identifier = "${var.name_prefix}-postgres"

  # ElastiCache 식별자
  redis_cluster_id = "${var.name_prefix}-redis"

  # Parameter Group 이름
  rds_parameter_group_name   = "${var.name_prefix}-postgres-params"
  redis_parameter_group_name = "${var.name_prefix}-redis-params"

  # Subnet Group 이름
  rds_subnet_group_name   = "${var.name_prefix}-rds-subnet-group"
  redis_subnet_group_name = "${var.name_prefix}-redis-subnet-group"

  # 최종 스냅샷 이름
  final_snapshot_identifier = var.rds_skip_final_snapshot ? null : "${local.rds_identifier}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
}
