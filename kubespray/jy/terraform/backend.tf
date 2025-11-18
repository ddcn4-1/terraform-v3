# backend.tf
# 목적: Terraform State를 S3에 원격 저장 및 Lock 관리
# Best Practice: 팀 협업 및 State 유실 방지를 위한 필수 설정

terraform {
  backend "s3" {
    # State 파일 저장 위치
    bucket = "ddcn41-pjy-dev-terraform-state"
    key    = "phase3/terraform.tfstate"
    region = "ap-northeast-2"

    # S3 자체 잠금 기능 활성화
    use_lockfile = true

    # 버저닝으로 State 히스토리 관리
    # S3 버킷에서 버저닝 활성화 필요
  }
}
