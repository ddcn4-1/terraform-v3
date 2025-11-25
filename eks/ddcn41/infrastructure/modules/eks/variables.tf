variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes"
  type        = list(string)
}

variable "node_security_group_id" {
  description = "Security group ID for EKS nodes"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "node_instance_type" {
  description = "EKS node instance type"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "EKS node desired size"
  type        = number
  default     = 1
}

variable "node_min_size" {
  description = "EKS node min size"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "EKS node max size"
  type        = number
  default     = 3
}

# ============================================================================
# IAM Role Configuration (for multi-region deployments)
# ============================================================================
variable "create_iam_roles" {
  description = "Whether to create IAM roles (set to false in DR region to reuse existing roles)"
  type        = bool
  default     = true
}

variable "existing_cluster_role_arn" {
  description = "ARN of existing EKS cluster IAM role (required when create_iam_roles is false)"
  type        = string
  default     = null
}

variable "existing_node_role_arn" {
  description = "ARN of existing EKS node IAM role (required when create_iam_roles is false)"
  type        = string
  default     = null
}
