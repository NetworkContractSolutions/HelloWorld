# ============================================================================
# DEPLOYMENT CONFIGURATION
# ============================================================================
# These variables control where and how your Container App is deployed.
# In Azure DevOps pipelines, these are passed via --var flags.

variable "environment" {
  description = "Environment name (e.g., poc01, dev, staging, prod)"
  type        = string
  default     = "poc01"
}

variable "location" {
  description = "Azure region for resource deployment"
  type        = string
  default     = "centralus"
}

# ============================================================================
# EXISTING INFRASTRUCTURE REFERENCES
# ============================================================================
# These reference pre-existing Azure resources that your Container App uses.

variable "existing_cae_resource_group_name" {
  description = "Name of existing Resource Group where Container App will be deployed"
  type        = string
  default     = "rg-poc01-usc"
}

variable "existing_container_app_environment_name" {
  description = "Name of existing Container App Environment (shared infrastructure)"
  type        = string
  default     = "cae-poc01-usc"
}

variable "managed_identity_name" {
  description = "Name of existing User-Assigned Managed Identity for ACR access"
  type        = string
  default     = "uami-poc01-usc"
}

variable "managed_identity_resource_group_name" {
  description = "Resource Group containing the Managed Identity"
  type        = string
  default     = "rg-poc01-usc"
}

# ============================================================================
# CONTAINER APP CONFIGURATION
# ============================================================================

variable "container_app_name" {
  description = "Name for the Container App (must be unique within the environment)"
  type        = string
  default     = "ca-helloworld-poc01-usc-001"
}

variable "target_port" {
  description = "Port number your container listens on (ASP.NET Core default: 8080)"
  type        = number
  default     = 8080
}

# ============================================================================
# CONTAINER REGISTRY & IMAGE
# ============================================================================

variable "container_registry_login_server" {
  description = "Azure Container Registry login server URL"
  type        = string
  default     = "ncontracts.azurecr.io"
}

variable "container_image" {
  description = "Full container image path including tag (e.g., myregistry.azurecr.io/helloworld:12345). REQUIRED - must be passed from pipeline with specific build tag."
  type        = string
  # No default - this variable is required to prevent accidental deployment of 'latest' tag
}
