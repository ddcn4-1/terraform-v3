# Bootstrap resources for Terraform Backend
# This creates the S3 bucket and DynamoDB table needed for remote state management
# Run this ONCE before deploying the main infrastructure

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "mini-msa"
      Environment = "dev"
      ManagedBy   = "terraform-bootstrap"
      Owner       = "kimhxsong"
    }
  }
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-1"  # Tokyo region
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "hs-eks-tokyo"
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "Terraform State Bucket"
  }
}

# Enable versioning for state file recovery
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.project_name}-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform State Lock Table"
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Outputs to use in main Terraform configuration
output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.id
}

output "aws_region" {
  description = "AWS region where backend resources are created"
  value       = var.aws_region
}

output "backend_config" {
  description = "Backend configuration for main Terraform"
  value = <<-EOT

    After running 'terraform apply', update your main terraform/backend.tf with:

    backend "s3" {
      bucket         = "${aws_s3_bucket.terraform_state.id}"
      key            = "eks/terraform.tfstate"
      region         = "${var.aws_region}"
      dynamodb_table = "${aws_dynamodb_table.terraform_locks.id}"
      encrypt        = true
    }
  EOT
}
