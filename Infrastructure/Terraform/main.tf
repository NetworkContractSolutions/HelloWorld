# Module to create a naming convention for Azure resources
module "naming" {
  source      = "./tf-modules/az-naming"
  environment = var.environment
  location    = var.location
  function    = local.project_name
  tags        = local.tags
}

data "azurerm_resource_group" "default" {
  name = var.existing_resource_group_name
}

data "azurerm_container_app_environment" "default" {
  name                = var.existing_container_app_environment_name
  resource_group_name = data.azurerm_resource_group.default.name
}

module "container_app" {
  source                          = "./tf-modules/az-container-app"
  container_app_name              = lower(join("-", ["ca", module.naming.function_name, "00"]))
  resource_group_name             = data.azurerm_resource_group.default.name
  container_app_environment_id    = data.azurerm_container_app_environment.default.id
  revision_mode                   = "Single"
  ingress_external_enabled        = true
  target_port                     = 80
  ingress_transport               = "auto"
  container_registry_login_server = var.container_registry_login_server
  container_registry_username     = var.container_registry_username
  container_registry_password     = var.container_registry_password
  container_image                 = var.container_image
  container_cpu                   = "0.5"
  container_memory                = "1.0Gi"
  min_replicas                    = 1
  max_replicas                    = 10
}
