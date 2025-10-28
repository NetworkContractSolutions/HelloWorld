variable "container_app_name" {
  description = "The name of the Container App."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the Resource Group in which to create the Container App."
  type        = string
}

variable "container_app_environment_id" {
  description = "The ID of the Container App Environment in which to create the Container App."
  type        = string
}

variable "revision_mode" {
  description = "The revision mode of the Container App. Possible values are 'Single' or 'Multiple'."
  type        = string
  default     = "Single"
}

variable "ingress_external_enabled" {
  description = "Whether to enable external ingress for the Container App."
  type        = bool
  default     = true
}

variable "target_port" {
  description = "The target port for the Container App ingress."
  type        = number
  default     = 80
}

variable "ingress_transport" {
  description = "The transport protocol for the Container App ingress. Possible values are 'auto', 'http', or 'https'."
  type        = string
  default     = "auto"
}

variable "container_registry_login_server" {
  description = "The login server of the Container Registry."
  type        = string
}

variable "container_registry_username" {
  description = "The username for the Container Registry."
  type        = string
}

variable "container_registry_password" {
  description = "The password for the Container Registry."
  type        = string
  sensitive   = true
}

variable "container_image" {
  description = "The container image to deploy in the Container App."
  type        = string
}

variable "container_cpu" {
  description = "The CPU allocation for the container in vCPU."
  type        = number
  default     = 0.5
}

variable "container_memory" {
  description = "The memory allocation for the container."
  type        = string
  default     = "1Gi"
}

variable "min_replicas" {
  description = "The minimum number of replicas for the Container App."
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "The maximum number of replicas for the Container App."
  type        = number
  default     = 10
}
