# ============================================================================
# TERRAFORM OUTPUTS
# ============================================================================
# These outputs are available after deployment for use in pipelines or locally

output "container_app_name" {
  description = "Name of the deployed Container App"
  value       = azurerm_container_app.app.name
}

output "container_app_fqdn" {
  description = "Fully Qualified Domain Name (FQDN) of the Container App"
  value       = azurerm_container_app.app.ingress[0].fqdn
}

output "container_app_url" {
  description = "Full HTTPS URL to access the Container App"
  value       = "https://${azurerm_container_app.app.ingress[0].fqdn}"
}

output "resource_group_name" {
  description = "Resource Group where the Container App is deployed"
  value       = azurerm_container_app.app.resource_group_name
}

output "container_app_environment_id" {
  description = "ID of the Container App Environment"
  value       = azurerm_container_app.app.container_app_environment_id
}
