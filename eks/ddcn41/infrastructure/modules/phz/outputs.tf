# PHZ Module Outputs

output "zone_id" {
  description = "Route53 Private Hosted Zone ID"
  value       = aws_route53_zone.private.zone_id
}

output "zone_name" {
  description = "Route53 Private Hosted Zone name"
  value       = aws_route53_zone.private.name
}

output "zone_arn" {
  description = "Route53 Private Hosted Zone ARN"
  value       = aws_route53_zone.private.arn
}

output "name_servers" {
  description = "Name servers for the hosted zone"
  value       = aws_route53_zone.private.name_servers
}

# DNS endpoints for application configuration
output "rds_dns" {
  description = "RDS DNS endpoint (db.{domain})"
  value       = "db.${var.domain_name}"
}

output "redis_dns" {
  description = "Redis DNS endpoint (redis.{domain})"
  value       = "redis.${var.domain_name}"
}

# Record IDs for Ansible DR automation
output "rds_record_id" {
  description = "RDS Route53 record ID for DR updates"
  value       = aws_route53_record.rds.id
}

output "redis_record_id" {
  description = "Redis Route53 record ID for DR updates"
  value       = aws_route53_record.redis.id
}

# Full record names for AWS CLI updates
output "rds_record_name" {
  description = "Full RDS record name for AWS CLI"
  value       = "db.${var.domain_name}"
}

output "redis_record_name" {
  description = "Full Redis record name for AWS CLI"
  value       = "redis.${var.domain_name}"
}
