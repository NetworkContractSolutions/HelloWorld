# module-azure-naming

Terraform module to build proper naming based on naming and tagging convention.

## Usage

```HCL
module "azure_naming" {
  source      = "../../modules/module-azure-naming"
  project     = "landing-zone"
  environment = "hub"
  location    = "eastus"
  function    = "terraform"

  tags = {
    "ManagedBy" : "DevOps"
  }
}
```

## Module Details

This module creates an null resources with correct short and full naming.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.4.4 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.1.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_null"></a> [null](#provider\_null) | >= 3.1.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [null_resource.label](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.short_label](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alteration"></a> [alteration](#input\_alteration) | Example of alteration: you spawn more than one environments in the same environment first alteration of the default deployment/environment = 01 second alteration of the deployment/environment = 02 | `string` | n/a | no |
| <a name="input_delimiter"></a> [delimiter](#input\_delimiter) | Delimiter to be used between `name`, etc. | `string` | `"-"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name -	example:prod/stage/dev/int | `string` | n/a | yes |
| <a name="input_environment_list"></a> [environment\_list](#input\_environment\_list) | Environment name | `list(any)` | <pre>[<br>  "dev",<br>  "devops",<br>  "global",<br>  "ops",<br>  "nonprod",<br>  "prod",<br>  "sandbox",<br>  "shared",<br>  "stage",<br>  "root"<br>]</pre> | no |
| <a name="input_function"></a> [function](#input\_function) | Function name | `string` | `""` | no |
| <a name="input_location"></a> [location](#input\_location) | location - example: eastus | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | An abbreviation of the Project name. Example: Project = rdp | `string` | n/a | yes |
| <a name="input_short_environment_names"></a> [short\_environment\_names](#input\_short\_environment\_names) | n/a | `map(any)` | <pre>{<br>  "dev": "d",<br>  "devops": "ds",<br>  "global": "gbl",<br>  "nonprod": "np",<br>  "ops": "o",<br>  "prod": "p",<br>  "root": "rt",<br>  "sandbox": "sbx",<br>  "shared": "sh",<br>  "stage": "st"<br>}</pre> | no |
| <a name="input_short_location_names"></a> [short\_location\_names](#input\_short\_location\_names) | Location list and its assertion. The short location set according to name conventions. | `map(any)` | <pre>{<br>  "centralus": "clus",<br>  "eastus": "eus",<br>  "eastus2": "eus2",<br>  "northcentralus": "nclus",<br>  "southcentralus": "sclus",<br>  "westcentralus": "wclus",<br>  "westus": "wus",<br>  "westus2": "wus2",<br>  "westus3": "wus3"<br>}</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags (e.g. `map('BusinessUnit`,`XYZ`) | `map(any)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alteration"></a> [alteration](#output\_alteration) | Lowercased alteration |
| <a name="output_environment"></a> [environment](#output\_environment) | Lowercased environmen name |
| <a name="output_function"></a> [function](#output\_function) | Lowercased function name |
| <a name="output_function_name"></a> [function\_name](#output\_function\_name) | Project name, Function name, Environment name, Location name, and Alteration name lowercased and splatted by dash |
| <a name="output_location"></a> [location](#output\_location) | Lowercased Azure location |
| <a name="output_merged_function_name"></a> [merged\_function\_name](#output\_merged\_function\_name) | Project name, Function name, Environment name, Location name, and Alteration name lowercased and merged by dashes |
| <a name="output_merged_name"></a> [merged\_name](#output\_merged\_name) | Project name, Environment name, Location name, and Alteration name lowercased and merged by dashes |
| <a name="output_name"></a> [name](#output\_name) | Project name, Environment name, Location name, and Alteration name lowercased and splatted by dash |
| <a name="output_project"></a> [project](#output\_project) | Lowercased project name |
| <a name="output_short_environment"></a> [short\_environment](#output\_short\_environment) | Short and lowercased version of the environment name |
| <a name="output_short_function_name"></a> [short\_function\_name](#output\_short\_function\_name) | Short and lowercased version of Project name, Function name, Environment name, Location name, and Alteration name |
| <a name="output_short_location"></a> [short\_location](#output\_short\_location) | Short and lowercased Azure region |
| <a name="output_short_name"></a> [short\_name](#output\_short\_name) | Short version of lowercased Project name, Environment name, Location name, and Alteration name |
| <a name="output_tags"></a> [tags](#output\_tags) | A mapping of tags |
<!-- END_TF_DOCS -->

## Changelog

### v 1.0.0 2023-04-12

* Initial version
