# Velero Backup Infrastructure Module
# Provides S3 bucket, IAM roles (IRSA), and KMS encryption for Velero cluster migration
# Reference: https://velero.io/docs/main/contributions/ibm-config/

locals {
  velero_namespace     = "velero"
  velero_sa_name       = "velero"
  bucket_name          = "${var.project_name}-velero-${var.environment}-${var.aws_region}"
  replication_bucket   = var.enable_cross_region_replication ? "${var.project_name}-velero-${var.environment}-${var.replication_region}" : null

  # Resource resolution (create or reference existing)
  velero_role_arn  = var.create_iam_role ? aws_iam_role.velero[0].arn : var.existing_velero_role_arn
  velero_role_name = var.create_iam_role ? aws_iam_role.velero[0].name : split("/", var.existing_velero_role_arn)[1]
  bucket_arn       = var.create_bucket ? aws_s3_bucket.velero[0].arn : var.existing_bucket_arn
  bucket_id        = var.create_bucket ? aws_s3_bucket.velero[0].id : var.existing_bucket_id
}

# ============================================================================
# KMS Key for Velero Backup Encryption (only when creating bucket)
# ============================================================================
resource "aws_kms_key" "velero" {
  count                   = var.create_bucket ? 1 : 0
  description             = "KMS key for Velero backups encryption"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Velero to use the key"
        Effect = "Allow"
        Principal = {
          AWS = local.velero_role_arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow S3 Service to use the key"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-velero-kms"
    Environment = var.environment
    Purpose     = "velero-backup-encryption"
  }

  depends_on = [aws_iam_role.velero]
}

resource "aws_kms_alias" "velero" {
  count         = var.create_bucket ? 1 : 0
  name          = "alias/${var.project_name}-velero-${var.environment}"
  target_key_id = aws_kms_key.velero[0].key_id
}

# ============================================================================
# S3 Bucket for Velero Backups (only when create_bucket is true)
# ============================================================================
resource "aws_s3_bucket" "velero" {
  count  = var.create_bucket ? 1 : 0
  bucket = local.bucket_name

  tags = {
    Name        = local.bucket_name
    Environment = var.environment
    Purpose     = "velero-backup-storage"
  }
}

resource "aws_s3_bucket_versioning" "velero" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.velero[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "velero" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.velero[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.velero[0].arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "velero" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.velero[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "velero" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.velero[0].id

  rule {
    id     = "backup-lifecycle"
    status = "Enabled"

    # Apply to all objects in the bucket
    filter {}

    # Move to Glacier after 30 days
    transition {
      days          = var.backup_transition_glacier_days
      storage_class = "GLACIER"
    }

    # Delete old backups after retention period
    expiration {
      days = var.backup_retention_days
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.backup_retention_days
    }
  }
}

# ============================================================================
# Cross-Region Replication (Optional - only when creating bucket)
# ============================================================================
resource "aws_s3_bucket" "velero_replica" {
  count    = var.create_bucket && var.enable_cross_region_replication ? 1 : 0
  provider = aws.replication
  bucket   = local.replication_bucket

  tags = {
    Name        = local.replication_bucket
    Environment = var.environment
    Purpose     = "velero-backup-replica"
  }
}

resource "aws_s3_bucket_versioning" "velero_replica" {
  count    = var.create_bucket && var.enable_cross_region_replication ? 1 : 0
  provider = aws.replication
  bucket   = aws_s3_bucket.velero_replica[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# KMS key for replica bucket (in replication region)
resource "aws_kms_key" "velero_replica" {
  count                   = var.create_bucket && var.enable_cross_region_replication ? 1 : 0
  provider                = aws.replication
  description             = "KMS key for Velero backup replica bucket"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-velero-replica-kms"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "velero_replica" {
  count         = var.create_bucket && var.enable_cross_region_replication ? 1 : 0
  provider      = aws.replication
  name          = "alias/${var.project_name}-velero-replica"
  target_key_id = aws_kms_key.velero_replica[0].key_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "velero_replica" {
  count    = var.create_bucket && var.enable_cross_region_replication ? 1 : 0
  provider = aws.replication
  bucket   = aws_s3_bucket.velero_replica[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.velero_replica[0].arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "velero_replica" {
  count    = var.create_bucket && var.enable_cross_region_replication ? 1 : 0
  provider = aws.replication
  bucket   = aws_s3_bucket.velero_replica[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Replication Configuration
resource "aws_iam_role" "replication" {
  count = var.create_bucket && var.enable_cross_region_replication ? 1 : 0
  name  = "${var.project_name}-velero-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "s3.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "replication" {
  count = var.create_bucket && var.enable_cross_region_replication ? 1 : 0
  name  = "${var.project_name}-velero-replication-policy"
  role  = aws_iam_role.replication[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = local.bucket_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${local.bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "${aws_s3_bucket.velero_replica[0].arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = aws_kms_key.velero[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.velero_replica[0].arn
      }
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "velero" {
  count  = var.create_bucket && var.enable_cross_region_replication ? 1 : 0
  bucket = local.bucket_id
  role   = aws_iam_role.replication[0].arn

  # Both source and destination buckets must have versioning enabled
  depends_on = [
    aws_s3_bucket_versioning.velero,
    aws_s3_bucket_versioning.velero_replica
  ]

  rule {
    id     = "velero-cross-region-replication"
    status = "Enabled"

    # Filter is required for replication rules (V2)
    filter {}

    # Source objects are encrypted with KMS
    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }

    destination {
      bucket        = aws_s3_bucket.velero_replica[0].arn
      storage_class = "STANDARD"

      # Re-encrypt with destination KMS key
      encryption_configuration {
        replica_kms_key_id = aws_kms_key.velero_replica[0].arn
      }
    }

    delete_marker_replication {
      status = "Enabled"
    }
  }
}

# ============================================================================
# IAM Role for Velero (IRSA - IAM Roles for Service Accounts)
# Only created when create_iam_role is true
# ============================================================================
data "aws_caller_identity" "current" {}

locals {
  # Primary + additional OIDC providers for multi-region IRSA
  all_oidc_providers = concat([var.eks_oidc_provider_arn], var.additional_oidc_providers)
}

data "aws_iam_policy_document" "velero_assume_role" {
  count = var.create_iam_role ? 1 : 0

  # Create a statement for each OIDC provider (primary + additional regions)
  dynamic "statement" {
    for_each = local.all_oidc_providers
    content {
      effect = "Allow"
      principals {
        type        = "Federated"
        identifiers = [statement.value]
      }
      actions = ["sts:AssumeRoleWithWebIdentity"]
      condition {
        test     = "StringEquals"
        variable = "${replace(statement.value, "/^arn:aws:iam::[0-9]+:oidc-provider\\//", "")}:sub"
        values   = ["system:serviceaccount:${local.velero_namespace}:${local.velero_sa_name}"]
      }
      condition {
        test     = "StringEquals"
        variable = "${replace(statement.value, "/^arn:aws:iam::[0-9]+:oidc-provider\\//", "")}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_role" "velero" {
  count              = var.create_iam_role ? 1 : 0
  name               = "${var.project_name}-velero-irsa-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.velero_assume_role[0].json

  tags = {
    Name        = "${var.project_name}-velero-irsa"
    Environment = var.environment
  }
}

# Velero IAM Policy - Based on official Velero AWS documentation
# Reference: https://velero.io/docs/main/contributions/ibm-config/
resource "aws_iam_policy" "velero" {
  count       = var.create_iam_role ? 1 : 0
  name        = "${var.project_name}-velero-policy-${var.environment}"
  description = "IAM policy for Velero backup and restore operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2Permissions"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3BucketPermissions"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = [
          "${local.bucket_arn}/*"
        ]
      },
      {
        Sid    = "S3ListBucketPermissions"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          local.bucket_arn
        ]
      },
      {
        Sid    = "KMSPermissions"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = [
          aws_kms_key.velero[0].arn
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-velero-policy"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "velero" {
  count      = var.create_iam_role ? 1 : 0
  role       = aws_iam_role.velero[0].name
  policy_arn = aws_iam_policy.velero[0].arn
}

# Additional policy for cross-region operations
resource "aws_iam_policy" "velero_cross_region" {
  count       = var.create_iam_role && var.create_bucket && var.enable_cross_region_replication ? 1 : 0
  name        = "${var.project_name}-velero-cross-region-${var.environment}"
  description = "Additional IAM policy for Velero cross-region operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CrossRegionS3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.velero_replica[0].arn,
          "${aws_s3_bucket.velero_replica[0].arn}/*"
        ]
      },
      {
        Sid    = "CrossRegionEC2Snapshots"
        Effect = "Allow"
        Action = [
          "ec2:CopySnapshot",
          "ec2:DescribeSnapshots"
        ]
        Resource = "*"
      },
      {
        Sid    = "CrossRegionKMSPermissions"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = [
          aws_kms_key.velero_replica[0].arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "velero_cross_region" {
  count      = var.create_iam_role && var.create_bucket && var.enable_cross_region_replication ? 1 : 0
  role       = aws_iam_role.velero[0].name
  policy_arn = aws_iam_policy.velero_cross_region[0].arn
}
