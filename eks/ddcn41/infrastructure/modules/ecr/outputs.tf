# ============================================================================
# Repository Outputs
# ============================================================================
output "repository_urls" {
  description = "Map of repository names to their URLs"
  value       = { for k, v in aws_ecr_repository.main : k => v.repository_url }
}

output "repository_arns" {
  description = "Map of repository names to their ARNs"
  value       = { for k, v in aws_ecr_repository.main : k => v.arn }
}

output "repository_registry_id" {
  description = "Registry ID where repositories are created"
  value       = length(aws_ecr_repository.main) > 0 ? values(aws_ecr_repository.main)[0].registry_id : null
}

# ============================================================================
# Replication Outputs
# ============================================================================
output "replication_regions" {
  description = "List of regions where images are replicated"
  value       = var.enable_cross_region_replication ? var.replication_regions : []
}

output "replication_configuration_registry_id" {
  description = "Registry ID of the replication configuration"
  value       = var.enable_cross_region_replication ? aws_ecr_replication_configuration.main[0].registry_id : null
}

# ============================================================================
# Pull Through Cache Outputs
# ============================================================================
output "pull_through_cache_rules" {
  description = "Map of pull through cache prefixes to upstream registries"
  value = merge(
    var.enable_pull_through_cache ? { dockerhub = "registry-1.docker.io" } : {},
    var.enable_pull_through_cache && var.enable_quay_cache ? { quay = "quay.io" } : {},
    var.enable_pull_through_cache && var.enable_k8s_cache ? { k8s = "registry.k8s.io" } : {}
  )
}

# ============================================================================
# Helper Outputs for CI/CD
# ============================================================================
output "docker_login_command" {
  description = "AWS CLI command to login to ECR"
  value       = "aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
}

output "image_push_commands" {
  description = "Example commands to build and push images"
  value = {
    for k, v in aws_ecr_repository.main : k => {
      build = "docker build -t ${v.repository_url}:latest ."
      push  = "docker push ${v.repository_url}:latest"
    }
  }
}

data "aws_region" "current" {}
