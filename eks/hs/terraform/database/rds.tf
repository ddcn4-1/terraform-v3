# RDS PostgreSQL Configuration
# Creates a PostgreSQL database instance in private subnets

# DB Subnet Group (uses core-infra database subnets)
resource "aws_db_subnet_group" "postgres" {
  name_prefix = "${var.project_name}-postgres-"
  description = "Database subnet group for PostgreSQL"
  subnet_ids  = data.terraform_remote_state.core_infra.outputs.database_subnets

  tags = {
    Name        = "${var.project_name}-postgres-subnet-group"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# DB Parameter Group
resource "aws_db_parameter_group" "postgres" {
  name_prefix = "${var.project_name}-postgres-"
  family      = "postgres15"
  description = "Custom parameter group for PostgreSQL 15"

  # Performance and logging parameters
  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # Log queries taking more than 1 second
  }

  tags = {
    Name        = "${var.project_name}-postgres-params"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Generate random password for RDS master user
resource "random_password" "rds_master_password" {
  length  = 32
  special = true
  # Exclude characters that might cause issues in connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store RDS password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "rds_password" {
  name_prefix             = "${var.project_name}-rds-password-"
  description             = "RDS PostgreSQL master password"
  recovery_window_in_days = 7

  tags = {
    Name        = "${var.project_name}-rds-password"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "rds_password" {
  secret_id     = aws_secretsmanager_secret.rds_password.id
  secret_string = random_password.rds_master_password.result
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "postgres" {
  identifier_prefix = "${var.project_name}-postgres-"

  # Engine configuration
  engine               = "postgres"
  engine_version       = var.rds_engine_version
  instance_class       = var.rds_instance_class
  allocated_storage    = var.rds_allocated_storage
  storage_type         = "gp3"
  storage_encrypted    = true
  # kms_key_id         = aws_kms_key.rds.arn # Uncomment to use custom KMS key

  # Database configuration
  db_name  = var.rds_database_name
  username = var.rds_username
  password = random_password.rds_master_password.result
  port     = var.rds_port

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [data.terraform_remote_state.core_infra.outputs.rds_security_group_id]
  publicly_accessible    = false

  # Parameter group
  parameter_group_name = aws_db_parameter_group.postgres.name

  # Backup configuration
  backup_retention_period = var.rds_backup_retention_period
  backup_window           = "03:00-04:00" # UTC time
  maintenance_window      = "mon:04:00-mon:05:00"
  skip_final_snapshot     = true # Set to false in production
  # final_snapshot_identifier = "${var.project_name}-postgres-final-snapshot"

  # High availability
  multi_az = var.rds_multi_az

  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn

  # Performance Insights
  performance_insights_enabled    = true
  performance_insights_retention_period = 7 # Free tier

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  # Deletion protection (enable in production)
  deletion_protection = false

  tags = {
    Name        = "${var.project_name}-postgres"
    Environment = var.environment
  }

  lifecycle {
    ignore_changes = [
      password, # Password managed by Secrets Manager rotation
    ]
  }
}

# IAM Role for Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name_prefix = "${var.project_name}-rds-monitoring-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-rds-monitoring"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# KMS Key for RDS encryption (optional, currently using default AWS managed key)
# Uncomment if you want to use a custom KMS key
# resource "aws_kms_key" "rds" {
#   description             = "KMS key for RDS encryption"
#   deletion_window_in_days = 7
#   enable_key_rotation     = true
#
#   tags = {
#     Name        = "${var.project_name}-rds-encryption"
#     Environment = var.environment
#   }
# }
#
# resource "aws_kms_alias" "rds" {
#   name          = "alias/${var.project_name}-rds"
#   target_key_id = aws_kms_key.rds.key_id
# }

# CloudWatch Alarms for RDS monitoring
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.project_name}-rds-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS CPU utilization"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }

  tags = {
    Name        = "${var.project_name}-rds-cpu-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "${var.project_name}-rds-free-storage-space"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "2000000000" # 2GB in bytes
  alarm_description   = "This metric monitors RDS free storage space"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }

  tags = {
    Name        = "${var.project_name}-rds-storage-alarm"
    Environment = var.environment
  }
}
