# HelloWorld with Azure Container Apps

Simple HelloWorld ASP.NET Core 8.0 MVC application deployed to Azure Container Apps using Terraform and Azure DevOps.

## Overview

This project demonstrates a complete CI/CD pipeline for deploying a containerized ASP.NET Core application to Azure Container Apps using Terraform infrastructure as code and Azure DevOps pipelines with automated integration testing.

## Dependencies

1. .NET 8.0 SDK
1. Docker
1. Azure subscription with Container Apps resources
1. Azure Container Registry
1. Terraform ~> 1.0
1. Chromium browser (for Playwright integration tests)

## Deployment

The application is deployed via Azure DevOps pipeline ([Infrastructure/Pipelines/helloworld-dev-pipeline.yml](Infrastructure/Pipelines/helloworld-dev-pipeline.yml)):

1. **Build** - Builds and pushes Docker image to Azure Container Registry (tagged with Build ID)
2. **TerraformPlan** - Runs `terraform plan` with unique state file per build
3. **Deploy** - Runs `terraform apply` to create/update Azure Container App with ingress configuration
4. **Test** - Runs Playwright integration tests against the deployed Container App URL
5. **Teardown** - Optionally runs `terraform destroy` to remove resources (controlled by pipeline parameter, default: true)

### Pipeline Configuration

The pipeline requires the following variables:
- `ContainerRegistrySC` - Service connection for Azure Container Registry
- `AzureResourceManagerSC` - Azure subscription service connection with Terraform backend access
- `ContainerRegistryLoginServer` - ACR URL (e.g., `ncontracts.azurecr.io`)
- `ManagedIdentityName` - User-assigned managed identity for ACR authentication
- `EnvironmentName` - Environment name for resource naming (e.g., `poc01`, `dev`)

## Local Development

Build the Docker image locally:

```powershell
cd HelloWorld
docker build -t example/helloworld -f Dockerfile . --no-cache
```

Run integration tests:

```bash
# Set the URL to test against
$env:HomePageUrl = "https://your-container-app-url.azurecontainerapps.io"

# Build and run tests
dotnet build HelloWorld.IntegrationTests/HelloWorld.IntegrationTests.csproj --configuration Debug
pwsh HelloWorld.IntegrationTests/bin/Debug/net8.0/playwright.ps1 install chromium
dotnet test HelloWorld.IntegrationTests/HelloWorld.IntegrationTests.csproj --configuration Debug
```

Run a single test:

```bash
dotnet test HelloWorld.IntegrationTests/HelloWorld.IntegrationTests.csproj --filter "FullyQualifiedName~NavigateToWebsiteRoot"
```

## Infrastructure as Code

The Terraform configuration in [Infrastructure/Terraform/](Infrastructure/Terraform/) provides a simple, developer-friendly infrastructure setup:

- **main.tf** - Container App resource with data sources for existing infrastructure
- **variables.tf** - Well-documented input variables with sensible defaults
- **providers.tf** - Azure provider and remote state backend configuration
- **outputs.tf** - Exposes Container App URL and metadata for pipeline consumption

### Local Terraform Usage

```bash
cd Infrastructure/Terraform
terraform init
terraform plan
terraform apply
terraform output container_app_url
```

See [Infrastructure/Terraform/README.md](Infrastructure/Terraform/README.md) for detailed instructions.

## Technology Stack

- **Application**: ASP.NET Core 8.0 MVC (C#)
- **Container Runtime**: Docker
- **Cloud Platform**: Azure Container Apps
- **Infrastructure as Code**: Terraform
- **Testing**: NUnit with Playwright (Chromium)
- **CI/CD**: Azure DevOps Pipelines
- **Container Registry**: Azure Container Registry

## References

1. [Azure Container Apps Documentation](https://learn.microsoft.com/en-us/azure/container-apps/)
1. [Azure Container Registry](https://learn.microsoft.com/en-us/azure/container-registry/)
1. [ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/)
