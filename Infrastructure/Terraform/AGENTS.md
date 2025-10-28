# AI Agent Guidelines for Terraform Infrastructure as Code

This document provides guidelines for AI agents working with Terraform infrastructure code in this project.

## General Terraform Best Practices

### Code Structure
- Use consistent naming conventions following the pattern: `<resource_type>-<function>-<environment>-<location>-<instance_number>`
- Organize code into modules for reusability (use `tf-modules/` directory)
- Keep root module files focused: `main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`
- Use `locals.tf` for computed values and transformations
- Separate environments using workspace or directory structure

### Variables and Outputs
- Always add descriptions to variables and outputs
- Use appropriate variable types (string, number, bool, list, map, object)
- Set sensible defaults where applicable
- Mark sensitive variables with `sensitive = true`
- Use validation blocks for input validation when possible

### Resource Naming
- Use descriptive resource names in code (e.g., `azurerm_resource_group.main`)
- Actual Azure resource names should follow organizational naming conventions
- Refer to `/Docs/NamingConventions.md` for Azure resource naming patterns

### State Management
- Never commit `.tfstate` files to version control
- Use remote state backends (Azure Storage Account recommended)
- Enable state locking to prevent concurrent modifications
- Use `terraform_remote_state` data source for cross-stack references

## Code Quality

### Formatting
- Always run `terraform fmt -recursive` before committing
- Use consistent indentation (2 spaces)
- Group related resources together
- Add comments for complex logic or non-obvious configurations

### Validation
- Run `terraform validate` to check syntax and configuration
- Use `terraform plan` to review changes before applying
- Implement variable validation blocks where appropriate

### Documentation
- Document module usage with README.md in each module directory
- Include examples of how to use modules
- Document required and optional variables
- Explain outputs and their purposes

## Security Best Practices

### Secrets Management
- **NEVER** hardcode secrets, passwords, or sensitive data
- Use Azure Key Vault for secret storage
- Reference secrets using `data "azurerm_key_vault_secret"`
- Mark sensitive outputs with `sensitive = true`
- Use `@secure()` decorator equivalent (sensitive variables)

### Access Control
- Implement least privilege principle for managed identities
- Use Azure RBAC for resource permissions
- Enable managed identities instead of service principals where possible
- Document required permissions in module README

### Network Security
- Default to private endpoints for PaaS services
- Use network security groups (NSGs) appropriately
- Implement proper subnet delegation
- Enable Azure Firewall or Network Virtual Appliances where needed

### Compliance
- Enable diagnostic settings and logging
- Use Azure Policy for governance
- Tag all resources appropriately (refer to `tags` variable)
- Enable encryption at rest and in transit

## Testing

### Manual Testing
- Always run `terraform plan` and review output carefully
- Test in development environment before production
- Verify resource creation in Azure Portal
- Check for drift using `terraform plan` against existing infrastructure

### Automated Testing
- Use `terraform validate` in CI/CD pipelines
- Implement `terraform fmt -check` in PR validation
- Consider using `tflint` for additional linting
- Use `checkov` or `tfsec` for security scanning

### Test Checklist
- [ ] Run `terraform fmt -recursive`
- [ ] Run `terraform validate`
- [ ] Run `terraform plan` and review changes
- [ ] Check for security issues (no hardcoded secrets)
- [ ] Verify naming conventions
- [ ] Ensure proper tagging
- [ ] Review IAM permissions and roles
- [ ] Confirm network configuration

## Migration from Bicep

When migrating from Bicep to Terraform:

1. **Understand the mapping**: Bicep and Terraform have different syntax but similar concepts
2. **Resource mapping**:
   - Bicep modules → Terraform modules
   - Bicep parameters → Terraform variables
   - Bicep outputs → Terraform outputs
3. **Conditional logic**: Bicep conditions translate to `count` or `for_each` in Terraform
4. **Dependencies**: Explicit `depends_on` may be needed where Bicep inferred them

## Common Patterns

### Creating Resources with For Each
```hcl
resource "azurerm_resource_group" "rg" {
  for_each = var.resource_groups
  
  name     = each.value.name
  location = each.value.location
  tags     = var.tags
}
```

### Conditional Resource Creation
```hcl
resource "azurerm_postgresql_server" "psql" {
  count = var.create_replica ? 1 : 0
  
  name                = var.server_name
  resource_group_name = var.resource_group_name
  # ... other properties
}
```

### Using Data Sources
```hcl
data "azurerm_key_vault" "kv" {
  name                = var.key_vault_name
  resource_group_name = var.key_vault_rg
}

data "azurerm_key_vault_secret" "secret" {
  name         = "database-password"
  key_vault_id = data.azurerm_key_vault.kv.id
}
```

## Module Development

### Module Structure
```
tf-modules/az-resource-name/
├── main.tf           # Primary resources
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── provider.tf       # Provider version constraints
└── README.md         # Module documentation
```

### Module Best Practices
- Keep modules focused on a single resource type or logical grouping
- Use semantic versioning for module releases
- Provide examples in module README
- Include variable validation
- Document all outputs
- Use lifecycle blocks when needed (prevent_destroy, ignore_changes)

## CI/CD Integration

### Pipeline Stages
1. **Validation**: `terraform fmt -check`, `terraform validate`
2. **Security Scan**: Run `tfsec` or `checkov`
3. **Plan**: Generate and review `terraform plan`
4. **Apply**: Execute `terraform apply` (with approval gate)

### Pipeline Variables
- Use pipeline variables for environment-specific values
- Store secrets in Azure Key Vault or Azure DevOps variable groups, not pipeline variables
- Use service principals with limited permissions
- Enable plan artifacts for review

## Common Issues and Solutions

### State Lock Issues
- Check for stuck locks in storage account
- Use `terraform force-unlock` cautiously
- Ensure proper authentication

### Provider Version Conflicts
- Pin provider versions in `provider.tf`
- Use `terraform init -upgrade` carefully
- Test upgrades in non-production first

### Resource Dependencies
- Use explicit `depends_on` when implicit dependencies don't work
- Avoid circular dependencies
- Use `terraform graph` to visualize dependencies

## Resources

- [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Naming Conventions](../Docs/NamingConventions.md)
- [Resource Permissions Matrix](../Docs/ResourcePermissionsMatrix.md)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)

## When to Ask for Help

- Uncertain about security implications
- Complex networking configurations
- Multi-region or disaster recovery setups
- Performance optimization questions
- Compliance and governance requirements
