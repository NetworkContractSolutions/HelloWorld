#####################
#### Local values ###
#####################

locals {
  project_name = "helloworld"

  tags = {
    "Project"     = local.project_name
    "Environment" = var.environment
    "Location"    = var.location
    "IaCTool"     = "Terraform"
    "CostCenter"  = "Engineering"
    "Owner"       = "Infrastructure Team"
  }
}

###################################
### Global variable definitions ###
###################################

variable "environment" {
  description = "The environment for the resources (e.g., dev, prod)"
  type        = string
  default     = "poc01"
}

variable "location" {
  description = "The Azure region where resources will be deployed"
  type        = string
  default     = "centralus"
}

########################################
### Container App specific variables ###
########################################

variable "ca_name" {
  description = "The name of the Container App"
  type        = string
  default     = "ca-helloworld-poc01-usc-001"
}

variable "existing_resource_group_name" {
  description = "The name of the existing resource group"
  type        = string
  default     = "rg-poc01-usc"
}

variable "existing_container_app_environment_name" {
  description = "The name of the existing Container App Environment"
  type        = string
  default     = "cae-poc01-usc"
}

variable "managed_identity_name" {
  description = "The name of the user-assigned managed identity"
  type        = string
  default     = "uami-poc01-usc"
}

variable "managed_identity_resource_group_name" {
  description = "The resource group name where the managed identity is located"
  type        = string
  default     = "rg-poc01-usc"
}

variable "container_registry_login_server" {
  description = "The login server URL for the container registry"
  type        = string
  default     = "ncontracts.azurecr.io"
}

variable "container_image" {
  description = "The name of the container image to deploy"
  type        = string
  default     = "ncontracts.azurecr.io/helloworld:latest"
}
