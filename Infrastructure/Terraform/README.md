# Terraform Infrastructure for HelloWorld (Azure)

This Terraform stack provisions:
- 1 Azure Container App (external ingress, image from registry, basic autoscale)
- Uses existing Resource Group and Azure Container Apps Environment
- Consistent resource naming via a local naming module

Repository layout
- providers.tf: Backend and AzureRM provider settings
- variables.tf: Global variables, tags, and Container App parameters
- main.tf: References existing infrastructure and creates Container App
- tf-modules/**: Reusable internal modules (naming, RG, ACA Environment, ACA)
- pipelines/helloworld-tf-pipeline.yml: Azure DevOps pipeline for Terraform deployment

Prerequisites

### Core Requirements
- Terraform ~> 1.0 installed
- Azure subscription access for the tenant/subscription IDs configured in providers.tf
- Permission to read/write the remote state storage account and container
- Existing Resource Group and Container App Environment (referenced in variables)

### Local Development Tools (Optional)
For using `tf_run_local.sh`:
- tflint: `curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash`
- checkov: `brew install checkov` (macOS) or `pip install checkov`

Backend (remote state) — providers.tf
- Backend type: azurerm (Azure Storage)
  - resource_group_name: rg-dev-devops-usc
  - storage_account_name: sadevterraformusc
  - container_name: hello-world
  - key: hello-world-tf.tfstate
  - use_azuread_auth: true (Azure AD auth for backend)
- Notes:
  - Ensure your identity can read/write the storage account/container above.
  - State is shared across users; use workspaces if managing multiple environments.

Provider — providers.tf
- azurerm ~> 4.0
- Explicit tenant_id and subscription_id set
- storage_use_azuread = true (Azure AD auth for storage SDK)
- resource_provider_registrations = "none" (provider will not auto-register RP; make sure Microsoft.App is registered)

Inputs — variables.tf
- environment (string, default: "poc01")
- location (string, default: "centralus")
- container_app_name (string, computed from naming module)
- existing_resource_group_name (string, default: "rg-poc01-usc")
- existing_container_app_environment_name (string, default: "cae-poc01-usc")
- container_registry_login_server (string, default: "ncontracts.azurecr.io")
- container_registry_username (string, sensitive)
- container_registry_password (string, sensitive)
- container_image (string, default: "ncontracts.azurecr.io/helloworld:latest")
- Locals (implicit): tags and project_name = "helloworld"
  - tags include Project, Environment, Location, IaCTool, CostCenter, Owner

Architecture — main.tf
- module "naming" (tf-modules/az-naming)
  - Purpose: builds consistent, lowercase names using function, environment, and location
  - Output used: function_name (e.g., helloworld-poc01-<loc>)
- data "azurerm_resource_group" (existing)
  - References existing resource group by name
- data "azurerm_container_app_environment" (existing)
  - References existing Container App Environment by name and resource group
- module "container_app" (tf-modules/az-container-app)
  - Name: configured via container_app_name variable
  - Key inputs:
    - revision_mode = "Single"
    - ingress_external_enabled = true
    - target_port = 8080 (ASP.NET Core default port)
    - ingress_transport = "auto"
    - Registry: login_server, username, password
    - Image: container_image
    - Resources: container_cpu = "0.5", container_memory = "1.0Gi"
    - Scale: min_replicas = 1, max_replicas = 10

How to use

### Local Development
1) Ensure the target Resource Group and Container App Environment exist
2) Set input variables via one of:
   - terraform.tfvars (recommended for non-sensitive values)
   - Environment variables TF_VAR_<name> (recommended for secrets/sensitive values)
3) Use the provided script for local operations:
   ```bash
   # Make script executable
   chmod +x tf_run_local.sh
   
   # Available commands
   ./tf_run_local.sh plan .     # Format, validate, and plan
   ./tf_run_local.sh apply .    # Format, validate, and apply
   ./tf_run_local.sh destroy .  # Destroy resources
   ./tf_run_local.sh validate . # Format, validate, lint, and security check
   ```
4) The script includes linting (tflint) and security checks (checkov)

### Production Deployment (Recommended)
Use the Azure DevOps pipeline `pipelines/helloworld-tf-pipeline.yml` which handles:
- Docker image building and pushing
- Terraform planning and applying
- Container App Environment integration
- URL retrieval and testing setup

Example terraform.tfvars
environment = "poc01"
location    = "centralus"
existing_resource_group_name = "rg-poc01-usc"
existing_container_app_environment_name = "cae-poc01-usc"
container_app_name = "ca-helloworld-poc01-usc-12345"

# Container registry configuration
container_registry_login_server      = "ncontracts.azurecr.io" \
managed_identity_name                = "managed_identity" \
managed_identity_resource_group_name = "managed_identity_rg" \
container_image                      = "ncontracts.azurecr.io/helloworld:latest"

Customization
- Container port and ingress: change target_port and ingress_* in module "container_app" inputs (main.tf).
  - Default is 8080 for ASP.NET Core applications. Ensure your image exposes this port.
- Image and registry: set container_image and registry credentials in terraform.tfvars or environment variables.
- Resources and autoscale: adjust container_cpu, container_memory, min_replicas, max_replicas in main.tf.
- Infrastructure dependencies: update existing_resource_group_name and existing_container_app_environment_name to reference your target infrastructure.
- Naming: the naming module composes names and uses compact semantics to drop empty segments; all names are lowercased.

Outputs
- Module outputs are defined within tf-modules; if your container app module exposes FQDN or URL, use those outputs after apply. Otherwise, you can read the FQDN from the azurerm_container_app resource (ingress.fqdn) inside the module.

## Azure DevOps Pipeline

The pipeline `pipelines/helloworld-tf-pipeline.yml` provides automated deployment through Azure DevOps with the following features:

### Pipeline Parameters
- **EnvironmentName**: Choose from POC01, Feature01, Feature02, or Prod (default: POC01)
- **teardown**: Boolean to destroy infrastructure instead of deploying (default: false)

### Pipeline Stages

#### 1. Build Stage
- Builds and pushes Docker image to Azure Container Registry
- Uses Docker@2 task with buildAndPush command
- Tags image with Build.BuildId for traceability

#### 2. Terraform Plan Stage
- Installs latest Terraform version
- Runs `terraform init` and `terraform plan`
- Publishes terraform plan as pipeline artifact
- Uses dynamic variables based on environment parameter

#### 3. Terraform Apply Stage (conditional)
- Downloads terraform plan artifact
- Runs `terraform apply -auto-approve`
- Initializes Container App Environment integration
- Retrieves Container App URL for testing
- Only runs when teardown=false

#### 4. Terraform Destroy Stage (conditional)
- Removes Container App Environment integration
- Runs `terraform destroy -auto-approve`
- Only runs when teardown=true

### Required Pipeline Variables
The following variables must be configured in your Azure DevOps pipeline:
- `ContainerRegistrySC`: Service connection for Azure Container Registry
- `AzureResourceManagerSC`: Service connection for Azure Resource Manager
- `ContainerRegistryLoginServer`: ACR login server URL
- `ManagedIdentityName`: User managed identity name
- `ManagedIdentityResourceGroupName`: User managed identity resource group
- `ContainerAppEnvironment`: Container App Environment identifier

### Integration with External Templates
The pipeline references external templates from `NetworkContractSolutions/Ncontracts.Infrastructure`:
- `InitializeCAE1.yml`: Sets up Container App Environment integration
- `RemoveCAEIntegration1.yml`: Cleans up CAE integration during teardown

### Running the Pipeline
1. Queue the pipeline in Azure DevOps
2. Select environment (POC01, Feature01, Feature02, or Prod)
3. Choose teardown option (false for deploy, true for destroy)
4. Pipeline will build, plan, and deploy automatically
5. Container App URL will be available in pipeline outputs

Destroy
- Use terraform destroy manually or set teardown=true in the pipeline to remove all managed resources created by this stack.
