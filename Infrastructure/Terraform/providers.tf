terraform {
  required_version = "~> 1.0"

  backend "azurerm" {
    resource_group_name  = "rg-dev-devops-usc"
    storage_account_name = "sadevterraformusc"
    container_name       = "hello-world"
    # key                  = "hello-world-tf.tfstate" # Configured dynamically in the pipeline
    use_azuread_auth     = true # Use Azure AD authentication
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  tenant_id                       = "b16e3dc1-415b-443d-93b8-26af8e95260b"
  subscription_id                 = "d6a5ade2-7332-44cf-8c76-e07f6a4fcd8a"
  resource_provider_registrations = "none"
  storage_use_azuread             = true # Enable Azure AD authentication for storage
  features {}
}
