output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "ALB zone ID"
  value       = aws_lb.main.zone_id
}

output "api_target_group_arn" {
  description = "API target group ARN"
  value       = aws_lb_target_group.api.arn
}

output "queue_target_group_arn" {
  description = "Queue target group ARN"
  value       = aws_lb_target_group.queue.arn
}

output "admin_target_group_arn" {
  description = "Admin target group ARN"
  value       = aws_lb_target_group.admin.arn
}
