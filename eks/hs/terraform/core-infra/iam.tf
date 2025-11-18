# IAM Roles and Policies for EKS
# The EKS module creates most IAM resources automatically,
# but we define additional policies here for specific use cases

# IAM Role for AWS Load Balancer Controller
# This allows the controller to manage ALB/NLB resources
module "aws_load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.project_name}-aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = {
    Name        = "${var.project_name}-aws-load-balancer-controller"
    Environment = var.environment
  }
}

# IAM Role for EBS CSI Driver
# This allows the CSI driver to manage EBS volumes for persistent storage
module "ebs_csi_driver_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.project_name}-ebs-csi-driver"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = {
    Name        = "${var.project_name}-ebs-csi-driver"
    Environment = var.environment
  }
}

# IAM Role for External DNS (optional, for Route53 integration)
# Uncomment if you need to manage DNS records automatically
# module "external_dns_irsa_role" {
#   source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
#   version = "~> 5.0"
#
#   role_name = "${var.project_name}-external-dns"
#
#   attach_external_dns_policy = true
#
#   oidc_providers = {
#     main = {
#       provider_arn               = module.eks.oidc_provider_arn
#       namespace_service_accounts = ["kube-system:external-dns"]
#     }
#   }
#
#   tags = {
#     Name        = "${var.project_name}-external-dns"
#     Environment = var.environment
#   }
# }

# IAM Policy for Application Pods (example for accessing S3, RDS, etc.)
# This is a custom policy that can be attached to application service accounts
resource "aws_iam_policy" "application_policy" {
  name_prefix = "${var.project_name}-app-"
  description = "IAM policy for mini-msa application pods"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*",
          "arn:aws:s3:::${var.project_name}-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = [
          "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-app-policy"
    Environment = var.environment
  }
}

# IAM Role for Application Service Accounts
# This role can be used by application pods via IRSA (IAM Roles for Service Accounts)
module "application_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.project_name}-application"

  role_policy_arns = {
    policy = aws_iam_policy.application_policy.arn
  }

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "default:core-service",
        "default:queue-service"
      ]
    }
  }

  tags = {
    Name        = "${var.project_name}-application"
    Environment = var.environment
  }
}

# Additional IAM policy for node group to access ECR
# This is automatically handled by the EKS module, but shown here for reference
# The EKS module attaches these managed policies to node groups:
# - AmazonEKSWorkerNodePolicy
# - AmazonEKS_CNI_Policy
# - AmazonEC2ContainerRegistryReadOnly
# - AmazonSSMManagedInstanceCore (for Session Manager access)
