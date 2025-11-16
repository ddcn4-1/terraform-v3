# modules/vpc/locals.tf
# VPC 모듈 내부 로컬 변수

locals {
  # VPC 이름 prefix
  name_prefix = "${var.vpc_name}-${var.environment}"

  # 모든 Public Subnet IDs (생성 후)
  public_subnet_ids = [
    for key, subnet in aws_subnet.public : subnet.id
  ]

  # 모든 Private Subnet IDs (생성 후)
  private_subnet_ids = [
    for key, subnet in aws_subnet.private : subnet.id
  ]

  # NAT Gateway가 위치할 Subnet (AZ-A의 Public Subnet)
  nat_gateway_subnet_id = aws_subnet.public["a"].id

  # VPC Flow Logs용 CloudWatch Log Group 이름
  flow_log_group_name = "/aws/vpc/${local.name_prefix}"

  # 공통 태그
  common_tags = merge(
    var.tags,
    {
      Module = "vpc"
    }
  )
}