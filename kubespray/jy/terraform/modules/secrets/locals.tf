# modules/secrets/locals.tf
# Secrets Manager 모듈 로컬 변수

locals {
  # 공통 태그
  common_tags = merge(
    var.tags,
    {
      Module = "secrets"
    }
  )

  # Database URL 생성
  database_url = "postgresql://${var.db_host}:${var.db_port}/${var.db_name}"

  # Redis URL 생성
  redis_url = "redis://${var.redis_host}:${var.redis_port}"
}
