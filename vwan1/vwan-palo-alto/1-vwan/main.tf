# create a resource group
resource "azurerm_resource_group" "rg" {
  location = var.rg_location
  name     = var.rg_name
}
# create a vnet1
resource "azurerm_virtual_network" "vnet1" {
  name                = var.vnet1_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.101.1.0/24"]
}

# Create subnet11 in vnet1
resource "azurerm_subnet" "vnet1_subnet11" {
  name                 = var.vnet1_subnet1_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.101.1.0/27"]
}

# create a vnet2
resource "azurerm_virtual_network" "vnet2" {
  name                = var.vnet2_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.101.2.0/24"]
}

# Create subnet11 in vnet1
resource "azurerm_subnet" "vnet2_subnet12" {
  name                 = var.vnet2_subnet1_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
  address_prefixes     = ["10.101.2.0/27"]
}

# Create a Virtual WAN
resource "azurerm_virtual_wan" "vwan1" {
  name                = var.vwan_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# Create a Virtual Hub
resource "azurerm_virtual_hub" "hub1" {
  name                = var.hub_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  virtual_wan_id      = azurerm_virtual_wan.vwan1.id
  address_prefix      = "10.250.0.0/23"
}

resource "azurerm_virtual_hub_connection" "hubconnection11" {
  name                      = var.hub_connection11
  virtual_hub_id            = azurerm_virtual_hub.hub1.id
  remote_virtual_network_id = azurerm_virtual_network.vnet1.id
}

resource "azurerm_virtual_hub_connection" "hubconnection12" {
  name                      = var.hub_connection12
  virtual_hub_id            = azurerm_virtual_hub.hub1.id
  remote_virtual_network_id = azurerm_virtual_network.vnet2.id

  depends_on = [azurerm_virtual_hub_connection.hubconnection11]
}

# create a vnet90
resource "azurerm_virtual_network" "vnet90" {
  name                = var.vnet90_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.90.0.0/24"]
}

# Create subnet90 in vnet90
resource "azurerm_subnet" "vnet90_subnet11" {
  name                 = var.subnet90_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet90.name
  address_prefixes     = ["10.90.0.0/27"]
}

resource "azurerm_virtual_network_peering" "peering_vnet90_to_spoke1" {
  name                      = "peer-90-to-1"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet90.name
  remote_virtual_network_id = azurerm_virtual_network.vnet1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  # `allow_gateway_transit` must be set to false for vnet Global Peering
  allow_gateway_transit = false
}

resource "azurerm_virtual_network_peering" "peering_spoke1_to_vnet90" {
  name                      = "peer-1-to-90"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet1.name
  remote_virtual_network_id = azurerm_virtual_network.vnet90.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  # `allow_gateway_transit` must be set to false for vnet Global Peering
  allow_gateway_transit = false
}

resource "azurerm_virtual_network_peering" "peering_vnet90_to_spoke2" {
  name                      = "peer-90-to-2"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet90.name
  remote_virtual_network_id = azurerm_virtual_network.vnet2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  # `allow_gateway_transit` must be set to false for vnet Global Peering
  allow_gateway_transit = false
}

resource "azurerm_virtual_network_peering" "peering_spoke2_to_vnet90" {
  name                      = "peer-2-to-90"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet2.name
  remote_virtual_network_id = azurerm_virtual_network.vnet90.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  # `allow_gateway_transit` must be set to false for vnet Global Peering
  allow_gateway_transit = false
}
