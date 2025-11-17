# modules/security-groups/main.tf
# Security Group 리소스 정의

# ==========================================
# ALB Security Group
# ==========================================

resource "aws_security_group" "alb" {
  name_prefix = "${local.sg_name.alb}-"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = local.sg_name.alb
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ALB Inbound: HTTP
resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTP from internet"
  security_group_id = aws_security_group.alb.id
}

# ALB Inbound: HTTPS
resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTPS from internet"
  security_group_id = aws_security_group.alb.id
}

# ALB Outbound: Application Port to Worker Nodes (Instance 모드)
resource "aws_security_group_rule" "alb_egress_application" {
  type                     = "egress"
  from_port                = local.k8s_ports.node_port_from
  to_port                  = local.k8s_ports.node_port_to
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.worker_node.id
  description              = "Allow traffic to application port on worker nodes (Instance mode)"
  security_group_id        = aws_security_group.alb.id
}

# ==========================================
# Bastion Host Security Group
# ==========================================

resource "aws_security_group" "bastion" {
  name_prefix = "${local.sg_name.bastion}-"
  description = "Security group for Bastion Host (SSH Jump Server)"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = local.sg_name.bastion
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Bastion Inbound: SSH from Admin IPs
resource "aws_security_group_rule" "bastion_ingress_ssh" {
  count = length(local.all_ssh_cidrs)

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [local.all_ssh_cidrs[count.index]]
  description       = "Allow SSH from admin IP ${local.all_ssh_cidrs[count.index]}"
  security_group_id = aws_security_group.bastion.id
}

# Bastion Outbound: SSH to Control Plane
resource "aws_security_group_rule" "bastion_egress_ssh_control_plane" {
  type                     = "egress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.control_plane.id
  description              = "Allow SSH to control plane"
  security_group_id        = aws_security_group.bastion.id
}

# Bastion Outbound: SSH to Worker Nodes
resource "aws_security_group_rule" "bastion_egress_ssh_worker_nodes" {
  type                     = "egress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.worker_node.id
  description              = "Allow SSH to worker nodes"
  security_group_id        = aws_security_group.bastion.id
}

# Bastion Outbound: Kubernetes API (kubectl 사용)
resource "aws_security_group_rule" "bastion_egress_k8s_api" {
  type                     = "egress"
  from_port                = local.k8s_ports.api_server
  to_port                  = local.k8s_ports.api_server
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.control_plane.id
  description              = "Allow Kubernetes API access"
  security_group_id        = aws_security_group.bastion.id
}

# Bastion Outbound: HTTPS (패키지 다운로드)
resource "aws_security_group_rule" "bastion_egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTPS for package downloads"
  security_group_id = aws_security_group.bastion.id
}

# Bastion Outbound: HTTP (패키지 다운로드)
resource "aws_security_group_rule" "bastion_egress_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTP for package downloads"
  security_group_id = aws_security_group.bastion.id
}

# ==========================================
# NAT Instance Security Group
# ==========================================

resource "aws_security_group" "nat_instance" {
  name_prefix = "${local.sg_name.nat_instance}-"
  description = "Security group for NAT Instance"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = local.sg_name.nat_instance
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# NAT Instance Inbound: HTTP from Private Subnets
resource "aws_security_group_rule" "nat_instance_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.private_subnet_cidrs
  description       = "Allow HTTP from private subnets"
  security_group_id = aws_security_group.nat_instance.id
}

# NAT Instance Inbound: HTTPS from Private Subnets
resource "aws_security_group_rule" "nat_instance_ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.private_subnet_cidrs
  description       = "Allow HTTPS from private subnets"
  security_group_id = aws_security_group.nat_instance.id
}

# NAT Instance Inbound: SSH from Bastion (관리용)
resource "aws_security_group_rule" "nat_instance_ingress_ssh" {
  count = length(local.all_ssh_cidrs)

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [local.all_ssh_cidrs[count.index]]
  description       = "Allow SSH from admin IP ${local.all_ssh_cidrs[count.index]}"
  security_group_id = aws_security_group.nat_instance.id
}

# NAT Instance Outbound: HTTP to Internet
resource "aws_security_group_rule" "nat_instance_egress_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTP to internet"
  security_group_id = aws_security_group.nat_instance.id
}

# NAT Instance Outbound: HTTPS to Internet
resource "aws_security_group_rule" "nat_instance_egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTPS to internet"
  security_group_id = aws_security_group.nat_instance.id
}

# ==========================================
# Control Plane Security Group
# ==========================================

resource "aws_security_group" "control_plane" {
  name_prefix = "${local.sg_name.control_plane}-"
  description = "Security group for Kubernetes Control Plane"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = local.sg_name.control_plane
      Role = "kubernetes-control-plane"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Control Plane Inbound: SSH from Bastion
resource "aws_security_group_rule" "control_plane_ingress_ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  description              = "Allow SSH from bastion"
  security_group_id        = aws_security_group.control_plane.id
}

# Control Plane Inbound: Kubernetes API from Worker Nodes
resource "aws_security_group_rule" "control_plane_ingress_api_workers" {
  type                     = "ingress"
  from_port                = local.k8s_ports.api_server
  to_port                  = local.k8s_ports.api_server
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.worker_node.id
  description              = "Allow Kubernetes API from worker nodes"
  security_group_id        = aws_security_group.control_plane.id
}

# Control Plane Inbound: Kubernetes API from Bastion (kubectl)
resource "aws_security_group_rule" "control_plane_ingress_api_bastion" {
  type                     = "ingress"
  from_port                = local.k8s_ports.api_server
  to_port                  = local.k8s_ports.api_server
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  description              = "Allow Kubernetes API from bastion (kubectl)"
  security_group_id        = aws_security_group.control_plane.id
}

# Control Plane Inbound: etcd Client from Control Plane (Self)
resource "aws_security_group_rule" "control_plane_ingress_etcd_client" {
  type              = "ingress"
  from_port         = local.k8s_ports.etcd_client
  to_port           = local.k8s_ports.etcd_client
  protocol          = "tcp"
  self              = true
  description       = "Allow etcd client port from control plane itself"
  security_group_id = aws_security_group.control_plane.id
}

# Control Plane Inbound: etcd Peer from Control Plane (Self)
resource "aws_security_group_rule" "control_plane_ingress_etcd_peer" {
  type              = "ingress"
  from_port         = local.k8s_ports.etcd_peer
  to_port           = local.k8s_ports.etcd_peer
  protocol          = "tcp"
  self              = true
  description       = "Allow etcd peer port from control plane itself"
  security_group_id = aws_security_group.control_plane.id
}

# Control Plane Inbound: Kubelet API from Worker Nodes
resource "aws_security_group_rule" "control_plane_ingress_kubelet" {
  type                     = "ingress"
  from_port                = local.k8s_ports.kubelet
  to_port                  = local.k8s_ports.kubelet
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.worker_node.id
  description              = "Allow Kubelet API from worker nodes"
  security_group_id        = aws_security_group.control_plane.id
}

# Control Plane Inbound: Kube-scheduler
resource "aws_security_group_rule" "control_plane_ingress_scheduler" {
  type                     = "ingress"
  from_port                = local.k8s_ports.kube_scheduler
  to_port                  = local.k8s_ports.kube_scheduler
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.worker_node.id
  description              = "Allow Kube-scheduler from worker nodes"
  security_group_id        = aws_security_group.control_plane.id
}

# Control Plane Inbound: Kube-controller-manager
resource "aws_security_group_rule" "control_plane_ingress_controller" {
  type                     = "ingress"
  from_port                = local.k8s_ports.kube_controller
  to_port                  = local.k8s_ports.kube_controller
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.worker_node.id
  description              = "Allow Kube-controller-manager from worker nodes"
  security_group_id        = aws_security_group.control_plane.id
}

# Control Plane Outbound: All (인터넷 접근 필요)
resource "aws_security_group_rule" "control_plane_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic"
  security_group_id = aws_security_group.control_plane.id
}

# ==========================================
# Worker Node Security Group
# ==========================================

resource "aws_security_group" "worker_node" {
  name_prefix = "${local.sg_name.worker_node}-"
  description = "Security group for Kubernetes Worker Nodes"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = local.sg_name.worker_node
      Role = "kubernetes-worker-node"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Worker Node Inbound: SSH from Bastion
resource "aws_security_group_rule" "worker_node_ingress_ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  description              = "Allow SSH from bastion"
  security_group_id        = aws_security_group.worker_node.id
}

# Worker Node Inbound: Kubelet from Control Plane
resource "aws_security_group_rule" "worker_node_ingress_kubelet_control_plane" {
  type                     = "ingress"
  from_port                = local.k8s_ports.kubelet
  to_port                  = local.k8s_ports.kubelet
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.control_plane.id
  description              = "Allow Kubelet API from control plane"
  security_group_id        = aws_security_group.worker_node.id
}

# Worker Node Inbound: Kubelet from Worker Nodes (Self)
resource "aws_security_group_rule" "worker_node_ingress_kubelet_self" {
  type              = "ingress"
  from_port         = local.k8s_ports.kubelet
  to_port           = local.k8s_ports.kubelet
  protocol          = "tcp"
  self              = true
  description       = "Allow Kubelet API from other worker nodes"
  security_group_id = aws_security_group.worker_node.id
}

# Worker Node Inbound: Application Port from ALB (Instance 모드)
resource "aws_security_group_rule" "worker_node_ingress_application_alb" {
  type                     = "ingress"
  from_port                = local.k8s_ports.node_port_from
  to_port                  = local.k8s_ports.node_port_to
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description              = "Allow application traffic from ALB (Instance mode)"
  security_group_id        = aws_security_group.worker_node.id
}

# Worker Node Inbound: All traffic from Worker Nodes (Pod-to-Pod)
resource "aws_security_group_rule" "worker_node_ingress_all_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  description       = "Allow all traffic between worker nodes (Pod networking)"
  security_group_id = aws_security_group.worker_node.id
}

# Worker Node Outbound: Kubernetes API to Control Plane
resource "aws_security_group_rule" "worker_node_egress_api" {
  type                     = "egress"
  from_port                = local.k8s_ports.api_server
  to_port                  = local.k8s_ports.api_server
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.control_plane.id
  description              = "Allow Kubernetes API to control plane"
  security_group_id        = aws_security_group.worker_node.id
}

# Worker Node Outbound: PostgreSQL to RDS
resource "aws_security_group_rule" "worker_node_egress_rds" {
  type                     = "egress"
  from_port                = var.rds_port
  to_port                  = var.rds_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds.id
  description              = "Allow PostgreSQL to RDS"
  security_group_id        = aws_security_group.worker_node.id
}

# Worker Node Outbound: Redis to ElastiCache
resource "aws_security_group_rule" "worker_node_egress_redis" {
  type                     = "egress"
  from_port                = var.redis_port
  to_port                  = var.redis_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.elasticache.id
  description              = "Allow Redis to ElastiCache"
  security_group_id        = aws_security_group.worker_node.id
}

# Worker Node Outbound: All to Internet (패키지 다운로드, ECR 등)
resource "aws_security_group_rule" "worker_node_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic"
  security_group_id = aws_security_group.worker_node.id
}

# ==========================================
# RDS Security Group
# ==========================================

resource "aws_security_group" "rds" {
  name_prefix = "${local.sg_name.rds}-"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = local.sg_name.rds
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# RDS Inbound: PostgreSQL from Worker Nodes
resource "aws_security_group_rule" "rds_ingress_postgres" {
  type                     = "ingress"
  from_port                = var.rds_port
  to_port                  = var.rds_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.worker_node.id
  description              = "Allow PostgreSQL from worker nodes"
  security_group_id        = aws_security_group.rds.id
}

# RDS Inbound: PostgreSQL from Bastion (관리용)
# resource "aws_security_group_rule" "rds_ingress_postgres_bastion" {
#   type                     = "ingress"
#   from_port                = var.rds_port
#   to_port                  = var.rds_port
#   protocol                 = "tcp"
#   source_security_group_id = aws_security_group.bastion.id
#   description              = "Allow PostgreSQL from bastion for management"
#   security_group_id        = aws_security_group.rds.id
# }

# RDS는 Outbound 규칙 불필요 (응답만 보냄)

# ==========================================
# ElastiCache Security Group
# ==========================================

resource "aws_security_group" "elasticache" {
  name_prefix = "${local.sg_name.elasticache}-"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = local.sg_name.elasticache
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ElastiCache Inbound: Redis from Worker Nodes
resource "aws_security_group_rule" "elasticache_ingress_redis" {
  type                     = "ingress"
  from_port                = var.redis_port
  to_port                  = var.redis_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.worker_node.id
  description              = "Allow Redis from worker nodes"
  security_group_id        = aws_security_group.elasticache.id
}

# ElastiCache Inbound: Redis from Bastion (관리용)
# resource "aws_security_group_rule" "elasticache_ingress_redis_bastion" {
#   type                     = "ingress"
#   from_port                = var.redis_port
#   to_port                  = var.redis_port
#   protocol                 = "tcp"
#   source_security_group_id = aws_security_group.bastion.id
#   description              = "Allow Redis from bastion for management"
#   security_group_id        = aws_security_group.elasticache.id
# }

# ElastiCache는 Outbound 규칙 불필요
