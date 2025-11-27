# ============================================================================
# TERRAFORM & PROVIDER CONFIGURATION
# ============================================================================

terraform {
  required_version = "~> 1.0"

  # Remote state storage in Azure Blob Storage
  # The container_name and key are configured dynamically in the pipeline
  backend "azurerm" {
    resource_group_name  = "rg-dev-devops-usc"
    storage_account_name = "sadevterraformusc"
    use_azuread_auth     = true # Use Azure AD authentication (no access keys needed)
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Azure Resource Manager Provider
provider "azurerm" {
  # Your Azure subscription details
  subscription_id = "d6a5ade2-7332-44cf-8c76-e07f6a4fcd8a"
  tenant_id       = "b16e3dc1-415b-443d-93b8-26af8e95260b"

  # Don't auto-register resource providers (requires subscription owner permissions)
  # Ensure Microsoft.App is already registered in your subscription
  resource_provider_registrations = "none"

  # Use Azure AD authentication for storage operations (recommended over access keys)
  storage_use_azuread = true

  features {}
}
