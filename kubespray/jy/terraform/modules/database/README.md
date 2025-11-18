# database 모듈

AWS RDS (postgreSQL), ElastiCache (Redis) 구현

## 기능

- RDS 생성
- ElastiCache 생성

## 사용 예시

```hcl
module "database" {
  source = "./modules/database"

  # 기본 설정
  environment = "prod"
  name_prefix = "ticket-database"

  # 네트워크
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # Security Groups
  rds_security_group_id         = module.security_groups.rds_security_group_id
  elasticache_security_group_id = module.security_groups.elasticache_security_group_id

  # RDS 설정
  rds_instance_class      = local.rds_config.instance_class
  rds_allocated_storage   = local.rds_config.allocated_storage
  rds_storage_type        = local.rds_config.storage_type
  rds_engine_version      = local.rds_config.engine_version
  db_name                 = var.db_name
  db_username             = var.db_username
  db_password             = var.db_password
  rds_multi_az            = var.db_multi_az
  rds_deletion_protection = var.environment == "prod" ? true : false
  rds_skip_final_snapshot = var.environment == "prod" ? false : true

  # ElastiCache 설정
  redis_node_type       = local.elasticache_config.node_type
  redis_num_cache_nodes = var.redis_num_cache_nodes
  redis_engine_version  = "7.0"

  # 태그
  tags = local.common_tags

  # 의존성
  depends_on = [
    module.vpc,
    module.security_groups
  ]
}
```
