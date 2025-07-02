https://cloudlearning365.com/?p=506
https://blog.nhat-tong.com/post/2021/04/azure/site-to-site-vpn/
https://github.com/kumarvna/terraform-azurerm-vpn-gateway/blob/master/main.tf
===============================
VIRTUAL NETWORK MANAGER: https://raw.githubusercontent.com/MicrosoftDocs/azure-docs/refs/heads/main/articles/virtual-network-manager/create-virtual-network-manager-terraform.md
https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/virtual-network-manager/create-virtual-network-manager-terraform.md
https://learn.microsoft.com/en-us/azure/developer/terraform/
https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway
https://medium.com/@haroldfinch01/how-do-you-do-simple-string-concatenation-in-terraform-59437b83ec5a
https://spacelift.io/blog/terraform-files
https://github.com/Azure/azure-cli/issues/28062
https://www.cloudiqtech.com/terraform-infrastructure-as-code-quickstart-guide/
https://www.youtube.com/watch?v=QrSfASpVE14
https://github.com/hashicorp/terraform-provider-azurerm/issues/10425
https://spacelift.io/blog/terraform-files
https://stackoverflow.com/questions/70689512/terraform-check-if-resource-exists-before-creating-it

Configuration Files (.tf): These files define the infrastructure resources you want to create. They include details about providers, resources, variables, and outputs. For example, a configuration file might specify the creation of a virtual network, subnets, and virtual machines1.

State Files (.tfstate): Terraform uses state files to keep track of the resources it manages. These files are crucial for understanding the current state of your infrastructure and for making updates. Ensure you have the latest state file from your previous deployment1.

Variables Files (.tfvars): These files contain variable definitions that can be used to customize your deployment. They allow you to pass different values for variables without changing the main configuration files
=====================
Main Configuration Files: These are the .tf files that define your infrastructure. Typically, you'll have files like main.tf, variables.tf, outputs.tf, and providers.tf.

State Files: The terraform.tfstate file keeps track of the resources Terraform manages. If you want to maintain the current state of your infrastructure, you'll need this file. Additionally, the terraform.tfstate.backup file is useful as a backup of your state file.

Terraform Configuration Directory: Ensure you have the entire directory where your Terraform configuration files are stored. This includes any subdirectories and files that are referenced in your configuration.

Environment Variables and Secrets: If your configuration relies on environment variables or secret files (e.g., .env files), make sure these are also transferred.

Backend Configuration: If you're using a remote backend to store your state files (like AWS S3, Azure Blob Storage, etc.), ensure the backend configuration is included in your main.tf or a separate backend configuration file.

Modules: If your configuration uses modules, ensure the module files or the references to the module sources are included.

============================
terraform init
terraform plan
terraform apply
===========================
how to retrieve BGP address of the specified Azure VPN Gateway.

provider "azurerm" {
  features {}
}

data "azurerm_virtual_network_gateway" "example" {
  name                = "example-vng"
  resource_group_name = "example-rg"
}

output "bgp_address" {
  value = data.azurerm_virtual_network_gateway.example.bgp_settings[0].peering_addresses[0].apipa_addresses[0]
}