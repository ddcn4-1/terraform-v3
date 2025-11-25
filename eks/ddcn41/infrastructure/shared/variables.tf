variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "ticketing"
}

variable "environment" {
  description = "Environment name"
  type        = string
}
