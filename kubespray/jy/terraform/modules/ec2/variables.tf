# modules/ec2/variables.tf
# EC2 모듈 입력 변수

# ==========================================
# 기본 설정
# ==========================================

variable "environment" {
  description = "환경 (dev, staging, prod)"
  type        = string
}

variable "name_prefix" {
  description = "리소스 이름 접두사"
  type        = string
}

# ==========================================
# VPC 및 네트워크 설정
# ==========================================

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_a_id" {
  description = "Public Subnet A ID (NAT Instance용)"
  type        = string
}

variable "public_subnet_b_id" {
  description = "Public Subnet B ID (Bastion Host용)"
  type        = string
}

variable "private_subnet_a_id" {
  description = "Private Subnet A ID (Control Plane, Worker 1용)"
  type        = string
}

variable "private_subnet_b_id" {
  description = "Private Subnet B ID (Worker 2용)"
  type        = string
}

variable "private_route_table_ids" {
  description = "Private Route Table IDs (NAT Instance 라우트 추가용)"
  type        = map(string)
}

# ==========================================
# Security Groups
# ==========================================

variable "nat_instance_security_group_id" {
  description = "NAT Instance Security Group ID"
  type        = string
}

variable "bastion_security_group_id" {
  description = "Bastion Host Security Group ID"
  type        = string
}

variable "control_plane_security_group_id" {
  description = "Control Plane Security Group ID"
  type        = string
}

variable "worker_node_security_group_id" {
  description = "Worker Node Security Group ID"
  type        = string
}

# ==========================================
# EC2 인스턴스 설정
# ==========================================

variable "key_pair_name" {
  description = "SSH Key Pair 이름"
  type        = string
}

variable "nat_instance_type" {
  description = "NAT Instance 타입"
  type        = string
  default     = "t3.micro"
}

variable "bastion_instance_type" {
  description = "Bastion Host 인스턴스 타입"
  type        = string
  default     = "t3.micro"
}

variable "control_plane_instance_type" {
  description = "Control Plane 인스턴스 타입"
  type        = string
  default     = "t3.small"
}

variable "worker_node_instance_type" {
  description = "Worker Node 인스턴스 타입"
  type        = string
  default     = "t3.small"
}

variable "worker_node_count" {
  description = "Worker Node 개수"
  type        = number
  default     = 2

  validation {
    condition     = var.worker_node_count >= 1 && var.worker_node_count <= 10
    error_message = "Worker Node는 1~10개 사이여야 합니다."
  }
}

# ==========================================
# Kubernetes 설정
# ==========================================

variable "k8s_cluster_name" {
  description = "Kubernetes 클러스터 이름"
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes 버전"
  type        = string
  default     = "v1.34.1"
}

variable "kubespray_version" {
  description = "Kubespray 버전"
  type        = string
  default     = "2.29"
}

# ==========================================
# IAM Role ARNs (다른 모듈에서 생성)
# ==========================================

variable "ec2_kubernetes_instance_profile_name" {
  description = "EC2 Instance Profile 이름"
  type        = string
}

# ==========================================
# EBS 볼륨 설정
# ==========================================

variable "root_volume_size" {
  description = "Root EBS 볼륨 크기 (GB)"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Root EBS 볼륨 타입"
  type        = string
  default     = "gp3"
}

variable "enable_ebs_encryption" {
  description = "EBS 암호화 활성화"
  type        = bool
  default     = true
}

# ==========================================
# 태그
# ==========================================

variable "tags" {
  description = "리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}
