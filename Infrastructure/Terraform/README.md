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

The pipeline `Infrastructure/Pipelines/helloworld-dev-pipeline.yml` orchestrates image builds, Terraform, integration, and end-to-end validation.

### Pipeline Parameters
- **EnvironmentName**: Lower-cased string used to derive resource names (default: `poc01`).
- **teardown**: Boolean flag that controls the final teardown stage (default: `true`). Set to `false` to keep the environment after deployment/testing.

### Built-in Pipeline Variables
- `ContainerRegistryRepository` (`helloworld`), `ContainerRegistryLoginServer` (`ncontracts.azurecr.io`).
- `Region` (`centralus`), `ResourceGroup` (`rg-<env>-usc`), `ContainerAppEnvironmentName` (`cae-<env>-usc`).
- `ContainerAppName` is set to `helloworld-dev-ca-$(Build.BuildId)` per run, ensuring unique deployments.
- `ManagedIdentityName`/`ManagedIdentityResourceGroupName` refer to pre-created DevOps identities.
- `AzureResourceManagerSC` and `ContainerRegistrySC` must exist as service connections (`Dev-Limited`, `NContractsSC` in the sample).

### Stage Overview
- **Build (Ubuntu)**: Runs Docker@2 `buildAndPush`, producing `$(ContainerRegistryLoginServer)/$(ContainerRegistryRepository):$(Build.BuildId)`.
- **TerraformPlan (Windows)**: Checks out the repo, installs Terraform, and runs init/plan via AzureCLI. Each run writes state to `helloworld-<env>-<BuildId>.tfstate`, pins `target_port=8080`, and publishes the plan directory as the `terraform-plan` artifact.
- **Deploy (Windows)**: Downloads the artifact, repeats `terraform init` with the same state key, and executes `terraform apply --auto-approve tfplan`. After apply it:
  - Calls `Templates/Tasks/InitializeCAE1.yml@infrastructure` to wire CAE routing.
  - Executes an Azure CLI script that captures both the raw ingress FQDN and the friendly `https://<app>-<env>.dev.ncontracts.com` URL, exposing them via pipeline variables for later stages.
- **Test (Windows)**: Consumes the friendly URL, verifies it is non-empty, builds the Playwright-powered `HelloWorld.IntegrationTests` project, installs browsers (Chromium), and runs `dotnet test` against the deployed Container App.
- **Teardown (Windows, conditional)**: When `teardown=true` and the Deploy stage succeeded, the pipeline removes CAE integration via `RemoveCAEIntegration1.yml@infrastructure` and runs `terraform destroy` with the same variable set/state key to clean up the Container App.

### External Template Dependencies
Pulled from `NetworkContractSolutions/Ncontracts.Infrastructure` (via the `infrastructure` repository resource):
- `Templates/Tasks/InitializeCAE1.yml` — enables ingress and integration after deploy.
- `Templates/Tasks/RemoveCAEIntegration1.yml` — reverses the integration prior to destroy.

### Running the Pipeline
1. Queue `helloworld-dev-pipeline` in Azure DevOps.
2. Choose an `EnvironmentName` (any lowercase token used for naming) and set `teardown` to `false` if you need to keep the environment alive post-run.
3. Provide/override service-connection variables if your project uses different names.
4. Monitor stages in order: Build → TerraformPlan → Deploy → Test (Playwright) → Teardown (optional).
5. Retrieve the Container App URL from the Deploy stage logs or from the `HomePageUrl` variable emitted to the Test stage if you need to run manual checks.

Destroy
- Set `teardown=true` (default) to have the pipeline remove the Container App automatically, or run `terraform destroy` locally for ad-hoc cleanup using the same variables.
