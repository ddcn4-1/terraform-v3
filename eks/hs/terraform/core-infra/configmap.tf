# ConfigMap for non-sensitive application configuration
resource "kubernetes_config_map" "application_config" {
  metadata {
    name      = "${var.project_name}-application-config"
    namespace = "default"

    labels = {
      app         = "mini-msa"
      environment = var.environment
      managed-by  = "terraform"
    }
  }

  data = {
    # Non-sensitive configuration
    AWS_REGION         = var.aws_region
    ENVIRONMENT        = var.environment
    CORE_SERVICE_PORT  = tostring(var.core_service_port)
    QUEUE_SERVICE_PORT = tostring(var.queue_service_port)

    # Database connection settings (without credentials)
    DB_MAX_CONNECTIONS = "20"
    DB_POOL_TIMEOUT    = "30"

    # Redis connection settings (without credentials)
    REDIS_MAX_RETRIES     = "3"
    REDIS_CONNECT_TIMEOUT = "5000"

    # Application settings
    LOG_LEVEL = "info"
  }

  depends_on = [
    module.eks
  ]
}
