
variable "resource_group_location" {
  type        = string
  default     = "uksouth"
  description = "Location of the resource group."
}

variable "rg_name" {
  type        = string
  default     = "rg-vpn"
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

variable "gw1_name" {
  type        = string
  default     = "gw1"
  description = "The name of the Virtual Network Gateway1"
}

variable "gw2_name" {
  type        = string
  default     = "gw2"
  description = "The name of the Virtual Network Gateway2"
}

variable "gw_sku" {
  type        = string
  description = "Configuration of the size and capacity of the virtual network gateway"
  default     = "VpnGw2AZ"
}

variable "gw_generation" {
  description = "The Generation of the Virtual Network gateway"
  default     = "Generation2"
}

variable "enable_active_active" {
  description = "If true, an active-active VPN Gateway will be created"
  default     = true
}

variable "enable_bgp" {
  description = "If true, BGP will be enabled for this VPN Gateway"
  default     = true
}

variable "gw1_bgp_asn_number" {
  description = "The Autonomous System Number (ASN) for the VPN Gateway1"
  default     = "65001"
}

variable "gw2_bgp_asn_number" {
  description = "The Autonomous System Number (ASN) for the VPN Gateway2"
  default     = "65002"
}

variable "local_netgw11_name" {
  type        = string
  description = "Name of the local network gateway to reach out the public IP1 and BGP peer IP1 of the remote VPN Gateway1"
  default     = "localNetGw11"
}

variable "local_netgw12_name" {
  type        = string
  description = "Name of the local network gateway to reach out the public IP2 and BGP peer IP2 of the remote VPN Gateway1"
  default     = "localNetGw12"
}

variable "local_netgw21_name" {
  type        = string
  description = "Name of the local network gateway to reach out the public IP1 and BGP peer IP1 of the remote VPN Gateway2"
  default     = "localNetGw21"
}

variable "local_netgw22_name" {
  type        = string
  description = "Name of the local network gateway to reach out the public IP2 and BGP peer IP2 of the remote VPN Gateway2"
  default     = "localNetGw22"
}
variable "gw1_conn1_name" {
  type        = string
  description = "The name of the Connection1 in VPN Gateway1 to connect to the remote VPN Gateway2-public IP1"
  default     = "gwconn11"
}
variable "gw1_conn2_name" {
  type        = string
  description = "The name of the Connection2 in VPN Gateway1 to connect to the remote VPN Gateway2-public IP2"
  default     = "gwconn12"
}

variable "gw2_conn1_name" {
  type        = string
  description = "The name of the Connection1 in VPN Gateway2 to connect to the remote VPN Gateway1-public IP1"
  default     = "gwconn21"
}
variable "gw2_conn2_name" {
  type        = string
  description = "The name of the Connection2 in VPN Gateway2 to connect to the remote VPN Gateway1-public IP2"
  default     = "gwconn22"
}


