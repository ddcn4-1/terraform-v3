# Helm Releases for EKS Add-ons
# This file deploys essential Kubernetes add-ons using Helm

# AWS Load Balancer Controller
# Required for managing ALB/NLB through Kubernetes Ingress and Service resources
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.6.2" # Check for latest version
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.aws_load_balancer_controller_irsa_role.iam_role_arn
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  # Enable Shield, WAF, and other features
  set {
    name  = "enableShield"
    value = "false"
  }

  set {
    name  = "enableWaf"
    value = "false"
  }

  set {
    name  = "enableWafv2"
    value = "false"
  }

  depends_on = [
    module.eks,
    module.aws_load_balancer_controller_irsa_role
  ]
}

# Metrics Server
# Required for Horizontal Pod Autoscaler (HPA) and kubectl top commands
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.11.0" # Check for latest version
  namespace  = "kube-system"

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  set {
    name  = "args[1]"
    value = "--kubelet-preferred-address-types=InternalIP"
  }

  depends_on = [
    module.eks
  ]
}

# Cluster Autoscaler (optional, for automatic node scaling)
# Uncomment if you want automatic node scaling based on pod resource requests
# resource "helm_release" "cluster_autoscaler" {
#   name       = "cluster-autoscaler"
#   repository = "https://kubernetes.github.io/autoscaler"
#   chart      = "cluster-autoscaler"
#   version    = "9.29.3"
#   namespace  = "kube-system"
#
#   set {
#     name  = "autoDiscovery.clusterName"
#     value = module.eks.cluster_name
#   }
#
#   set {
#     name  = "awsRegion"
#     value = var.aws_region
#   }
#
#   set {
#     name  = "rbac.serviceAccount.create"
#     value = "true"
#   }
#
#   set {
#     name  = "rbac.serviceAccount.name"
#     value = "cluster-autoscaler"
#   }
#
#   set {
#     name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#     value = module.cluster_autoscaler_irsa_role.iam_role_arn
#   }
#
#   depends_on = [
#     module.eks
#   ]
# }

# External Secrets Operator (optional, for syncing AWS Secrets Manager to Kubernetes)
# Uncomment if you want to sync AWS Secrets Manager secrets to Kubernetes secrets
# resource "helm_release" "external_secrets" {
#   name       = "external-secrets"
#   repository = "https://charts.external-secrets.io"
#   chart      = "external-secrets"
#   version    = "0.9.9"
#   namespace  = "external-secrets-system"
#   create_namespace = true
#
#   depends_on = [
#     module.eks
#   ]
# }

# Prometheus & Grafana (from existing mini-msa/helm/mini-msa/charts/)
# Note: These are already prepared in your charts/ directory
# You can deploy them separately using:
#   helm install prometheus ./mini-msa/helm/mini-msa/charts/kube-prometheus-stack-54.2.2.tgz
#   helm install elasticsearch ./mini-msa/helm/mini-msa/charts/eck-operator-2.15.0.tgz
#   helm install kubernetes-dashboard ./mini-msa/helm/mini-msa/charts/kubernetes-dashboard-7.14.0.tgz

# Example: Deploy mini-msa application via Helm (optional)
# Uncomment if you want Terraform to deploy your application charts
# resource "helm_release" "mini_msa" {
#   name       = "mini-msa"
#   chart      = "../mini-msa/helm/mini-msa"
#   namespace  = "default"
#
#   values = [
#     templatefile("${path.module}/../mini-msa/helm/mini-msa/values.yaml", {
#       environment = var.environment
#       db_host     = aws_db_instance.postgres.address
#       redis_host  = aws_elasticache_cluster.redis.cache_nodes[0].address
#     })
#   ]
#
#   depends_on = [
#     module.eks,
#     kubernetes_secret.application_config,
#     helm_release.aws_load_balancer_controller
#   ]
# }
