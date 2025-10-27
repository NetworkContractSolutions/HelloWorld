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
  default     = "dev"
}

variable "location" {
  description = "The Azure region where resources will be deployed"
  type        = string
  default     = "centralus"
}

########################################
### Container App specific variables ###
########################################

variable "container_registry_login_server" {
  description = "The login server for the container registry"
  type        = string
  default     = "mcr.microsoft.com"
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
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}
