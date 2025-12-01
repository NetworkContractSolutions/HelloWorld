# Reference existing Resource Group where Container App will be deployed
data "azurerm_resource_group" "rg" {
  name = var.existing_cae_resource_group_name
}

# Reference existing Container App Environment (shared infrastructure)
data "azurerm_container_app_environment" "env" {
  name                = var.existing_container_app_environment_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Reference existing User-Assigned Managed Identity for ACR access
data "azurerm_user_assigned_identity" "acr_identity" {
  name                = var.managed_identity_name
  resource_group_name = var.managed_identity_resource_group_name
}

# Deploy Azure Container App
resource "azurerm_container_app" "app" {
  name                         = var.container_app_name
  resource_group_name          = data.azurerm_resource_group.rg.name
  container_app_environment_id = data.azurerm_container_app_environment.env.id
  revision_mode                = "Single"

  # Enable external ingress (public HTTPS endpoint)
  ingress {
    external_enabled = true
    target_port      = var.target_port
    transport        = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  # Use managed identity for Azure Container Registry authentication
  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.acr_identity.id]
  }

  registry {
    server   = var.container_registry_login_server
    identity = data.azurerm_user_assigned_identity.acr_identity.id
  }

  # Container configuration
  template {
    container {
      name   = var.container_app_name
      image  = var.container_image
      cpu    = "0.5"
      memory = "1Gi"
    }

    min_replicas = 0
    max_replicas = 1
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "HelloWorld"
  }
}
