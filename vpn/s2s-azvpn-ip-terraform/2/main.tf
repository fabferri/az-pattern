
# create a resource group
data "azurerm_resource_group" "rg" {
  name     = var.rg_name
}
# create a vnet1
data "azurerm_virtual_network" "vnet1" {
  name                = var.vnet1_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

# create a vnet2
data "azurerm_virtual_network" "vnet2" {
  name                = var.vnet2_name
  resource_group_name = data.azurerm_resource_group.rg.name

}

# create the first public IP for the Virtual Network Gateway1
data "azurerm_public_ip" "gw1pubIP1" {
  name                = "${var.gw1_name}-pip1"
  resource_group_name = data.azurerm_resource_group.rg.name
}

# create the second public IP for the Virtual Network Gateway1
data "azurerm_public_ip" "gw1pubIP2" {
  name                = "${var.gw1_name}-pip2"
  resource_group_name = data.azurerm_resource_group.rg.name
}

# create the first public IP for the Virtual Network Gateway2
data "azurerm_public_ip" "gw2pubIP1" {
  name                = "${var.gw2_name}-pip1"
  resource_group_name = data.azurerm_resource_group.rg.name
 
}

# create the second public IP for the Virtual Network Gateway2
data "azurerm_public_ip" "gw2pubIP2" {
  name                = "${var.gw2_name}-pip2"
  resource_group_name = data.azurerm_resource_group.rg.name
}

# deploy the Virtual Network Gateway1
data "azurerm_virtual_network_gateway" "gw1" {
  name                = var.gw1_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

# deploy the Virtual Network Gateway2
data "azurerm_virtual_network_gateway" "gw2" {
  name                = var.gw2_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

# generate a random password for the shared key
resource "random_password" "psk" {
  length           = 16
  min_lower        = 4
  min_upper        = 4
  min_numeric      = 4
  min_special      = 4
  special          = true
}

# create a local file to store the shared key
resource "local_file" "shared_secret" {
    content  = random_password.psk.result
    filename = "psk.txt"
}

# create the first local network gateway
resource "azurerm_local_network_gateway" "localnetgw11" {
  name                = var.local_netgw11_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_virtual_network.vnet2.location
  gateway_address     = data.azurerm_public_ip.gw1pubIP1.ip_address
  address_space       = []
  bgp_settings {
    asn                 = var.gw1_bgp_asn_number
    bgp_peering_address = split(",", lookup(data.azurerm_virtual_network_gateway.gw1.bgp_settings[0], "peering_address"))[0]
    peer_weight         = 0
  }
}

# create the second local network gateway
resource "azurerm_local_network_gateway" "localnetgw12" {
  name                = var.local_netgw12_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_virtual_network.vnet2.location
  gateway_address     = data.azurerm_public_ip.gw1pubIP2.ip_address
  address_space       = []
  bgp_settings {
    asn                 = var.gw1_bgp_asn_number
    bgp_peering_address = split(",", lookup(data.azurerm_virtual_network_gateway.gw1.bgp_settings[0], "peering_address"))[1]
    peer_weight         = 0
  }
}

# create the first local network gateway
resource "azurerm_local_network_gateway" "localnetgw21" {
  name                = var.local_netgw21_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_virtual_network.vnet1.location
  gateway_address     = data.azurerm_public_ip.gw2pubIP1.ip_address
  address_space       = []
  bgp_settings {
    asn                 = var.gw2_bgp_asn_number
    bgp_peering_address = split(",", lookup(data.azurerm_virtual_network_gateway.gw2.bgp_settings[0], "peering_address"))[0]
    peer_weight         = 0
  }
}

# create the second local network gateway
resource "azurerm_local_network_gateway" "localnetgw22" {
  name                = var.local_netgw22_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_virtual_network.vnet1.location
  gateway_address     = data.azurerm_public_ip.gw2pubIP2.ip_address
  address_space       = []
  bgp_settings {
    asn                 = var.gw2_bgp_asn_number
    bgp_peering_address = split(",", lookup(data.azurerm_virtual_network_gateway.gw2.bgp_settings[0], "peering_address"))[1]
    peer_weight         = 0
  }
}

# create the Virtual Network Connection1
resource "azurerm_virtual_network_gateway_connection" "gw1conn1" {
  name                               = var.gw1_conn1_name
  location                           = data.azurerm_virtual_network.vnet1.location
  resource_group_name                = data.azurerm_resource_group.rg.name
  type                               = "IPsec"
  virtual_network_gateway_id         = data.azurerm_virtual_network_gateway.gw1.id
  local_network_gateway_id           = azurerm_local_network_gateway.localnetgw21.id
  connection_protocol                = "IKEv2"
  shared_key                         = random_password.psk.result
  enable_bgp                         = true
  use_policy_based_traffic_selectors = false

  depends_on = [
    azurerm_local_network_gateway.localnetgw21
  ]
}

# create the Virtual Network Connection2
resource "azurerm_virtual_network_gateway_connection" "gw1conn2" {
  name                               = var.gw1_conn2_name
  location                           = data.azurerm_virtual_network.vnet1.location
  resource_group_name                = data.azurerm_resource_group.rg.name
  type                               = "IPsec"
  virtual_network_gateway_id         = data.azurerm_virtual_network_gateway.gw1.id
  local_network_gateway_id           = azurerm_local_network_gateway.localnetgw22.id
  connection_protocol                = "IKEv2"
  shared_key                         = random_password.psk.result
  enable_bgp                         = true
  use_policy_based_traffic_selectors = false

  depends_on = [
    azurerm_local_network_gateway.localnetgw22,
    azurerm_virtual_network_gateway_connection.gw1conn1
  ]
}

# create the Virtual Network Connection1
resource "azurerm_virtual_network_gateway_connection" "gw2conn1" {
  name                               = var.gw2_conn1_name
  location                           = data.azurerm_virtual_network.vnet1.location
  resource_group_name                = data.azurerm_resource_group.rg.name
  type                               = "IPsec"
  virtual_network_gateway_id         = data.azurerm_virtual_network_gateway.gw2.id
  local_network_gateway_id           = azurerm_local_network_gateway.localnetgw11.id
  connection_protocol                = "IKEv2"
  shared_key                         = random_password.psk.result
  enable_bgp                         = true
  use_policy_based_traffic_selectors = false

  depends_on = [
    azurerm_local_network_gateway.localnetgw11
  ]
}

# create the Virtual Network Connection2
resource "azurerm_virtual_network_gateway_connection" "gw2conn2" {
  name                               = var.gw2_conn2_name
  location                           = data.azurerm_virtual_network.vnet1.location
  resource_group_name                = data.azurerm_resource_group.rg.name
  type                               = "IPsec"
  virtual_network_gateway_id         = data.azurerm_virtual_network_gateway.gw2.id
  local_network_gateway_id           = azurerm_local_network_gateway.localnetgw12.id
  connection_protocol                = "IKEv2"
  shared_key                         = random_password.psk.result
  enable_bgp                         = true
  use_policy_based_traffic_selectors = false

  depends_on = [
    azurerm_local_network_gateway.localnetgw12,
    azurerm_virtual_network_gateway_connection.gw2conn1
  ]
}
