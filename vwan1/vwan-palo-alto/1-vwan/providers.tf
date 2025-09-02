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
  features {}
  subscription_id = var.subscription_id
}