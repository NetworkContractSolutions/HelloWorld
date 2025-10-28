# Terraform Infrastructure for HelloWorld (Azure)

This Terraform stack provisions:
- 1 Resource Group
- 1 Azure Container Apps Environment
- 1 Azure Container App (external ingress, image from registry, basic autoscale)
- Consistent resource naming via a local naming module

Repository layout
- providers.tf: Backend and AzureRM provider settings
- variables.tf: Global variables, tags, and Container App parameters
- main.tf: Composes modules (naming, resource group, Container Apps env, Container App)
- tf-modules/**: Reusable internal modules (naming, RG, ACA Environment, ACA)

Prerequisites
- Terraform ~> 1.0 installed
- Azure subscription access for the tenant/subscription IDs configured in providers.tf
- Permission to read/write the remote state storage account and container
- Required resource providers registered in the subscription (Microsoft.App, Microsoft.OperationalInsights, Microsoft.LogAnalytics if applicable)

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
- environment (string, default: "dev")
- location (string, default: "centralus")
- container_registry_login_server (string, default: "mcr.microsoft.com")
- container_registry_username (string, sensitive)
- container_registry_password (string, sensitive)
- container_image (string, default: "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest")
- Locals (implicit): tags and project_name = "helloworld"
  - tags include Project, Environment, Location, IaCTool

Modules — main.tf
- module "naming" (tf-modules/az-naming)
  - Purpose: builds consistent, lowercase names using function, environment, and location
  - Output used: function_name (e.g., helloworld-dev-<loc>)
- module "resource_group" (tf-modules/az-resource-group)
  - Name: rg-${function_name}-00 (lowercased and hyphenated)
- module "container_app_env" (tf-modules/az-container-app-env)
  - Name: cappenv-${function_name}-00
  - Outputs used: app_container_env_id
- module "container_app" (tf-modules/az-container-app)
  - Name: capp-${function_name}-00
  - Key inputs:
    - revision_mode = "Single"
    - ingress_external_enabled = true
    - target_port = 80
    - ingress_transport = "auto"
    - Registry: login_server, username, password
    - Image: container_image
    - Resources: container_cpu = "0.5", container_memory = "1.0Gi"
    - Scale: min_replicas = 1, max_replicas = 10

How to use
1) Set input variables via one of:
   - terraform.tfvars (recommended for non-sensitive values)
   - Environment variables TF_VAR_<name> (recommended for secrets/sensitive values)
2) Initialize the working directory (downloads providers and configures the remote backend)
3) Review the execution plan, then apply

Example terraform.tfvars
environment = "dev"
location    = "centralus"

# Private registry example (ACR or others)
container_registry_login_server = "myregistry.azurecr.io"
container_registry_username     = "myregistry"
container_registry_password     = "<secret>"
container_image                 = "myregistry.azurecr.io/hello-world:2025.10.27"

Customization
- Container port and ingress: change target_port and ingress_* in module "container_app" inputs (main.tf).
  - If your container listens on 8080, set target_port = 8080 and ensure your image exposes/uses that port.
- Image and registry: set container_image and registry credentials in terraform.tfvars or environment variables.
- Resources and autoscale: adjust container_cpu, container_memory, min_replicas, max_replicas in main.tf.
- Naming: the naming module composes names and uses compact semantics to drop empty segments; all names are lowercased.

Outputs
- Module outputs are defined within tf-modules; if your container app module exposes FQDN or URL, use those outputs after apply. Otherwise, you can read the FQDN from the azurerm_container_app resource (ingress.fqdn) inside the module.

Security and secrets
- Do not commit secrets. Prefer TF_VAR_* environment variables for sensitive inputs:
  - TF_VAR_container_registry_username
  - TF_VAR_container_registry_password
- Ensure the Azure Storage backend is secured and access is scoped appropriately.

Troubleshooting
- MissingSubscriptionRegistration: Register Microsoft.App and related providers in your subscription.
- Backend auth errors: Verify your identity has access to the storage account and that Azure AD auth is allowed.
- Image pull failures: Confirm registry server/username/password are correct and that the image tag exists and is accessible.

Destroy
- Use terraform destroy to remove all managed resources created by this stack. Be aware this will remove the resource group and all contained resources created by these modules.
