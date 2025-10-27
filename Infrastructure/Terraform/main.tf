# Module to create a naming convention for Azure resources
module "naming" {
  source      = "./tf-modules/az-naming"
  environment = var.environment
  location    = var.location
  function    = local.project_name
  tags        = local.tags
}

module "resource_group" {
  source              = "./tf-modules/az-resource-group"
  resource_group_name = lower(join("-", ["rg", module.naming.function_name, "00"]))
  location            = var.location
  tags                = local.tags
}

module "container_app_env" {
  source                 = "./tf-modules/az-container-app-env"
  container_app_env_name = lower(join("-", ["cappenv", module.naming.function_name, "00"]))
  resource_group_name    = module.resource_group.resource_group_name
  location               = module.resource_group.location
  tags                   = module.resource_group.tags
}

module "container_app" {
  source                          = "./tf-modules/az-container-app"
  container_app_name              = lower(join("-", ["capp", module.naming.function_name, "00"]))
  resource_group_name             = module.resource_group.resource_group_name
  container_app_environment_id    = module.container_app_env.app_container_env_id
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
