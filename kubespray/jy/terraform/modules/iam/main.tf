# modules/iam/main.tf
# IAM Role 및 Policy 리소스 정의

# ==========================================
# 데이터 소스
# ==========================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ==========================================
# EC2 Instance Role
# ==========================================

# Trust Relationship: EC2 서비스가 이 Role을 assume 가능
resource "aws_iam_role" "ec2_kubernetes_instance_role" {
  name = "${var.name_prefix}-ec2-kubernetes-instance-role"

  assume_role_policy = file("${path.module}/policies/ec2-trust-policy.json")

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-ec2-kubernetes-instance-role"
    }
  )
}

# EC2 Instance Profile (Role을 EC2에 연결하는 컨테이너)
resource "aws_iam_instance_profile" "ec2_kubernetes_instance_profile" {
  name = "${var.name_prefix}-ec2-kubernetes-instance-profile"
  role = aws_iam_role.ec2_kubernetes_instance_role.name

  tags = var.tags
}

# ==========================================
# Policies 선언
# ==========================================

# AWS LB Controller Policy
resource "aws_iam_policy" "aws-loadbalancer-controller-access" {
  name        = "${var.name_prefix}-aws-lb-controller-access-policy"
  description = "Allow aws loadbalancer-controller"

  policy = file("${path.module}/policies/aws-loadbalancer-controller-access-policy.json")
}

# ExternalDNS Policy
resource "aws_iam_policy" "external-dns-access" {
  name        = "${var.name_prefix}-external-dns-access-policy"
  description = "Allow External DNS"

  policy = file("${path.module}/policies/external-dns-access-policy.json")
}

# External-Secret-Operator Policy
resource "aws_iam_policy" "external-secret-operator-access" {
  name        = "${var.name_prefix}-external-secret-operator-access-policy"
  description = "Allow External Secret Operator"

  # 내 계정 ID의 secrets manager 접근 허용
  policy = templatefile("${path.module}/policies/external-secret-operator-access-policy.json", {
    secrets_arn_prefix = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:*"
  })
}

# ==========================================
# Policies를 Iam role에 등록
# ==========================================

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.ec2_kubernetes_instance_role.name
  policy_arn = aws_iam_policy.aws-loadbalancer-controller-access.arn
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.ec2_kubernetes_instance_role.name
  policy_arn = aws_iam_policy.external-dns-access.arn
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.ec2_kubernetes_instance_role.name
  policy_arn = aws_iam_policy.external-secret-operator-access.arn
}
