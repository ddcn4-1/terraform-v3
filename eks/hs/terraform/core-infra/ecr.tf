# ============================================================================
# ECR Repository for Backend-v3
# ============================================================================

resource "aws_ecr_repository" "backend_v3" {
  name                 = "backend-v3"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.project_name}-backend-v3"
    Environment = var.environment
    ManagedBy   = "terraform"
    Service     = "backend-v3"
  }
}

# Lifecycle policy to manage image retention
resource "aws_ecr_lifecycle_policy" "backend_v3" {
  repository = aws_ecr_repository.backend_v3.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["main-", "admin-", "queue-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
