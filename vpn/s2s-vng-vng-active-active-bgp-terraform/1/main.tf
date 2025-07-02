# create a resource group
resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = var.rg_name
}
# create a vnet1
resource "azurerm_virtual_network" "vnet1" {
  name                = var.vnet1_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.1.0.0/24"]
}

# create a vnet2
resource "azurerm_virtual_network" "vnet2" {
  name                = var.vnet2_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.2.0.0/24"]
}

# create the GatewaySubnet to be used by the Virtual Network Gateway1
resource "azurerm_subnet" "gw1Subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.1.0.192/26"]
}
# create the subnet for the workloads in vnet1
resource "azurerm_subnet" "subnet11" {
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.1.0.0/26"]
}

# create the GatewaySubnet to be used by the Virtual Network Gateway2
resource "azurerm_subnet" "gw2Subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
  address_prefixes     = ["10.2.0.192/26"]
}

# create the subnet for the workloads in vnet2
resource "azurerm_subnet" "subnet21" {
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
  address_prefixes     = ["10.2.0.0/26"]
}

# create the first public IP for the Virtual Network Gateway1
resource "azurerm_public_ip" "gw1pubIP1" {
  name                = "${var.gw1_name}-pip1"
  location            = azurerm_virtual_network.vnet1.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  sku_tier            = "Regional"
  zones               = ["1", "2", "3"]
}

# create the second public IP for the Virtual Network Gateway1
resource "azurerm_public_ip" "gw1pubIP2" {
  name                = "${var.gw1_name}-pip2"
  location            = azurerm_virtual_network.vnet1.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  sku_tier            = "Regional"
  zones               = ["1", "2", "3"]
}

# create the first public IP for the Virtual Network Gateway2
resource "azurerm_public_ip" "gw2pubIP1" {
  name                = "${var.gw2_name}-pip1"
  location            = azurerm_virtual_network.vnet2.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  sku_tier            = "Regional"
  zones               = ["1", "2", "3"]
}

# create the second public IP for the Virtual Network Gateway2
resource "azurerm_public_ip" "gw2pubIP2" {
  name                = "${var.gw2_name}-pip2"
  location            = azurerm_virtual_network.vnet2.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  sku_tier            = "Regional"
  zones               = ["1", "2", "3"]
}

# deploy the Virtual Network Gateway1
resource "azurerm_virtual_network_gateway" "gw1" {
  name                = var.gw1_name
  location            = azurerm_virtual_network.vnet1.location
  resource_group_name = azurerm_resource_group.rg.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = var.gw_sku
  generation          = var.gw_generation
  active_active       = var.enable_active_active
  enable_bgp          = var.enable_bgp
  bgp_settings {
    asn = var.gw1_bgp_asn_number
  }

  ip_configuration {
    name                          = "gw1Config1"
    public_ip_address_id          = azurerm_public_ip.gw1pubIP1.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gw1Subnet.id
  }
  ip_configuration {
    name                          = "gw1Config2"
    public_ip_address_id          = azurerm_public_ip.gw1pubIP2.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gw1Subnet.id
  }
}

# deploy the Virtual Network Gateway2
resource "azurerm_virtual_network_gateway" "gw2" {
  name                = var.gw2_name
  location            = azurerm_virtual_network.vnet2.location
  resource_group_name = azurerm_resource_group.rg.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = var.gw_sku
  generation          = var.gw_generation
  active_active       = var.enable_active_active
  enable_bgp          = var.enable_bgp
  bgp_settings {
    asn = var.gw2_bgp_asn_number
  }

  ip_configuration {
    name                          = "gw2Config1"
    public_ip_address_id          = azurerm_public_ip.gw2pubIP1.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gw2Subnet.id
  }
  ip_configuration {
    name                          = "gw2Config2"
    public_ip_address_id          = azurerm_public_ip.gw2pubIP2.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gw2Subnet.id
  }
}

