# ECR Repositories for Mini MSA Services
# These repositories will store Docker images for core-service and queue-service

locals {
  ecr_repositories = {
    "core-service" = {
      image_tag_mutability = "MUTABLE"
      scan_on_push         = true
      lifecycle_policy     = jsonencode({
        rules = [{
          rulePriority = 1
          description  = "Keep last 10 images"
          selection = {
            tagStatus     = "tagged"
            tagPrefixList = ["v"]
            countType     = "imageCountMoreThan"
            countNumber   = 10
          }
          action = {
            type = "expire"
          }
        },
        {
          rulePriority = 2
          description  = "Delete untagged images after 7 days"
          selection = {
            tagStatus     = "untagged"
            countType     = "sinceImagePushed"
            countUnit     = "days"
            countNumber   = 7
          }
          action = {
            type = "expire"
          }
        }]
      })
    }
    "queue-service" = {
      image_tag_mutability = "MUTABLE"
      scan_on_push         = true
      lifecycle_policy     = jsonencode({
        rules = [{
          rulePriority = 1
          description  = "Keep last 10 images"
          selection = {
            tagStatus     = "tagged"
            tagPrefixList = ["v"]
            countType     = "imageCountMoreThan"
            countNumber   = 10
          }
          action = {
            type = "expire"
          }
        },
        {
          rulePriority = 2
          description  = "Delete untagged images after 7 days"
          selection = {
            tagStatus     = "untagged"
            countType     = "sinceImagePushed"
            countUnit     = "days"
            countNumber   = 7
          }
          action = {
            type = "expire"
          }
        }]
      })
    }
  }
}

# ECR Repositories
resource "aws_ecr_repository" "mini_msa" {
  for_each = local.ecr_repositories

  name                 = "${var.project_name}-${each.key}"
  image_tag_mutability = each.value.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = each.value.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${each.key}"
    Service     = each.key
    Environment = var.environment
  })
}

# Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "mini_msa" {
  for_each = local.ecr_repositories

  repository = aws_ecr_repository.mini_msa[each.key].name
  policy     = each.value.lifecycle_policy
}

# ECR Repository Policy - Allow EKS nodes to pull images
data "aws_iam_policy_document" "ecr_policy" {
  statement {
    sid    = "AllowPull"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }

    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
    ]
  }
}

resource "aws_ecr_repository_policy" "mini_msa" {
  for_each = local.ecr_repositories

  repository = aws_ecr_repository.mini_msa[each.key].name
  policy     = data.aws_iam_policy_document.ecr_policy.json
}

# IAM Policy for EKS nodes to pull from ECR
resource "aws_iam_policy" "ecr_pull" {
  name        = "${var.project_name}-ecr-pull-policy"
  description = "Policy to allow EKS nodes to pull images from ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-ecr-pull-policy"
    Environment = var.environment
  })
}

# Attach ECR pull policy to EKS node role
resource "aws_iam_role_policy_attachment" "ecr_pull" {
  for_each = module.eks.eks_managed_node_groups

  role       = each.value.iam_role_name
  policy_arn = aws_iam_policy.ecr_pull.arn
}
