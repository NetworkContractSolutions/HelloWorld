# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an ASP.NET Core 8.0 MVC web application deployed to Azure Container Apps via Azure DevOps pipelines.

## Technology Stack

- **Application**: ASP.NET Core 8.0 MVC (C#)
- **Container Runtime**: Docker
- **Cloud Platform**: Azure Container Apps
- **Testing**: NUnit with Playwright (Chromium)
- **Infrastructure as Code**: Terraform
- **CI/CD**: Azure DevOps Pipelines

## Common Commands

### Local Development

**Build Docker image locally:**
```powershell
cd HelloWorld
docker build -t example/helloworld -f Dockerfile . --no-cache
```

### Testing

**Run integration tests:**
```bash
dotnet build --configuration Debug
dotnet test HelloWorld.IntegrationTests/HelloWorld.IntegrationTests.csproj
```

**Run single test:**
```bash
dotnet test HelloWorld.IntegrationTests/HelloWorld.IntegrationTests.csproj --filter "FullyQualifiedName~NavigateToWebsiteRoot"
```

**Note**: Integration tests require ChromeDriver. Set the `HomePageUrl` environment variable to point to your Container App URL.

### Azure Container Apps Operations

**View Container Apps:**
```bash
az containerapp list --resource-group <resource-group-name> -o table
```

**View Container App logs:**
```bash
az containerapp logs show --name <container-app-name> --resource-group <resource-group-name> --follow
```

**Get Container App URL:**
```bash
az containerapp show --name <container-app-name> --resource-group <resource-group-name> --query properties.configuration.ingress.fqdn -o tsv
```

## Architecture

### Solution Structure

```
HelloWorld/                          # Main ASP.NET Core MVC application
├── Controllers/                     # MVC Controllers (HomeController)
├── Models/                          # View Models (ErrorViewModel)
├── Views/                           # Razor views
├── wwwroot/                         # Static files (CSS, JS, libraries)
├── Dockerfile                       # Multi-stage build for container
└── HelloWorld.csproj                # Project file

HelloWorld.IntegrationTests/         # Playwright UI tests
└── HomeTest.cs                      # Page object pattern tests

Infrastructure/
├── Pipelines/                       # Azure DevOps pipeline definitions
│   ├── helloworld-dev-pipeline.yml  # Build, deploy to Container Apps, test, teardown
│   ├── container-app.bicep          # Legacy Bicep template (not used)
│   └── reset-test.yml               # Pipeline reset pattern
└── Terraform/                       # Terraform infrastructure as code
    ├── main.tf                      # Container App resource definition
    ├── variables.tf                 # Input variables
    ├── providers.tf                 # Azure provider configuration
    ├── outputs.tf                   # Deployment outputs
    └── README.md                    # Terraform documentation
```

### Application Flow

1. **Entry Point**: [Program.cs](HelloWorld/Program.cs) creates host using [Startup.cs](HelloWorld/Startup.cs)
2. **Startup**: Configures MVC with default routing pattern `{controller=Home}/{action=Index}/{id?}`
3. **Controller**: [HomeController.cs](HelloWorld/Controllers/HomeController.cs) handles Index, Privacy, and Error actions
4. **Views**: Razor views in Views/Home/ rendered by controller actions

### Deployment Flow

1. **Docker Build**: Multi-stage Dockerfile builds application in SDK container, publishes to runtime container
2. **Container Registry**: Image pushed to Azure Container Registry
3. **Terraform Plan**: Terraform generates execution plan with unique state file per build
4. **Terraform Apply**: Container App deployed to Azure with ingress configuration
5. **Testing**: Playwright integration tests run against deployed Container App
6. **Teardown**: Optional `terraform destroy` cleanup of Container App resources

## Azure DevOps Pipeline

[Infrastructure/Pipelines/helloworld-dev-pipeline.yml](Infrastructure/Pipelines/helloworld-dev-pipeline.yml) defines the Azure Container Apps deployment pipeline:

1. **Build Stage**: Builds and pushes Docker image to Azure Container Registry (tagged with Build ID)
2. **TerraformPlan Stage**: Runs `terraform plan` with unique state file per build
3. **Deploy Stage**: Runs `terraform apply`, configures CAE routing, retrieves Container App URL
4. **Test Stage**: Runs Playwright integration tests against deployed Container App URL
5. **Teardown Stage**: Optionally runs `terraform destroy` (controlled by `teardown` parameter, default: true)

**Required Pipeline Variables:**
- `ContainerRegistrySC`: Service connection for Azure Container Registry
- `AzureResourceManagerSC`: Azure subscription service connection with Terraform backend access
- `ContainerRegistryLoginServer`: ACR URL (e.g., `ncontracts.azurecr.io`)
- `ManagedIdentityName`: User-assigned managed identity for ACR authentication
- `EnvironmentName`: Environment name for resource naming (e.g., `poc01`, `dev`)

**Pipeline Features:**
- Unique state file per build: `helloworld-{env}-{buildId}.tfstate`
- Variables passed to Terraform via `--var` flags (no manual .tf file edits needed)
- Automatic URL retrieval and injection into test stage
- Conditional teardown based on parameter

## Integration Testing

Tests in [HelloWorld.IntegrationTests/HomeTest.cs](HelloWorld.IntegrationTests/HomeTest.cs) use:

- **Framework**: NUnit
- **Browser Automation**: Microsoft Playwright with Chromium
- **Pattern**: Page Object pattern (HelloWorldHome class)
- **Configuration**: `HomePageUrl` environment variable is automatically set in Azure DevOps pipeline to the deployed Container App URL

Test scenarios:
- Navigate to root and verify home page
- Navigate to Privacy page via nav link
- Navigate back to Home via brand link

**Running Locally:**
```bash
# Set the URL to test against
$env:HomePageUrl = "https://your-container-app-url.azurecontainerapps.io"

# Build and run tests
dotnet build HelloWorld.IntegrationTests/HelloWorld.IntegrationTests.csproj --configuration Debug
pwsh HelloWorld.IntegrationTests/bin/Debug/net8.0/playwright.ps1 install chromium
dotnet test HelloWorld.IntegrationTests/HelloWorld.IntegrationTests.csproj --configuration Debug
```

## Key Dependencies

- Azure subscription with Container Apps resources
- Azure Container Registry
- .NET 8.0 SDK
- Docker
- Terraform ~> 1.0
- Playwright with Chromium (for integration tests)

## Terraform Infrastructure

The Terraform configuration in [Infrastructure/Terraform/](Infrastructure/Terraform/) is designed as a simple, developer-friendly example:

**Structure:**
- **main.tf** (66 lines): Container App resource with data sources for existing infrastructure
- **variables.tf**: Well-documented input variables with sensible defaults
- **providers.tf**: Azure provider and remote state backend configuration
- **outputs.tf**: Exposes Container App URL and metadata for pipeline consumption
- **README.md**: Comprehensive documentation for developers

**Key Features:**
- No custom modules - everything is self-contained and readable
- References existing infrastructure (Resource Group, Container App Environment, Managed Identity)
- Managed identity authentication to Azure Container Registry (no passwords in state)
- Auto-scaling configuration (1-10 replicas)
- External HTTPS ingress with auto-provisioned SSL certificates

**Local Usage:**
```bash
cd Infrastructure/Terraform
terraform init
terraform plan
terraform apply
terraform output container_app_url
```

See [Infrastructure/Terraform/README.md](Infrastructure/Terraform/README.md) for detailed instructions.

## Important Notes

- Container Apps automatically handle SSL/TLS certificates and ingress
- Integration tests retrieve the Container App URL dynamically from the deployment
- Teardown stage can be controlled via pipeline parameter to preserve or delete resources
- Application uses MVC with runtime Razor compilation enabled for development
- Terraform state files are stored per-build in Azure Blob Storage with unique keys
