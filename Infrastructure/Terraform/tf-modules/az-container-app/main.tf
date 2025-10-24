resource "azurerm_container_app" "container_app" {
  name                         = var.container_app_name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.container_app_environment_id
  revision_mode                = var.revision_mode

  ingress {
    external_enabled = var.ingress_external_enabled
    target_port      = var.target_port
    transport        = var.ingress_transport
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  registry {
    server               = var.container_registry_login_server
    username             = var.container_registry_username
    password_secret_name = "registry-password"
  }

  secret {
    name  = "registry-password"
    value = var.container_registry_password
  }

  template {
    container {
      name   = var.container_app_name
      image  = var.container_image
      cpu    = var.container_cpu
      memory = var.container_memory
    }
    max_replicas = var.max_replicas
    min_replicas = var.min_replicas
  }
}
