# modules/ec2/locals.tf
# EC2 모듈 로컬 변수

locals {
  # 공통 태그
  common_tags = merge(
    var.tags,
    {
      Module = "ec2"
    }
  )

  # Worker Node Subnet 배치 (AZ 분산)
  worker_node_subnets = [
    var.private_subnet_a_id, # Worker 1 → AZ-A
    var.private_subnet_b_id, # Worker 2 → AZ-B
  ]

  # Worker Node 이름
  worker_node_names = [
    for i in range(var.worker_node_count) :
    "k8s-worker-${i + 1}"
  ]

  # Worker Node AZ 라벨
  worker_node_azs = [
    "a", # Worker 1
    "b", # Worker 2
  ]
}
