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
  resource_group_name = lower(join("-", ["rg", local.project_name, module.naming.name, "00"]))
  location            = var.location
  tags                = local.tags
}

module "container_app_env" {
  source                 = "./tf-modules/az-container-app-env"
  container_app_env_name = lower(join("-", ["cappenv", local.project_name, module.naming.name, "00"]))
  resource_group_name    = module.resource_group.resource_group_name
  location               = module.resource_group.location
  tags                   = local.tags
}

module "container_app" {
  source                          = "./tf-modules/az-container-app"
  container_app_name              = lower(join("-", ["capp", local.project_name, module.naming.name, "00"]))
  resource_group_name             = module.resource_group.resource_group_name
  container_app_environment_id    = module.container_app_env.app_container_env_id
  revision_mode                   = var.revision_mode
  ingress_external_enabled        = var.ingress_external_enabled
  target_port                     = var.target_port
  ingress_transport               = var.ingress_transport
  container_registry_login_server = var.container_registry_login_server
  container_registry_username     = var.container_registry_username
  container_registry_password     = var.container_registry_password
  container_image                 = var.container_image
  container_cpu                   = var.container_cpu
  container_memory                = var.container_memory
  min_replicas                    = var.min_replicas
  max_replicas                    = var.max_replicas
}
