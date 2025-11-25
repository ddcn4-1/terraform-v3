# ECR Module with Cross-Region Replication
# Supports multi-region image availability for disaster recovery

locals {
  repository_names = toset(var.repository_names)
}

# ============================================================================
# ECR Repositories (Primary Region)
# ============================================================================
resource "aws_ecr_repository" "main" {
  for_each = local.repository_names

  name                 = "${var.project_name}/${each.value}"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = var.encryption_type
    kms_key         = var.encryption_type == "KMS" ? var.kms_key_arn : null
  }

  tags = {
    Name        = "${var.project_name}/${each.value}"
    Environment = var.environment
  }
}

# ============================================================================
# Lifecycle Policy for All Repositories
# ============================================================================
resource "aws_ecr_lifecycle_policy" "main" {
  for_each   = local.repository_names
  repository = aws_ecr_repository.main[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.image_count_to_keep} images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "release", "prod"]
          countType     = "imageCountMoreThan"
          countNumber   = var.image_count_to_keep
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images older than ${var.untagged_image_retention_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_retention_days
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Keep only ${var.dev_image_count_to_keep} dev/staging images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev", "staging", "feature"]
          countType     = "imageCountMoreThan"
          countNumber   = var.dev_image_count_to_keep
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ============================================================================
# Cross-Region Replication Configuration
# ============================================================================
resource "aws_ecr_replication_configuration" "main" {
  count = var.enable_cross_region_replication ? 1 : 0

  replication_configuration {
    rule {
      dynamic "destination" {
        for_each = var.replication_regions
        content {
          region      = destination.value
          registry_id = data.aws_caller_identity.current.account_id
        }
      }

      dynamic "repository_filter" {
        for_each = var.replication_repository_filter != null ? [1] : []
        content {
          filter      = var.replication_repository_filter
          filter_type = "PREFIX_MATCH"
        }
      }
    }
  }
}

data "aws_caller_identity" "current" {}

# ============================================================================
# ECR Pull Through Cache (Optional)
# For caching upstream registries like Docker Hub, Quay, etc.
# ============================================================================
resource "aws_ecr_pull_through_cache_rule" "dockerhub" {
  count = var.enable_pull_through_cache ? 1 : 0

  ecr_repository_prefix = "dockerhub"
  upstream_registry_url = "registry-1.docker.io"
  credential_arn        = var.dockerhub_credential_secret_arn
}

resource "aws_ecr_pull_through_cache_rule" "quay" {
  count = var.enable_pull_through_cache && var.enable_quay_cache ? 1 : 0

  ecr_repository_prefix = "quay"
  upstream_registry_url = "quay.io"
}

resource "aws_ecr_pull_through_cache_rule" "kubernetes" {
  count = var.enable_pull_through_cache && var.enable_k8s_cache ? 1 : 0

  ecr_repository_prefix = "k8s"
  upstream_registry_url = "registry.k8s.io"
}

# ============================================================================
# Repository Policy for Cross-Account Access (Optional)
# ============================================================================
resource "aws_ecr_repository_policy" "cross_account" {
  for_each   = var.cross_account_arns != null ? local.repository_names : toset([])
  repository = aws_ecr_repository.main[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CrossAccountPull"
        Effect = "Allow"
        Principal = {
          AWS = var.cross_account_arns
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}
