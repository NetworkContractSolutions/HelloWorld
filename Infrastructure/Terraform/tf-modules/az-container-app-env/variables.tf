variable "name" {
  description = "The name of the Container App Environment."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group in which to create the Container App Environment."
  type        = string
}

variable "location" {
  description = "The Azure location where the Container App Environment should be created."
  type        = string
}

variable "zone_redundancy_enabled" {
  description = "Specifies whether zone redundancy is enabled for the Container App Environment."
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of tags to assign to the Container App Environment."
  type        = map(string)
}

variable "managed_identity_id" {
  description = "The ID of the User Assigned Managed Identity to be used by the Container App Environment."
  type        = string
}

variable "log_analytics_customer_id" {
  description = "The Customer ID of the Log Analytics workspace for app logs."
  type        = string
}

variable "log_analytics_shared_key" {
  description = "The Shared Key of the Log Analytics workspace for app logs."
  type        = string
}

variable "vnet_conf_internal" {
  description = "Specifies whether the Container App Environment is internal to a VNet."
  type        = bool
  default     = false
}

variable "vnet_infra_subnet_id" {
  description = "The ID of the subnet to be used for the Container App Environment's infrastructure."
  type        = string
}

variable "workload_profile_type" {
  description = "The type of workload profile for the Container App Environment."
  type        = string
  default     = "Consumption"
}

variable "workload_profile_name" {
  description = "The name of the workload profile for the Container App Environment."
  type        = string
  default     = "ConsumptionProfile"
}
