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

variable "vwan_name" {
  type        = string
  default     = "vwan1"
  description = "The name of the virtual WAN"
}

variable "hub_name" {
  type        = string
  default     = "hub1"
  description = "The name of the Virtual Hub"
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
  description = "The name of the subnet1 in vnet1"
}

variable "vnet2_subnet1_name" {
  type        = string
  default     = "vnet2-subnet1"
  description = "The name of the subnet1 in vnet2"
}

variable "subnet90_name" {
  type        = string
  default     = "vnet90-subnet1"
  description = "The name of the subnet1 in vnet90"
}

variable "hub_connection11" {
  type        = string
  default     = "conn11"
  description = "The name of the Virtual Hub connection to spoke11"
}

variable "hub_connection12" {
  type        = string
  default     = "conn12"
  description = "The name of the Virtual Hub connection to spoke12"
}



