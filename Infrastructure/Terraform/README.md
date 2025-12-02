# Terraform Infrastructure for HelloWorld Container App

This Terraform configuration deploys an ASP.NET Core application to Azure Container Apps. It's designed as a simple, copy-paste-able example for developers new to Terraform and Azure Container Apps.

## What Gets Deployed

- **1 Azure Container App** - Your containerized application with:
  - External HTTPS ingress (auto-provisioned SSL)
  - Auto-scaling (0-1 replicas)
  - Managed identity authentication to Azure Container Registry

## Prerequisites

### Required Azure Resources (Pre-existing)
These must exist before running Terraform:
- Azure Container App Environment (shared across multiple apps)
- Resource Group
- User-Assigned Managed Identity (with AcrPull permission on your container registry)
- Azure Container Registry with your application image

### Required Tools
- [Terraform](https://www.terraform.io/downloads) ~> 1.0
- Azure CLI (authenticated: `az login`)
- Access to the Azure subscription and state storage account

## Project Structure

```
Infrastructure/Terraform/
├── main.tf          # Container App resource and data sources (66 lines)
├── variables.tf     # Input variables with descriptions and defaults
├── providers.tf     # Terraform backend and Azure provider configuration
├── outputs.tf       # Outputs (URLs, names) for pipeline consumption
└── README.md        # This file
```

**Key Point**: Everything is in these 4 files. No custom modules, no complex abstractions.

## How It Works

### 1. Reference Existing Infrastructure
```hcl
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}
```
Terraform looks up your existing Resource Group, Container App Environment, and Managed Identity.

### 2. Deploy Container App
```hcl
resource "azurerm_container_app" "app" {
  name                         = var.container_app_name
  container_app_environment_id = data.azurerm_container_app_environment.env.id
  # ... configuration ...
}
```
Creates your Container App with ingress, registry authentication, and scaling configured.

### 3. Output URLs
```hcl
output "container_app_url" {
  value = "https://${azurerm_container_app.app.ingress[0].fqdn}"
}
```
Exposes the app URL for testing or pipeline integration.

## Quick Start

### Local Development

1. **Authenticate to Azure**
   ```bash
   az login
   ```

2. **Initialize Terraform**
   ```bash
   cd Infrastructure/Terraform
   terraform init
   ```

3. **Customize Variables** (optional)

   Edit the defaults in `variables.tf` or create `terraform.tfvars`:
   ```hcl
   environment                              = "dev"
   container_app_name                       = "ca-myapp-dev-001"
   existing_cae_resource_group_name         = "rg-dev-usc"
   existing_container_app_environment_name  = "cae-dev-usc"
   container_image                          = "myregistry.azurecr.io/myapp:v1.0"
   ```

4. **Plan & Apply**
   ```bash
   terraform plan
   terraform apply
   ```

5. **Get the URL**
   ```bash
   terraform output container_app_url
   ```

### Azure DevOps Pipeline (Recommended)

See `Infrastructure/Pipelines/helloworld-dev-pipeline.yml` for a complete CI/CD example:

**Pipeline Flow:**
1. **Build** - Builds Docker image, pushes to ACR with Build ID as tag
2. **TerraformPlan** - Runs `terraform plan` with unique state file
3. **Deploy** - Runs `terraform apply`, configures routing, retrieves URL
4. **Test** - Runs Playwright integration tests against deployed app
5. **Teardown** - Optionally runs `terraform destroy` to clean up

**Key Pipeline Features:**
- Variables passed via `--var` flags (no need to edit .tf files)
- Unique state file per build: `helloworld-{env}-{buildId}.tfstate`
- Automatic URL retrieval for testing
- Conditional teardown controlled by pipeline parameter

## Configuration Reference

### Essential Variables

| Variable | Description | Default | Pipeline Override |
|----------|-------------|---------|-------------------|
| `container_app_name` | Unique name for Container App | `ca-helloworld-poc01-usc-001` | Yes - includes Build ID |
| `container_image` | Full image path with tag | `ncontracts.azurecr.io/helloworld:latest` | Yes - uses Build ID tag |
| `existing_cae_resource_group_name` | Existing Resource Group | `rg-poc01-usc` | Yes - based on environment |
| `existing_container_app_environment_name` | Existing CAE | `cae-poc01-usc` | Yes - based on environment |
| `target_port` | Container listening port | `8080` | No |

### Container App Settings

Located in `main.tf` lines 48-59:

```hcl
template {
  container {
    cpu    = "0.5"      # 0.5 CPU cores
    memory = "1Gi"      # 1 GiB memory
  }
  min_replicas = 0     # Initially 1 replica is created but can scale to 0
  max_replicas = 1     # Scale to a maximum of 1 instance
}
```

**To customize**: Edit these values directly in `main.tf` or convert them to variables.

## Remote State Configuration

State is stored in Azure Blob Storage (see `providers.tf`):

```hcl
backend "azurerm" {
  resource_group_name  = "rg-dev-devops-usc"
  storage_account_name = "sadevterraformusc"
  use_azuread_auth     = true
}
```

**Pipeline Behavior:**
- Each pipeline run creates a unique state file: `helloworld-{env}-{buildId}.tfstate`
- This allows multiple deployments without state conflicts
- State files are stored in separate containers per environment (e.g., `poc01`, `dev`)

**State Cleanup:**
- State files accumulate over time
- Consider implementing a cleanup process for old state files
- Or use a shared state file for persistent environments

## Common Customizations

### Change Container Resources
Edit `main.tf` lines 53-54:
```hcl
cpu    = "1.0"   # Double the CPU
memory = "2Gi"   # Double the memory
```

### Change Scaling Behavior
Edit `main.tf` lines 57-58:
```hcl
min_replicas = 2    # Always have 2 instances
max_replicas = 20   # Scale up to 20 instances
```

### Change Container Port
Edit `variables.tf` line 61 (or pass via `--var`):
```hcl
default = 5000  # If your app listens on port 5000
```

### Add Environment Variables
Add to the `container` block in `main.tf`:
```hcl
container {
  name   = var.container_app_name
  image  = var.container_image
  cpu    = "0.5"
  memory = "1Gi"

  env {
    name  = "ASPNETCORE_ENVIRONMENT"
    value = var.environment
  }

  env {
    name  = "ApplicationInsights__ConnectionString"
    value = "your-connection-string"
  }
}
```

## Teardown

### Local
```bash
terraform destroy
```

### Pipeline
Set the `teardown` parameter to `true` (default) when running the pipeline.

**What gets destroyed:**
- The Container App resource
- The Terraform state file remains in storage for audit purposes

**What's preserved:**
- Container App Environment (shared infrastructure)
- Resource Group
- Managed Identity
- Container images in ACR

## Troubleshooting

### "No declaration found for var.xxx"
Make sure you've defined all variables in `variables.tf`. Run `terraform init` to refresh.

### "Error: Backend initialization required"
Run `terraform init` or `terraform init --reconfigure` to set up the backend.

### "Error acquiring the state lock"
Another Terraform process is running. Wait for it to complete or use `terraform force-unlock` (use cautiously).

### Pipeline can't find Container App after deployment
Check that the `container_app_name` variable matches between Plan and Apply stages. The pipeline uses `$(ContainerAppName)` which includes the Build ID.

### Playwright tests fail
- Verify `HomePageUrl` is being passed correctly (Pipeline line 198)
- Check that the Container App is actually running: `az containerapp show -n {name} -g {rg}`
- Verify external ingress is enabled and HTTPS certificate is provisioned

## Learning Resources

- [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Container Apps Documentation](https://learn.microsoft.com/en-us/azure/container-apps/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)

## Next Steps

1. **Run the pipeline** to see the full workflow in action
2. **Experiment locally** with `terraform plan` to see what changes before applying
3. **Customize** the configuration for your specific application needs
4. **Add secrets** using Azure Key Vault references (see Azure Container Apps docs)
5. **Implement** multi-environment configurations using workspaces or separate .tfvars files
