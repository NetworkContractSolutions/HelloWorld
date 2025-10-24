output "name" {
  description = "The name of the container registry"
  value       = azurerm_container_registry.acr.name
}

output "login_server" {
  description = "The login server of the container registry"
  value       = azurerm_container_registry.acr.login_server
}
