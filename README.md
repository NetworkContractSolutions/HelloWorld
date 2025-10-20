# HelloWorld with Azure Container Apps

Simple HelloWorld ASP.NET Core 8.0 MVC application deployed to Azure Container Apps.

## Overview

This project demonstrates a complete CI/CD pipeline for deploying a containerized ASP.NET Core application to Azure Container Apps using Azure DevOps.

## Dependencies

1. .NET 8.0 SDK
1. Docker
1. Azure subscription with Container Apps resources
1. Azure Container Registry
1. Chrome browser (for integration tests)

## Deployment

The application is deployed via Azure DevOps pipeline ([Infrastructure/Pipelines/helloworld-dev-pipeline.yml](Infrastructure/Pipelines/helloworld-dev-pipeline.yml)):

1. **Build** - Builds and pushes Docker image to Azure Container Registry
2. **Deploy** - Creates Azure Container App using Bicep template
3. **Test** - Runs Selenium integration tests against the deployed application
4. **Teardown** - Optionally removes the Container App (controlled by pipeline parameter)

## Local Development

Build the Docker image locally:

```powershell
cd HelloWorld
docker build -t example/helloworld -f Dockerfile . --no-cache
```

Run integration tests:

```bash
dotnet build --configuration Debug
dotnet test HelloWorld.IntegrationTests/HelloWorld.IntegrationTests.csproj
```

## Technology Stack

- ASP.NET Core 8.0 MVC
- Azure Container Apps
- Azure Container Registry
- Docker
- NUnit + Selenium WebDriver
- Azure DevOps Pipelines

## References

1. [Azure Container Apps Documentation](https://learn.microsoft.com/en-us/azure/container-apps/)
1. [Azure Container Registry](https://learn.microsoft.com/en-us/azure/container-registry/)
1. [ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/)
