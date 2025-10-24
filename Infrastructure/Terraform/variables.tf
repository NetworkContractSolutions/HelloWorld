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

variable "revision_mode" {
  description = "The revision mode for the container app"
  type        = string
  default     = "Single"
}

variable "ingress_external_enabled" {
  description = "Enable external ingress for the container app"
  type        = bool
  default     = true
}

variable "target_port" {
  description = "The target port for the container app ingress"
  type        = number
  default     = 80
}

variable "ingress_transport" {
  description = "The transport protocol for the container app ingress"
  type        = string
  default     = "auto"
}

variable "container_registry_login_server" {
  description = "The login server of the container registry"
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

variable "container_cpu" {
  description = "The CPU allocation for the container"
  type        = string
  default     = "0.5"
}

variable "container_memory" {
  description = "The memory allocation for the container"
  type        = string
  default     = "1.0Gi"
}

variable "min_replicas" {
  description = "The minimum number of replicas for the container app"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "The maximum number of replicas for the container app"
  type        = number
  default     = 10
}
