output "resource_group_name" {
  description = "The name of the Resource Group"
  value       = azurerm_resource_group.resource_group.name
}

output "resource_group_id" {
  description = "The ID of the Resource Group"
  value       = azurerm_resource_group.resource_group.id
}

output "location" {
  description = "The location of the Resource Group"
  value       = azurerm_resource_group.resource_group.location
}

output "tags" {
  description = "The tags assigned to the Resource Group"
  value       = azurerm_resource_group.resource_group.tags
}
