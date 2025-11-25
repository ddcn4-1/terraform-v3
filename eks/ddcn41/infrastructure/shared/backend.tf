terraform {
  backend "s3" {
    bucket         = "ticketing-terraform-state-20241112"  # 위에서 생성한 버킷명
    key            = "terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
