# Module to create a naming convention for Azure resources
module "naming" {
  source      = "./tf-modules/az-naming"
  environment = var.environment
  location    = var.location
  function    = local.project_name
  tags        = local.tags
}

data "azurerm_resource_group" "cae_rg" {
  name = var.existing_resource_group_name
}

data "azurerm_container_app_environment" "cae_env" {
  name                = var.existing_container_app_environment_name
  resource_group_name = data.azurerm_resource_group.cae_rg.name
}

data "azurerm_user_assigned_identity" "uami" {
  name                = var.managed_identity_name
  resource_group_name = var.managed_identity_resource_group_name
}

module "container_app" {
  source                          = "./tf-modules/az-container-app"
  container_app_name              = var.ca_name
  resource_group_name             = data.azurerm_resource_group.cae_rg.name
  container_app_environment_id    = data.azurerm_container_app_environment.cae_env.id
  revision_mode                   = "Single"
  ingress_external_enabled        = true
  target_port                     = 8080 # Default port for ASP.NET apps
  ingress_transport               = "auto"
  container_registry_login_server = var.container_registry_login_server
  user_assigned_identity_id       = data.azurerm_user_assigned_identity.uami.id
  container_image                 = var.container_image
  container_cpu                   = "0.5"
  container_memory                = "1.0Gi"
  min_replicas                    = 1
  max_replicas                    = 10
}
