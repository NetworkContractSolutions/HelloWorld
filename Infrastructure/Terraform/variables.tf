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

variable "existing_resource_group_name" {
  description = "The name of an existing resource group to use"
  type        = string
  default     = "rg-poc01-usc"
}

variable "existing_container_app_environment_name" {
  description = "The name of an existing Container App Environment to use"
  type        = string
  default     = "cae-poc01-usc"
}

########################################
### Container App specific variables ###
########################################

variable "container_registry_login_server" {
  description = "The login server for the container registry"
  type        = string
  default     = "ncontracts.azurecr.io"
}

variable "container_registry_username" {
  description = "The username for the container registry"
  type        = string
  sensitive   = true
}

variable "container_registry_password" {
  description = "The password for the container registry"
  type        = string
  sensitive   = true
}

variable "container_image" {
  description = "The container image to deploy"
  type        = string
  default     = "ncontracts.azurecr.io/helloworld:latest"
}
