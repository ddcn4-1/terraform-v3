# modules/ec2/main.tf
# EC2 인스턴스 리소스 정의

# ==========================================
# NAT Instance
# ==========================================

# Elastic IP for NAT Instance
resource "aws_eip" "nat_instance" {
  domain = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-nat-instance-eip"
    }
  )
}

# NAT Instance
resource "aws_instance" "nat_instance" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.nat_instance_type

  # Public Subnet A에 배치
  subnet_id = var.public_subnet_a_id

  # associate_public_ip_address = false

  # Security Group
  vpc_security_group_ids = [var.nat_instance_security_group_id]

  # SSH Key
  key_name = var.key_pair_name

  # Source/Destination Check 비활성화 (NAT 필수!)
  source_dest_check = false

  # User Data
  user_data = file("${path.module}/user-data/nat-instance.sh")

  # Root Volume
  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = 8 # NAT Instance는 작은 볼륨으로 충분
    delete_on_termination = true
    encrypted             = var.enable_ebs_encryption
  }

  # 상세 모니터링 (선택적, 비용 증가)
  monitoring = false

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-nat-instance"
      Role = "nat"
    }
  )

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = true             # 삭제 방지
    ignore_changes        = [ami, user_data] # AMI ID는 자주 바뀌므로 무시
  }
}

# EIP를 NAT Instance에 연결
resource "aws_eip_association" "nat_instance" {
  instance_id   = aws_instance.nat_instance.id
  allocation_id = aws_eip.nat_instance.id
}

# NAT Instance를 Private Route Table에 추가
resource "aws_route" "private_nat_instance" {
  for_each = var.private_route_table_ids

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat_instance.primary_network_interface_id

  depends_on = [aws_instance.nat_instance]
}

resource "terraform_data" "wait_for_nat_init" {
  depends_on = [aws_instance.nat_instance, aws_eip_association.nat_instance]

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /tmp/nat-instance-setup-complete ]; do echo 'Waiting for user data...'; sleep 5; done",
      "echo 'User data script complete.'"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/${var.key_pair_name}.pem")
      host        = aws_eip.nat_instance.public_ip
    }
  }
}
# ==========================================
# Bastion Host
# ==========================================

# Elastic IP for Bastion Host
resource "aws_eip" "bastion" {
  domain = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-bastion-eip"
    }
  )
}

# Bastion Host
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.bastion_instance_type

  # Public Subnet B에 배치
  subnet_id = var.public_subnet_b_id

  # Security Group
  vpc_security_group_ids = [var.bastion_security_group_id]

  # SSH Key
  key_name = var.key_pair_name

  # User Data (템플릿 사용)
  user_data = templatefile("${path.module}/user-data/bastion-host.sh", {
    kubespray_version = var.kubespray_version
    k8s_version       = var.k8s_version
  })

  # Root Volume
  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = var.enable_ebs_encryption
  }

  monitoring = false

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-bastion"
      Role = "bastion"
    }
  )

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = true             # 삭제 방지
    ignore_changes        = [ami, user_data] # AMI ID는 자주 바뀌므로 무시
  }
}

# EIP를 Bastion Host에 연결
resource "aws_eip_association" "bastion" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.id
}

# ==========================================
# Kubernetes Control Plane
# ==========================================

resource "aws_instance" "control_plane" {
  ami           = data.aws_ami.ubuntu_24_04.id
  instance_type = var.control_plane_instance_type

  # Private Subnet A에 배치
  subnet_id = var.private_subnet_a_id

  # Security Group
  vpc_security_group_ids = [var.control_plane_security_group_id]

  # SSH Key
  key_name = var.key_pair_name

  # IAM Instance Profile
  iam_instance_profile = var.ec2_kubernetes_instance_profile_name

  # User Data
  user_data = templatefile("${path.module}/user-data/control-plane.sh", {
    hostname = "k8s-control-plane"
  })

  # Root Volume
  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = var.enable_ebs_encryption
  }

  # etcd 데이터용 추가 EBS 볼륨 (선택적)
  # ebs_block_device {
  #   device_name           = "/dev/sdf"
  #   volume_type           = "gp3"
  #   volume_size           = 50
  #   encrypted             = true
  #   delete_on_termination = true
  # }

  monitoring = true # Control Plane은 모니터링 권장

  depends_on = [terraform_data.wait_for_nat_init]

  tags = merge(
    local.common_tags,
    {
      Name                                            = "${var.name_prefix}-control-plane"
      Role                                            = "control-plane"
      "kubernetes.io/cluster/${var.k8s_cluster_name}" = "owned"
    }
  )

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = true             # 삭제 방지
    ignore_changes        = [ami, user_data] # AMI ID는 자주 바뀌므로 무시
  }
}

# ==========================================
# Kubernetes Worker Nodes
# ==========================================

resource "aws_instance" "worker_nodes" {
  count = var.worker_node_count

  ami           = data.aws_ami.ubuntu_24_04.id
  instance_type = var.worker_node_instance_type

  # AZ 분산 배치 (count.index로 Subnet 선택)
  subnet_id = local.worker_node_subnets[count.index]

  # Security Group
  vpc_security_group_ids = [var.worker_node_security_group_id]

  # SSH Key
  key_name = var.key_pair_name

  # IAM Instance Profile
  iam_instance_profile = var.ec2_kubernetes_instance_profile_name

  # User Data
  user_data = templatefile("${path.module}/user-data/worker-node.sh", {
    hostname   = local.worker_node_names[count.index]
    node_index = count.index + 1
  })

  # Root Volume
  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = var.enable_ebs_encryption
  }

  # Container 이미지용 추가 EBS 볼륨 (선택적)
  # ebs_block_device {
  #   device_name           = "/dev/sdf"
  #   volume_type           = "gp3"
  #   volume_size           = 100
  #   encrypted             = true
  #   delete_on_termination = true
  # }

  monitoring = true

  depends_on = [terraform_data.wait_for_nat_init]

  tags = merge(
    local.common_tags,
    {
      Name                                            = "${var.name_prefix}-${local.worker_node_names[count.index]}"
      Role                                            = "worker-node"
      AZ                                              = local.worker_node_azs[count.index]
      "kubernetes.io/cluster/${var.k8s_cluster_name}" = "owned"
    }
  )

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = true             # 삭제 방지
    ignore_changes        = [ami, user_data] # AMI ID는 자주 바뀌므로 무시
  }
}
