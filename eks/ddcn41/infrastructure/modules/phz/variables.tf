# PHZ Module Variables

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., prod, staging)"
  type        = string
}

variable "domain_name" {
  description = "Private hosted zone domain name (e.g., ticket-hs.internal)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to associate with the private hosted zone"
  type        = string
}

variable "rds_endpoint" {
  description = "RDS endpoint (hostname:port format)"
  type        = string
  default     = ""
}

variable "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  type        = string
  default     = ""
}

variable "dns_ttl" {
  description = "Default TTL for DNS records (seconds)"
  type        = number
  default     = 300  # 5 minutes - balance between caching and failover speed
}

variable "custom_records" {
  description = "Additional custom DNS records"
  type = map(object({
    type    = string
    records = list(string)
    ttl     = optional(number)
  }))
  default = {}
}
