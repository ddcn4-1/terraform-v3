# ConfigMap for non-sensitive application configuration
resource "kubernetes_config_map" "application_config" {
  metadata {
    name      = "${var.project_name}-application-config"
    namespace = "ddcn41"

    labels = {
      app         = "backend-v3"
      environment = var.environment
      managed-by  = "terraform"
    }
  }

  data = {
    # AWS Configuration
    AWS_REGION  = var.aws_region
    AWS_S3_BUCKET = "ddcn41v1-image"

    # Environment
    ENVIRONMENT        = var.environment
    SPRING_PROFILES_ACTIVE = var.environment == "dev" ? "dev" : "prod"

    # Server Ports
    CORE_SERVICE_PORT  = tostring(var.core_service_port)
    QUEUE_SERVICE_PORT = tostring(var.queue_service_port)

    # Database Connection Settings (without credentials)
    DATABASE_MAX_CONNECTIONS   = "20"
    DATABASE_CONNECTION_TIMEOUT = "30000"

    # Redis Connection Settings (without credentials)
    REDIS_TIMEOUT       = "5000"
    REDIS_MAX_RETRIES   = "3"

    # Cognito Settings (non-sensitive)
    COGNITO_REGION = var.aws_region

    # Application Settings
    LOG_LEVEL = "info"
  }

  depends_on = [
    module.eks
  ]
}
