# modules/vpc/outputs.tf
# VPC 모듈 출력값

# ==========================================
# VPC 정보
# ==========================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_arn" {
  description = "VPC ARN"
  value       = aws_vpc.main.arn
}

output "vpc_cidr_block" {
  description = "VPC CIDR 블록"
  value       = aws_vpc.main.cidr_block
}

# ==========================================
# Subnet 정보
# ==========================================

output "public_subnet_ids" {
  description = "Public Subnet ID 목록"
  value       = local.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private Subnet ID 목록"
  value       = local.private_subnet_ids
}

output "public_subnet_cidrs" {
  description = "Public Subnet CIDR 블록 맵"
  value = {
    for key, subnet in aws_subnet.public : key => subnet.cidr_block
  }
}

output "private_subnet_cidrs" {
  description = "Private Subnet CIDR 블록 맵"
  value = {
    for key, subnet in aws_subnet.private : key => subnet.cidr_block
  }
}

# 특정 AZ의 Subnet ID (EC2 모듈에서 사용)
output "public_subnet_a_id" {
  description = "Public Subnet A ID"
  value       = aws_subnet.public["a"].id
}

output "public_subnet_b_id" {
  description = "Public Subnet B ID"
  value       = aws_subnet.public["b"].id
}

output "private_subnet_a_id" {
  description = "Private Subnet A ID"
  value       = aws_subnet.private["a"].id
}

output "private_subnet_b_id" {
  description = "Private Subnet B ID"
  value       = aws_subnet.private["b"].id
}

# ==========================================
# Route Table 정보
# ==========================================

output "public_route_table_id" {
  description = "Public Route Table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Private Route Table ID 맵"
  value = {
    for key, rt in aws_route_table.private : key => rt.id
  }
}

# NAT Instance용: AZ-A Private Route Table ID
output "private_route_table_a_id" {
  description = "Private Route Table A ID (NAT Instance 라우트 추가용)"
  value       = aws_route_table.private["a"].id
}

# ==========================================
# Gateway 정보
# ==========================================

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID (사용 시)"
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[0].id : null
}

output "nat_gateway_public_ip" {
  description = "NAT Gateway Public IP (사용 시)"
  value       = var.enable_nat_gateway ? aws_eip.nat[0].public_ip : null
}