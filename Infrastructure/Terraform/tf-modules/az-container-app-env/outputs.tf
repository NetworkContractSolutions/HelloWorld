output "app_container_env_name" {
  description = "The name of the Container App Environment"
  value       = azurerm_container_app_environment.container_app_env.name
}

output "app_container_env_id" {
  description = "The ID of the Container App Environment"
  value       = azurerm_container_app_environment.container_app_env.id
}

output "app_container_default_domain" {
  description = "The default domain of the Container App Environment"
  value       = azurerm_container_app_environment.container_app_env.default_domain
}
