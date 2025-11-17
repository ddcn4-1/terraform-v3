# modules/security-groups/locals.tf
# Security Groups 모듈 로컬 변수

locals {
  # 공통 태그
  common_tags = merge(
    var.tags,
    {
      Module = "security-groups"
    }
  )

  # Security Group 이름 생성 함수
  sg_name = {
    alb           = "${var.name_prefix}-alb-sg"
    bastion       = "${var.name_prefix}-bastion-sg"
    nat_instance  = "${var.name_prefix}-nat-instance-sg"
    control_plane = "${var.name_prefix}-control-plane-sg"
    worker_node   = "${var.name_prefix}-worker-node-sg"
    rds           = "${var.name_prefix}-rds-sg"
    elasticache   = "${var.name_prefix}-elasticache-sg"
  }

  # 모든 SSH 허용 CIDR (단일 + 리스트)
  all_ssh_cidrs = concat(
    [var.allowed_ssh_cidr],
    var.allowed_ssh_cidrs
  )

  # Kubernetes 필수 포트
  k8s_ports = {
    api_server      = 6443
    etcd_client     = 2379
    etcd_peer       = 2380
    kubelet         = 10250
    kube_scheduler  = 10251
    kube_controller = 10252
    node_port_from  = var.k8s_node_port_range.from
    node_port_to    = var.k8s_node_port_range.to
  }
}
