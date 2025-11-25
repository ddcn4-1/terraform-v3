# 환경 설정
environment = "dev"
project_name = "ticketing"

# 네트워크 설정 (VPC 모듈에서 실제 사용되는 변수들만)
vpc_cidr = "10.0.0.0/16"
availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]

# 서브넷 CIDR
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
database_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24"]
# Database 설정
db_password = "ticketing123!"
