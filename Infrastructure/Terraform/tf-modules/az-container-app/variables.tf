variable "container_app_name" {
  description = "The name of the Container App"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the Resource Group"
  type        = string
}

variable "container_app_environment_id" {
  description = "The ID of the Container App Environment"
  type        = string
}

variable "revision_mode" {
  description = "The revision mode for the Container App"
  type        = string
  default     = "Single"
}

variable "ingress_external_enabled" {
  description = "Enable external ingress for the Container App"
  type        = bool
  default     = true
}

variable "target_port" {
  description = "The target port for the Container App"
  type        = number
  default     = 80
}

variable "ingress_transport" {
  description = "The transport protocol for the ingress"
  type        = string
  default     = "auto"
}

variable "user_assigned_identity_id" {
  description = "The ID of the user-assigned managed identity"
  type        = string
}

variable "container_registry_login_server" {
  description = "The login server for the container registry"
  type        = string
}

variable "container_image" {
  description = "The container image"
  type        = string
}

variable "container_cpu" {
  description = "The CPU limit for the container"
  type        = number
  default     = 0.5
}

variable "container_memory" {
  description = "The memory limit for the container"
  type        = string
  default     = "1Gi"
}

variable "max_replicas" {
  description = "The maximum number of replicas for the container"
  type        = number
  default     = 10
}

variable "min_replicas" {
  description = "The minimum number of replicas for the container"
  type        = number
  default     = 1
}
