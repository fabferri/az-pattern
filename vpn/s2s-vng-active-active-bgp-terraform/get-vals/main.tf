data "azurerm_resource_group" "rg" {
  name     = var.rg_name
}

data "azurerm_virtual_network_gateway" "gw1" {
  name                = var.gw1_name
  resource_group_name = var.rg_name
}

# deploy the Virtual Network Gateway2
data "azurerm_virtual_network_gateway" "gw2" {
  name                = var.gw2_name
  resource_group_name = var.rg_name
}

output "gw1_bgp_peering_address1" {
  value=split(",", data.azurerm_virtual_network_gateway.gw1.bgp_settings[0].peering_address)[0]
  description = "gateway1: BGP peering address for the first peering"
}

output "gw1_bgp_peering_address2" {
  value=split(",", data.azurerm_virtual_network_gateway.gw1.bgp_settings[0].peering_address)[1]
  description = "gateway1: BGP peering address for the first peering"
}

output "gw2_bgp_peering_address1" {
  value=split(",",data.azurerm_virtual_network_gateway.gw2.bgp_settings[0].peering_address)[0]
  description = "gateway2: BGP peering address for the first peering"
}

output "gw2_bgp_peering_address2" {
  value=split(",", data.azurerm_virtual_network_gateway.gw2.bgp_settings[0].peering_address)[1]
  description = "gateway2: BGP peering addresses for the second peering"
}

output "gw1_bgp_peerings_list" {
  value= data.azurerm_virtual_network_gateway.gw1.bgp_settings[0].peering_address
  description = "gateway1: list of BGP peering address"
}

output "gw1_asn" {
  value= data.azurerm_virtual_network_gateway.gw1.bgp_settings[0].asn
  description = "gateway1 ASN"
}

output "gw2_asn" {
  value= data.azurerm_virtual_network_gateway.gw2.bgp_settings[0].asn
  description = "gateway1 ASN"
}
