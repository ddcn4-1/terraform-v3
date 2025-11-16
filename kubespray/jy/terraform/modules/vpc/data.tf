# modules/vpc/data.tf
# Data Sources - 외부 정보 조회

# 현재 리전 정보
data "aws_region" "current" {}

# 현재 계정 정보
data "aws_caller_identity" "current" {}

# 사용 가능한 Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}