# providers.tf

provider "aws" {
  region = var.aws_region

  # 모든 리소스에 기본 태그 자동 적용 (Best Practice!)
  default_tags {
    tags = local.common_tags
  }
}

# CloudFront와 ACM 인증서는 us-east-1에서만 사용 가능
# Alias를 사용하여 여러 리전 Provider 정의
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.common_tags
  }
}