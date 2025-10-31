variable "name" {
  description = "The name of the resource group. Changing this forces a new resource to be created"
  type        = string
  default     = null
}

variable "location" {
  description = "The Azure Region where the Resource Group should exist. Changing this forces a new Resource Group to be created"
  type        = string
}

variable "tags" {
  description = "A mapping of tags which should be assigned to the Resource Group"
  type        = map(any)
  default     = {}
}
