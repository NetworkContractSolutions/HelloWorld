# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an ASP.NET Core 8.0 MVC web application deployed to Azure Container Apps via Azure DevOps pipelines.

## Technology Stack

- **Application**: ASP.NET Core 8.0 MVC (C#)
- **Container Runtime**: Docker
- **Cloud Platform**: Azure Container Apps
- **Testing**: NUnit with Selenium WebDriver (Chrome)
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

HelloWorld.IntegrationTests/         # Selenium UI tests
└── HomeTest.cs                      # Page object pattern tests

Infrastructure/
└── Pipelines/                       # Azure DevOps pipeline definitions
    ├── helloworld-dev-pipeline.yml  # Build, deploy to Container Apps, test, teardown
    ├── container-app.bicep          # Bicep template for Container App
    └── reset-test.yml               # Pipeline reset pattern
```

### Application Flow

1. **Entry Point**: [Program.cs](HelloWorld/Program.cs) creates host using [Startup.cs](HelloWorld/Startup.cs)
2. **Startup**: Configures MVC with default routing pattern `{controller=Home}/{action=Index}/{id?}`
3. **Controller**: [HomeController.cs](HelloWorld/Controllers/HomeController.cs) handles Index, Privacy, and Error actions
4. **Views**: Razor views in Views/Home/ rendered by controller actions

### Deployment Flow

1. **Docker Build**: Multi-stage Dockerfile builds application in SDK container, publishes to runtime container
2. **Container Registry**: Image pushed to Azure Container Registry
3. **Container App**: Deployed using Bicep template with ingress configuration
4. **Testing**: Integration tests run against deployed Container App
5. **Teardown**: Optional cleanup of Container App resources

## Azure DevOps Pipeline

[Infrastructure/Pipelines/helloworld-dev-pipeline.yml](Infrastructure/Pipelines/helloworld-dev-pipeline.yml) defines the Azure Container Apps deployment pipeline:

1. **Build Stage**: Builds and pushes Docker image to Azure Container Registry
2. **Deploy Stage**: Creates Azure Container App with ingress using Bicep template
3. **Test Stage**: Runs integration tests against deployed Container App URL
4. **Teardown Stage**: Optionally deletes Container App (controlled by `teardown` parameter)

**Required Pipeline Variables:**
- `ContainerRegistrySC`: Service connection for ACR
- `AzureResourceManagerSC`: Azure subscription service connection
- `ContainerAppEnvironment`: Container App Environment ID
- `ContainerRegistryLoginServer`, `ContainerRegistryUsername`, `ContainerRegistryPassword`
- `LogAnalyticsWorkspace`, `LogAnalyticsResourceGroup`

## Integration Testing

Tests in [HelloWorld.IntegrationTests/HomeTest.cs](HelloWorld.IntegrationTests/HomeTest.cs) use:

- **Framework**: NUnit
- **Browser Automation**: Selenium WebDriver with ChromeDriver
- **Pattern**: Page Object pattern (HelloWorldHome class)
- **Configuration**: `HomePageUrl` environment variable is automatically set in Azure DevOps pipeline to the deployed Container App URL

Test scenarios:
- Navigate to root and verify home page
- Navigate to Privacy page via nav link
- Navigate back to Home via brand link

## Key Dependencies

- Azure subscription with Container Apps resources
- Azure Container Registry
- .NET 8.0 SDK
- Docker
- Chrome browser (for integration tests)

## Important Notes

- Container Apps automatically handle SSL/TLS certificates and ingress
- Integration tests retrieve the Container App URL dynamically from the deployment
- Teardown stage can be controlled via pipeline parameter to preserve or delete resources
- Application uses MVC with runtime Razor compilation enabled for development
