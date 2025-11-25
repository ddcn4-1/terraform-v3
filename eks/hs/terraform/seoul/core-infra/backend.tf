# Terraform Backend Configuration for Core Infrastructure
# This file configures remote state storage in S3 with DynamoDB locking

terraform {
  backend "s3" {
    # Replace these values after running bootstrap
    bucket         = "hs-eks-tfstate-911723818289"
    key            = "eks/core-infra/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "hs-eks-tfstate-lock"
    encrypt        = true
  }
}

# Alternative: Local backend (for testing, uncomment if needed)
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }
