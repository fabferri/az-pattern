terraform {
  required_version = ">=1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.6.3"
    }
    local = {
      source  = "hashicorp/local"
      version = ">2.5.0"
    }
  }
}
provider "azurerm" {
  features {}
}
