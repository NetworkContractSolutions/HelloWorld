output "fqdn" {
  description = "The FQDN of the Container App"
  value       = azurerm_container_app.container_app.ingress[0].fqdn
}

output "container_app_url" {
  description = "The URL of the Container App"
  value       = "https://${azurerm_container_app.container_app.ingress[0].fqdn}"
}
