# Private Hosted Zone Module
# DNS abstraction for RDS and ElastiCache endpoints
# Enables seamless DR failover without application changes

# ============================================================================
# Private Hosted Zone
# ============================================================================
resource "aws_route53_zone" "private" {
  name = var.domain_name

  vpc {
    vpc_id = var.vpc_id
  }

  comment = "Private hosted zone for ${var.project_name} - ${var.environment}"

  tags = {
    Name        = "${var.project_name}-phz"
    Environment = var.environment
  }

  lifecycle {
    ignore_changes = [vpc]
  }
}

# ============================================================================
# RDS DNS Record
# ============================================================================
resource "aws_route53_record" "rds" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "db.${var.domain_name}"
  type    = "CNAME"
  ttl     = var.dns_ttl

  # RDS endpoint format: instance-id.xxxxxx.region.rds.amazonaws.com:port
  # Extract hostname without port
  records = [split(":", var.rds_endpoint)[0]]
}

# ============================================================================
# ElastiCache DNS Record
# ============================================================================
resource "aws_route53_record" "redis" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "redis.${var.domain_name}"
  type    = "CNAME"
  ttl     = var.dns_ttl

  records = [var.redis_endpoint]
}

# ============================================================================
# Additional Service Records (Optional)
# ============================================================================
resource "aws_route53_record" "custom" {
  for_each = var.custom_records

  zone_id = aws_route53_zone.private.zone_id
  name    = "${each.key}.${var.domain_name}"
  type    = each.value.type
  ttl     = each.value.ttl != null ? each.value.ttl : var.dns_ttl

  records = each.value.records
}
