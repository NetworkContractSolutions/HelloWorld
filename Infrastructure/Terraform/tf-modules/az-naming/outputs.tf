output "name" {
  description = "Project name, Environment name, Location name, and Alteration name lowercased and splatted by dash"
  value       = null_resource.label.triggers.name
}

output "merged_name" {
  description = "Project name, Environment name, Location name, and Alteration name lowercased and merged by dashes"
  value       = null_resource.label.triggers.merged_name
}

output "short_name" {
  description = "Short version of lowercased Project name, Environment name, Location name, and Alteration name"
  value       = null_resource.label.triggers.short_name
}

output "function_name" {
  description = "Project name, Function name, Environment name, Location name, and Alteration name lowercased and splatted by dash"
  value       = null_resource.label.triggers.function_name
}

output "merged_function_name" {
  description = "Project name, Function name, Environment name, Location name, and Alteration name lowercased and merged by dashes"
  value       = null_resource.label.triggers.merged_function_name
}

output "short_function_name" {
  description = "Short and lowercased version of Project name, Function name, Environment name, Location name, and Alteration name"
  value       = null_resource.label.triggers.short_function_name
}

output "environment" {
  description = "Lowercased environmen name"
  value       = null_resource.label.triggers.environment
}

output "short_environment" {
  description = "Short and lowercased version of the environment name"
  value       = null_resource.short_label.triggers.short_environment
}

output "function" {
  description = "Lowercased function name"
  value       = null_resource.label.triggers.function
}

output "alteration" {
  description = "Lowercased alteration"
  value       = null_resource.label.triggers.alteration
}

output "location" {
  description = "Lowercased Azure location"
  value       = null_resource.label.triggers.location
}

output "short_location" {
  description = "Short and lowercased Azure region"
  value       = null_resource.short_label.triggers.short_location
}

# Merge input tags with the module defined tags
output "tags" {
  description = "A mapping of tags"
  value = merge(
    tomap({
      "Environment" = null_resource.label.triggers.environment
      "Location"    = null_resource.label.triggers.location
      "Function"    = null_resource.label.triggers.function
    }), var.tags
  )
}
