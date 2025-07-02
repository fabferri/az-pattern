
variable "resource_group_location" {
  type        = string
  default     = "uksouth"
  description = "Location of the resource group."
}

variable "resource_group_name" {
  type        = string
  default     = "rg-vpn-10"
  description = "name of the resource group."
}

variable "virtual_network1_name" {
  type        = string
  default     = "vnet1"
  description = "The name of the virtual network"
}

variable "virtual_network2_name" {
  type        = string
  default     = "vnet2"
  description = "The name of the virtual network"
}

variable "vnet1_address_space" {
  type        = list(string)
  default     = ["10.1.0.0/24"]
  description = "The name of the virtual network"
}
variable "vnet2_address_space" {
  type        = list(string)
  default     = ["10.2.0.0/24"]
  description = "The name of the virtual network"
}

variable "vnet1_GatewaySubnet" {
  type        = list(string)
  default     = ["10.1.0.192/26"]
  description = "The name of the virtual network"
}

variable "vnet2_GatewaySubnet" {
  type        = list(string)
  default     = ["10.2.0.192/26"]
  description = "The name of the virtual network"
}
variable "vnet1_AppSubnet1Name" {
  type        = string
  default     = "AppSubnet1"
  description = "The name of the virtual network"
}
variable "vnet2_AppSubnet1Name" {
  type        = string
  default     = "AppSubnet1"
  description = "The name of the virtual network"
}

variable "vnet1_AppSubnet1AddressPrefix" {
  type        = list(string)
  default     = ["10.1.0.0/27"]
  description = "The name of the virtual network"
}
variable "vnet2_AppSubnet1AddressPrefix" {
  type        = list(string)
  default     = ["10.2.0.0/27"]
  description = "The name of the virtual network"
}

variable "vpn_gw1_name" {
  type        = string
  default     = "vpngw1"
  description = "The name of the Virtual Network Gateway"
}

variable "vpn_gw2_name" {
  type        = string
  default     = "vpngw2"
  description = "The name of the Virtual Network Gateway"
}

variable "vpn_gw_sku" {
  type        = string
  description = "Configuration of the size and capacity of the virtual network gateway"
  default     = "VpnGw2AZ"
}

variable "vpn_gw_generation" {
  description = "The Generation of the Virtual Network gateway"
  default     = "Generation2"
}

variable "enable_active_active" {
  description = "If true, an active-active Virtual Network Gateway will be created"
  default     = true
}

variable "enable_bgp" {
  description = "If true, BGP (Border Gateway Protocol) will be enabled for this Virtual Network Gateway"
  default     = false
}

variable "local_netgw11_name" {
  type        = string
  description = "Name of the local network gateway on-premises"
  default     = "localNetGw11"
}

variable "local_netgw12_name" {
  type        = string
  description = "Name of the local network gateway on-premises"
  default     = "localNetGw12"
}

variable "local_netgw21_name" {
  type        = string
  description = "Name of the local network gateway on-premises"
  default     = "localNetGw21"
}

variable "local_netgw22_name" {
  type        = string
  description = "Name of the local network gateway on-premises"
  default     = "localNetGw22"
}

variable "vpn_conn11_name" {
  type        = string
  description = "The name of the VPN Gateway Connection1 to remote public IP1"
  default     = "vpngwconn11"
}
variable "vpn_conn12_name" {
  type        = string
  description = "The name of the VPN Gateway Connection2 to remote public IP2"
  default     = "vpngwconn12"
}

variable "vpn_conn21_name" {
  type        = string
  description = "The name of the VPN Gateway Connection1 to remote public IP1"
  default     = "vpngwconn21"
}
variable "vpn_conn22_name" {
  type        = string
  description = "The name of the VPN Gateway Connection2 to remote public IP2"
  default     = "vpngwconn22"
}


