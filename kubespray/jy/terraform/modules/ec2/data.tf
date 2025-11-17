# modules/ec2/data.tf
# Data Sources - AMI 조회

# ==========================================
# Amazon Linux 2023 AMI (NAT Instance, Bastion Host용)
# ==========================================

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"] # Or "arm64" for ARM-based instances
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# ==========================================
# Ubuntu 24.04 LTS AMI (Kubernetes용)
# ==========================================

data "aws_ami" "ubuntu_24_04" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ==========================================
# 현재 리전 정보
# ==========================================

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}
