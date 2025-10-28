resource "azurerm_container_app_environment" "default" {
  name                    = var.name
  resource_group_name     = var.resource_group_name
  location                = var.location
  zone_redundancy_enabled = var.zone_redundancy_enabled
  tags                    = var.tags

  identity {
    type        = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  app_logs_configuration {
    destination = "log-analytics"

    log_analytics_configuration {
      customer_id = var.log_analytics_customer_id
      shared_key  = var.log_analytics_shared_key
    }
  }

  vnet_configuration {
    internal                    = var.vnet_conf_internal
    infrastructure_subnet_id    = var.vnet_infra_subnet_id
    docker_bridge_cidr          = null
    platform_reserved_cidr      = null
    platform_reserved_dns_ip    = null
  }

  workload_profile {
    workload_profile_type = var.workload_profile_type
    name                  = var.workload_profile_name
  }
}
