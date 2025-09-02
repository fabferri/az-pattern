variable "subscription_id" {
  type        = string
  description = "Location of the resource group."
}

variable "rg_location" {
  type        = string
  default     = "uksouth"
  description = "Location of the resource group."
}

variable "rg_name" {
  type        = string
  default     = "rg2-wan"
  description = "name of the resource group."
}

variable "vnet1_name" {
  type        = string
  default     = "vnet1"
  description = "The name of the virtual network1"
}

variable "vnet2_name" {
  type        = string
  default     = "vnet2"
  description = "The name of the virtual network2"
}

variable "vnet90_name" {
  type        = string
  default     = "vnet90"
  description = "The name of the virtual network90"
}

variable "vnet1_subnet1_name" {
  type        = string
  default     = "vnet1-subnet1"
  description = "The name of the vnet1 subnet1"
}

variable "vnet2_subnet1_name" {
  type        = string
  default     = "vnet2-subnet1"
  description = "The name of the vnet2 subnet1"
}

variable "vnet90_subnet1_name" {
  type        = string
  default     = "vnet90-subnet1"
  description = "The name of the vnet90 subnet1"
}

variable "admin_username" {
  type        = string
  description = "The admin username for the VM"
}

variable "admin_password" {
  type        = string
  description = "The admin password for the VM"
}

