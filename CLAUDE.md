# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an ASP.NET Core 8.0 MVC web application demonstrating Kubernetes deployment using Helm charts, with NGINX ingress controller and self-signed SSL certificates. The application is designed to run in a local Docker Desktop Kubernetes cluster.

## Technology Stack

- **Application**: ASP.NET Core 8.0 MVC (C#)
- **Container Runtime**: Docker
- **Orchestration**: Kubernetes (Docker Desktop)
- **Package Manager**: Helm 3
- **Testing**: NUnit with Selenium WebDriver (Chrome)
- **CI/CD**: Azure DevOps Pipelines (Container Apps deployment)

## Common Commands

### Local Development & Deployment

**Deploy entire application locally:**
```powershell
.\Infrastructure\DeployAll.ps1
```
This script:
1. Deploys self-signed SSL certificate (requires admin)
2. Deploys NGINX ingress controller
3. Builds Docker image
4. Creates Kubernetes namespace `example-local`
5. Deploys application via Helm
6. Opens browser to https://helloworld.localtest.me

**Build Docker image:**
```powershell
cd HelloWorld/Infrastructure
docker build -t example/helloworld -f ..\Dockerfile .. --no-cache
```

**Deploy only the application (after one-time setup):**
```powershell
cd HelloWorld/Infrastructure
.\Deploy.ps1
```

**Teardown local environment:**
```powershell
.\Infrastructure\TeardownAll.ps1
```

### Testing

**Run integration tests locally:**
```bash
dotnet build --configuration Debug
dotnet test HelloWorld.IntegrationTests/HelloWorld.IntegrationTests.csproj
```

**Run single test:**
```bash
dotnet test HelloWorld.IntegrationTests/HelloWorld.IntegrationTests.csproj --filter "FullyQualifiedName~NavigateToWebsiteRoot"
```

**Note**: Integration tests require ChromeDriver and expect the application running at https://helloworld.localtest.me (or override via `HomePageUrl` environment variable).

### Kubernetes Operations

**View all resources:**
```bash
kubectl get all -o wide -n example-local
```

**View pods:**
```bash
kubectl get pod -n example-local
```

**View logs:**
```bash
kubectl logs <pod-name> -n example-local
```

**Describe pod:**
```bash
kubectl describe pod/<pod-name> -n example-local
```

**Execute commands in pod:**
```bash
kubectl exec <pod-name> -n example-local -- env
kubectl exec <pod-name> -n example-local -it -- /bin/bash
```

**View ingress:**
```bash
kubectl get ing -n example-local
kubectl describe ing helloworld-ingress -n example-local
```

**Helm operations:**
```bash
# List releases
helm list -n example-local -a

# Rollback to revision 1
helm rollback helloworld 1 -n example-local
```

## Architecture

### Solution Structure

```
HelloWorld/                          # Main ASP.NET Core MVC application
├── Controllers/                     # MVC Controllers (HomeController)
├── Models/                          # View Models (ErrorViewModel)
├── Views/                           # Razor views
├── wwwroot/                         # Static files (CSS, JS, libraries)
├── charts/helloworld/               # Helm chart templates
│   ├── templates/                   # K8s manifests (deployment, service, ingress)
│   ├── Chart.yaml                   # Helm chart metadata
│   └── values.yaml                  # Default Helm values
├── Infrastructure/                  # App-specific deployment scripts
│   ├── Deploy.ps1                   # Deploy app to K8s
│   └── Teardown.ps1                 # Remove app from K8s
├── Dockerfile                       # Multi-stage build for container
└── HelloWorld.csproj                # Project file

HelloWorld.IntegrationTests/         # Selenium UI tests
└── HomeTest.cs                      # Page object pattern tests

Infrastructure/                      # Shared infrastructure scripts
├── OneTimeScripts/                  # One-time setup (SSL cert, NGINX)
│   ├── DeploySelfSigned.ps1        # Generate & install self-signed cert
│   └── DeployNginx.ps1             # Install NGINX ingress controller
├── Pipelines/                       # Azure DevOps pipeline definitions
│   ├── helloworld-dev-pipeline.yml # Build, deploy to Container Apps, test, teardown
│   └── reset-test.yml              # Pipeline reset pattern
├── DeployAll.ps1                    # Main deployment orchestrator
└── TeardownAll.ps1                  # Complete environment cleanup

Documentation/
└── SampleCommands.ps1               # Reference kubectl/helm commands
```

### Application Flow

1. **Entry Point**: [Program.cs](HelloWorld/Program.cs) creates host using [Startup.cs](HelloWorld/Startup.cs)
2. **Startup**: Configures MVC with default routing pattern `{controller=Home}/{action=Index}/{id?}`
3. **Controller**: [HomeController.cs](HelloWorld/Controllers/HomeController.cs) handles Index, Privacy, and Error actions
4. **Views**: Razor views in Views/Home/ rendered by controller actions

### Deployment Flow

1. **Docker Build**: Multi-stage Dockerfile builds application in SDK container, publishes to runtime container
2. **Helm Package**: Charts packaged from [HelloWorld/charts/helloworld/](HelloWorld/charts/helloworld/)
3. **Kubernetes Resources**:
   - **Deployment**: Creates pods from Docker image `example/helloworld:latest`
   - **Service**: ClusterIP service on port 80
   - **Ingress**: NGINX ingress routes helloworld.localtest.me to service, terminates TLS using secret `helloworld-tls-secret`
4. **Namespace**: Resources deployed to `example-local` namespace

### Helm Chart Configuration

Located in [HelloWorld/charts/helloworld/values.yaml](HelloWorld/charts/helloworld/values.yaml):

- **Image**: `repository: helloworld`, `tag: stable`, `pullPolicy: IfNotPresent`
- **Replicas**: 1 by default
- **Service**: ClusterIP on port 80
- **Ingress**: Configured via `--set` flags in Deploy.ps1 with DNS and TLS settings
- **Probes**: Disabled by default (`probes.enabled: false`)

Override values during deployment via `--set` flags or custom values file.

## Azure DevOps Pipeline

[Infrastructure/Pipelines/helloworld-dev-pipeline.yml](Infrastructure/Pipelines/helloworld-dev-pipeline.yml) defines:

1. **Build Stage**: Builds and pushes Docker image to Azure Container Registry
2. **Deploy Stage**: Creates Azure Container App with ingress
3. **Test Stage**: Runs integration tests against deployed Container App
4. **Teardown Stage**: Optionally deletes resource group (controlled by `teardown` parameter)

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
- **Configuration**: Base URL defaults to https://helloworld.localtest.me, override with `HomePageUrl` environment variable

Test scenarios:
- Navigate to root and verify home page
- Navigate to Privacy page via nav link
- Navigate back to Home via brand link

## Key Dependencies

- Docker Desktop with Kubernetes enabled
- Helm 3.x
- OpenSSL (included with Git for Windows)
- .NET 8.0 SDK
- Chrome browser (for integration tests)

## Important Notes

- Self-signed certificate generation requires PowerShell admin privileges
- Certificate and private key stored in `%USERPROFILE%\temp\HelloWorld\`
- If certificate validation fails, run: `kubectl delete -A ValidatingWebhookConfiguration ingress-nginx-admission`
- Application uses MVC with runtime Razor compilation enabled for development
- Default namespace for local deployment: `example-local`
