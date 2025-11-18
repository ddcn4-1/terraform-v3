# EKS Cluster Configuration
# Reference: https://github.com/terraform-aws-modules/terraform-aws-eks
# This module creates:
# - EKS Control Plane
# - Managed Node Groups
# - IRSA (IAM Roles for Service Accounts)
# - EKS Add-ons

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.project_name}-cluster"
  cluster_version = var.kubernetes_version

  # Cluster endpoint access configuration
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  # Control plane logging
  cluster_enabled_log_types = var.cluster_enabled_log_types

  # VPC and Networking
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Control plane subnet IDs (optional, defaults to subnet_ids if not specified)
  control_plane_subnet_ids = module.vpc.private_subnets

  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # Cluster add-ons (managed by EKS)
  cluster_addons = {
    # CoreDNS for DNS resolution
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        tolerations = [
          {
            key    = "CriticalAddonsOnly"
            effect = "NoSchedule"
          }
        ]
      })
    }

    # VPC CNI for pod networking
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        env = {
          # Enable prefix delegation for more IPs per node
          ENABLE_PREFIX_DELEGATION = "true"
          # Warm prefix target
          WARM_PREFIX_TARGET = "1"
        }
      })
    }

    # kube-proxy for service networking
    kube-proxy = {
      most_recent = true
    }

    # EBS CSI Driver for persistent volumes
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_driver_irsa_role.iam_role_arn
    }

    # Pod Identity Agent (for IRSA)
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  # EKS Managed Node Group
  eks_managed_node_groups = {
    main = {
      name            = "${var.project_name}-node-group"
      use_name_prefix = true

      # Scaling configuration
      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      # Instance configuration
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type

      # Disk configuration
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = var.node_disk_size
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      # Network configuration
      subnet_ids = module.vpc.private_subnets

      # Additional security groups
      vpc_security_group_ids = [
        aws_security_group.eks_worker_additional.id
      ]

      # Kubernetes labels
      labels = {
        Environment = var.environment
        NodeGroup   = "main"
        Project     = var.project_name
      }

      # Kubernetes taints (none for general purpose nodes)
      taints = []

      # Update configuration
      update_config = {
        max_unavailable_percentage = 50
      }

      # User data (bootstrap script)
      # pre_bootstrap_user_data = <<-EOT
      #   #!/bin/bash
      #   # Add custom initialization here
      #   echo "Node initialization started"
      # EOT

      # IAM role permissions
      iam_role_additional_policies = {
        # Allow SSM access for debugging
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        # Allow CloudWatch logging
        CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      }

      # Metadata options (IMDSv2)
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
        instance_metadata_tags      = "enabled"
      }

      # Enable monitoring
      enable_monitoring = true

      # Tags
      tags = {
        Name            = "${var.project_name}-node-group"
        NodeGroupType   = "managed"
        "karpenter.sh/discovery" = "${var.project_name}-cluster"
      }
    }
  }

  # Cluster security group rules
  cluster_security_group_additional_rules = {
    # Allow nodes to communicate with cluster API
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes to cluster API"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  # Node security group rules
  node_security_group_additional_rules = {
    # Allow nodes to communicate with each other
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }

    # Allow nodes to receive communication from cluster control plane
    ingress_cluster_all = {
      description                   = "Cluster to node all ports/protocols"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }

    # Allow nodes to send communication to cluster control plane
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  # Access entries (replaces aws-auth ConfigMap in newer versions)
  # This grants cluster administrator access to the IAM role/user running Terraform
  enable_cluster_creator_admin_permissions = true

  # Encryption configuration
  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = null # Uses default EKS managed key. Replace with custom KMS key ARN if needed
  }

  # Tags for all resources
  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-eks"
      Environment = var.environment
      GithubRepo  = "terraform-v3"
    }
  )
}

# KMS Key for EKS secret encryption (optional, currently using default)
# Uncomment if you want to use a custom KMS key
# resource "aws_kms_key" "eks" {
#   description             = "EKS Secret Encryption Key"
#   deletion_window_in_days = 7
#   enable_key_rotation     = true
#
#   tags = {
#     Name        = "${var.project_name}-eks-encryption"
#     Environment = var.environment
#   }
# }
#
# resource "aws_kms_alias" "eks" {
#   name          = "alias/${var.project_name}-eks"
#   target_key_id = aws_kms_key.eks.key_id
# }
