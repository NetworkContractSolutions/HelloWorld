variable "container_app_name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "container_app_environment_id" {
  type = string
}

variable "revision_mode" {
  type    = string
  default = "Single"
}

variable "ingress_external_enabled" {
  type    = bool
  default = true
}

variable "target_port" {
  type    = number
  default = 80
}

variable "ingress_transport" {
  type    = string
  default = "auto"
}

variable "container_registry_login_server" {
  type = string
}

variable "container_registry_username" {
  type = string
}

variable "container_registry_password" {
  type      = string
  sensitive = true
}

variable "container_image" {
  type = string
}

variable "container_cpu" {
  type    = number
  default = 0.5
}

variable "container_memory" {
  type    = string
  default = "1Gi"
}

variable "min_replicas" {
  type    = number
  default = 1
}

variable "max_replicas" {
  type    = number
  default = 10
}
