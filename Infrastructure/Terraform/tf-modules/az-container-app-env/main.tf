resource "azurerm_container_app_environment" "container_app_env" {
  name                = var.container_app_env_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}
