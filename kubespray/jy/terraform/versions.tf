# versions.tf

terraform {
  # backend S3 자체 잠금 활용 위해 1.10 이상 버전 필요
  required_version = "~> 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }
}

# version = "5.0.0"      # 정확히 5.0.0만 사용
# version = ">= 5.0.0"   # 5.0.0 이상
# version = "~> 5.0"     # 5.0.x 중 최신 (5.1, 5.2 포함, 6.0 제외)
# version = "~> 5.0.0"   # 5.0.x 중 최신 (5.1 제외)