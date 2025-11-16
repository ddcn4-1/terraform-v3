# modules/vpc/main.tf
# VPC 및 네트워킹 리소스 정의

# ==========================================
# VPC
# ==========================================

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # DNS 설정 (중요!)
  enable_dns_hostnames = var.enable_dns_hostnames  # EC2에 DNS 호스트네임 할당
  enable_dns_support   = var.enable_dns_support    # VPC 내 DNS 해석 활성화

  # 태그
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-vpc"
      "kubernetes.io/cluster/kubernetes-pjy" = "shared"
    }
  )
}

# ==========================================
# Internet Gateway
# ==========================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-igw"
    }
  )
}

# ==========================================
# Public Subnets
# ==========================================

resource "aws_subnet" "public" {
  # for_each로 여러 Subnet 생성
  for_each = var.public_subnet_cidrs

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = var.azs[each.key]

  # Public IP 자동 할당 (Public Subnet의 특징)
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-public-${each.key}"
      Tier = "Public"
      AZ   = each.key
      
      # Kubernetes AWS Load Balancer Controller용 태그
      "kubernetes.io/role/elb" = "1"
      "kubernetes.io/cluster/kubernetes-pjy" = "shared"
    }
  )
}

# ==========================================
# Private Subnets
# ==========================================

resource "aws_subnet" "private" {
  for_each = var.private_subnet_cidrs

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = var.azs[each.key]

  # Private IP만 할당 (Public IP 없음)
  map_public_ip_on_launch = false

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-private-${each.key}"
      Tier = "Private"
      AZ   = each.key
      
      # Kubernetes AWS Load Balancer Controller용 태그
      "kubernetes.io/role/internal-elb" = "1"
      "kubernetes.io/cluster/kubernetes-pjy" = "shared"
    }
  )
}

# ==========================================
# Elastic IP for NAT Gateway (조건부)
# ==========================================

resource "aws_eip" "nat" {
  # NAT Gateway를 사용하는 경우에만 생성
  count = var.enable_nat_gateway ? 1 : 0

  domain = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-nat-eip"
    }
  )

  # Internet Gateway가 생성된 후에 EIP 생성
  depends_on = [aws_internet_gateway.main]
}

# ==========================================
# NAT Gateway (조건부)
# ==========================================

resource "aws_nat_gateway" "main" {
  # NAT Gateway를 사용하는 경우에만 생성
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = local.nat_gateway_subnet_id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-nat-gateway"
    }
  )

  # Internet Gateway가 완전히 연결된 후 NAT Gateway 생성
  depends_on = [aws_internet_gateway.main]
}

# ==========================================
# Route Table - Public
# ==========================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-public-rt"
      Tier = "Public"
    }
  )
}

# Public Route Table에 Internet Gateway로 가는 라우트 추가
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Public Subnet과 Public Route Table 연결
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ==========================================
# Route Table - Private (AZ별)
# ==========================================

# AZ별로 Private Route Table 생성 (NAT Instance는 AZ-A에만)
resource "aws_route_table" "private" {
  for_each = var.private_subnet_cidrs

  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-private-rt-${each.key}"
      Tier = "Private"
      AZ   = each.key
    }
  )
}

# NAT Gateway를 사용하는 경우: Private Route
resource "aws_route" "private_nat_gateway" {
  # NAT Gateway를 사용하는 경우에만 생성
  for_each = var.enable_nat_gateway ? var.private_subnet_cidrs : {}

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

# Private Subnet과 Private Route Table 연결
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
