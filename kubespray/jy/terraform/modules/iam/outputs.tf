# modules/iam/outputs.tf
# IAM 모듈 출력값

# ==========================================
# EC2 Instance Role
# ==========================================

output "ec2_kubernetes_instance_role_arn" {
  description = "EC2 Instance Role ARN"
  value       = aws_iam_role.ec2_kubernetes_instance_role.arn
}

output "ec2_kubernetes_instance_role_name" {
  description = "EC2 Instance Role 이름"
  value       = aws_iam_role.ec2_kubernetes_instance_role.name
}

output "ec2_kubernetes_instance_profile_name" {
  description = "EC2 Instance Profile 이름 (EC2에 연결용)"
  value       = aws_iam_instance_profile.ec2_kubernetes_instance_profile.name
}

output "ec2_kubernetes_instance_profile_arn" {
  description = "EC2 Instance Profile ARN"
  value       = aws_iam_instance_profile.ec2_kubernetes_instance_profile.arn
}
