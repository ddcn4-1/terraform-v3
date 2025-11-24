# Terraform Backend Configuration for Core Infrastructure (Tokyo)
# This file configures remote state storage in S3 with DynamoDB locking

terraform {
  backend "s3" {
    # Tokyo region backend - will be created by bootstrap
    bucket         = "hs-eks-tokyo-tfstate-911723818289"
    key            = "eks/tokyo/core-infra/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "hs-eks-tokyo-tfstate-lock"
    encrypt        = true
  }
}

# Alternative: Local backend (for testing, uncomment if needed)
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }
