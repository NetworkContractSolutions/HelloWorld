# Region global variables

variable "function" {
  description = "Function name"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name -	example:prod/stage/dev/int"
  type        = string
}

variable "location" {
  description = "Location - example: eastus"
  type        = string
}

variable "location_list" {
  description = "Location list"
  type        = list(any)
  default = [
    "eastus",
    "westus",
    "centralus",
    "eastus2"
  ]
}

variable "alteration" {
  description = "Example of alteration: you spawn more than one environments in the same environment first alteration of the default deployment/environment = 01 second alteration of the deployment/environment = 02"
  type        = string
  default     = null
}

variable "delimiter" {
  description = "Delimiter to be used between `name`, etc."
  type        = string
  default     = "-"
}

variable "tags" {
  description = "Additional tags (e.g. `map('BusinessUnit`,`XYZ`)"
  type        = map(any)
  default     = {}
}

# Region specific variables

# Location list and its assertion. The short location set according to name conventions.
variable "short_location_names" {
  description = "Short location names"
  type        = map(any)
  default = {
    "eastus"    = "eus"
    "westus"    = "wus"
    "centralus" = "cus"
    "eastus2"   = "eus2"
  }
}

# Environment names list and its assertion. The short environment names set according to name conventions
variable "environment_list" {
  description = "Environment name"
  type        = list(any)
  default = [
    "dev",
    "devops",
    "nonprod",
    "prod",
    "sandbox",
    "hub",
    "poc01"
  ]
}

variable "short_environment_names" {
  description = "Short environment names"
  type        = map(any)
  default = {
    "dev"     = "dev"
    "devops"  = "ds"
    "nonprod" = "np"
    "prod"    = "prd"
    "sandbox" = "sbx"
    "hub"     = "hub"
    "poc01"   = "p01"
  }
}
