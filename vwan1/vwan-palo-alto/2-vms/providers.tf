terraform {
  required_version = ">=1.11"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.41.0"
    }
  }
}



provider "azurerm" {
  features {
    virtual_machine {
      delete_os_disk_on_deletion = true
      skip_shutdown_and_force_delete = true
    }
  }
  subscription_id = var.subscription_id
}
