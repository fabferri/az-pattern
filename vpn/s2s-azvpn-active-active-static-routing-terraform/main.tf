# generate a random password for the shared key
resource "random_password" "psk" {
  length           = 32
  min_lower        = 8
  min_upper        = 8
  min_numeric      = 8
  min_special      = 8
  special          = true
}

# create a local file to store the shared key
resource "local_file" "shared_secret" {
    content  = random_password.psk.result
    filename = "psk.txt"
}

# create a resource group
resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = var.resource_group_name
}
# create a vnet
resource "azurerm_virtual_network" "vnet1" {
  name                = var.virtual_network1_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vnet1_address_space
}
resource "azurerm_virtual_network" "vnet2" {
  name                = var.virtual_network2_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vnet2_address_space
}

# create the GatewaySubnet to be used by the Virtual Network Gateway
resource "azurerm_subnet" "vnet1_GatewaySubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.1.0.192/26"]
}
resource "azurerm_subnet" "vnet2_GatewaySubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
  address_prefixes     = ["10.2.0.192/26"]
}
resource "azurerm_subnet" "vnet1_AppSubnet" {
  name                 = var.vnet1_AppSubnet1Name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = var.vnet1_AppSubnet1AddressPrefix
}
resource "azurerm_subnet" "vnet2_AppSubnet" {
  name                 = var.vnet2_AppSubnet1Name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
  address_prefixes     = var.vnet2_AppSubnet1AddressPrefix
}

# create the first public IP for the Virtual Network Gateway
resource "azurerm_public_ip" "gw1pubIP1" {
  name                = "${var.vpn_gw1_name}-pip1"
  location            = azurerm_virtual_network.vnet1.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  sku_tier            = "Regional"
  zones               = ["1", "2", "3"]
}

# create the second public IP for the Virtual Network Gateway
resource "azurerm_public_ip" "gw1pubIP2" {
  name                = "${var.vpn_gw1_name}-pip2"
  location            = azurerm_virtual_network.vnet1.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  sku_tier            = "Regional"
  zones               = ["1", "2", "3"]
}

# deploy the Virtual Network Gateway in vnet1
resource "azurerm_virtual_network_gateway" "vpngw1" {
  name                = var.vpn_gw1_name
  location            = azurerm_virtual_network.vnet1.location
  resource_group_name = azurerm_resource_group.rg.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = var.vpn_gw_sku
  generation          = var.vpn_gw_generation
  active_active       = var.enable_active_active
  enable_bgp          = var.enable_bgp

  ip_configuration {
    name                          = "vpngw1Config1"
    public_ip_address_id          = azurerm_public_ip.gw1pubIP1.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.vnet1_GatewaySubnet.id
  }
  ip_configuration {
    name                          = "vpngw1Config2"
    public_ip_address_id          = azurerm_public_ip.gw1pubIP2.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.vnet1_GatewaySubnet.id
  }
  depends_on = [ azurerm_public_ip.gw1pubIP1, azurerm_public_ip.gw1pubIP2, azurerm_virtual_network.vnet1 ]
}

resource "azurerm_public_ip" "gw2pubIP1" {
  name                = "${var.vpn_gw2_name}-pip1"
  location            = azurerm_virtual_network.vnet2.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  sku_tier            = "Regional"
  zones               = ["1", "2", "3"]
}

resource "azurerm_public_ip" "gw2pubIP2" {
  name                = "${var.vpn_gw2_name}-pip2"
  location            = azurerm_virtual_network.vnet2.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  sku_tier            = "Regional"
  zones               = ["1", "2", "3"]
}

# deploy the Virtual Network Gateway in vnet2
resource "azurerm_virtual_network_gateway" "vpngw2" {
  name                = var.vpn_gw2_name
  location            = azurerm_virtual_network.vnet2.location
  resource_group_name = azurerm_resource_group.rg.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = var.vpn_gw_sku
  generation          = var.vpn_gw_generation
  active_active       = var.enable_active_active
  enable_bgp          = var.enable_bgp

  ip_configuration {
    name                          = "vpngw2Config1"
    public_ip_address_id          = azurerm_public_ip.gw2pubIP1.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.vnet2_GatewaySubnet.id
  }
  ip_configuration {
    name                          = "vpngw2Config2"
    public_ip_address_id          = azurerm_public_ip.gw2pubIP2.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.vnet2_GatewaySubnet.id
  }
  depends_on = [ azurerm_public_ip.gw2pubIP1, azurerm_public_ip.gw2pubIP2, azurerm_virtual_network.vnet2 ]
}

# create the first local network gateway
resource "azurerm_local_network_gateway" "localnetgw11" {
  name                = var.local_netgw11_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_virtual_network.vnet2.location
  gateway_address     = azurerm_public_ip.gw1pubIP1.ip_address
  address_space       = var.vnet1_address_space
  depends_on          = [azurerm_public_ip.gw1pubIP1]
}

# create the second local network gateway
resource "azurerm_local_network_gateway" "localnetgw12" {
  name                = var.local_netgw12_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_virtual_network.vnet2.location
  gateway_address     = azurerm_public_ip.gw1pubIP2.ip_address
  address_space       = var.vnet1_address_space
  depends_on          = [azurerm_public_ip.gw1pubIP2]
}
# create the first local network gateway
resource "azurerm_local_network_gateway" "localnetgw21" {
  name                = var.local_netgw21_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_virtual_network.vnet1.location
  gateway_address     = azurerm_public_ip.gw2pubIP1.ip_address
  address_space       = var.vnet2_address_space
  depends_on          = [azurerm_public_ip.gw2pubIP1]
}

# create the second local network gateway
resource "azurerm_local_network_gateway" "localnetgw22" {
  name                = var.local_netgw22_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_virtual_network.vnet1.location
  gateway_address     = azurerm_public_ip.gw2pubIP2.ip_address
  address_space       = var.vnet2_address_space
  depends_on          = [azurerm_public_ip.gw2pubIP2]
}

# create the Virtual Network Connection: vpng1-IP1 -> gw2-IP1
resource "azurerm_virtual_network_gateway_connection" "vpngwconn11" {
  name                               = var.vpn_conn11_name
  location                           = azurerm_virtual_network.vnet1.location
  resource_group_name                = azurerm_resource_group.rg.name
  type                               = "IPsec"
  virtual_network_gateway_id         = azurerm_virtual_network_gateway.vpngw1.id
  local_network_gateway_id           = azurerm_local_network_gateway.localnetgw21.id
  connection_protocol                = "IKEv2"
  shared_key                         = random_password.psk.result
  enable_bgp                         = var.enable_bgp
  use_policy_based_traffic_selectors = false
  depends_on = [ azurerm_virtual_network_gateway.vpngw1, azurerm_local_network_gateway.localnetgw21]
}

# create the Virtual Network Connection: vpng1-IP1 -> gw2-IP2
resource "azurerm_virtual_network_gateway_connection" "vpngwconn12" {
  name                               = var.vpn_conn12_name
  location                           = azurerm_virtual_network.vnet1.location
  resource_group_name                = azurerm_resource_group.rg.name
  type                               = "IPsec"
  virtual_network_gateway_id         = azurerm_virtual_network_gateway.vpngw1.id
  local_network_gateway_id           = azurerm_local_network_gateway.localnetgw22.id
  connection_protocol                = "IKEv2"
  shared_key                         = random_password.psk.result
  enable_bgp                         = var.enable_bgp
  use_policy_based_traffic_selectors = false
  depends_on = [azurerm_virtual_network_gateway_connection.vpngwconn11, azurerm_local_network_gateway.localnetgw22]
}

# create the Virtual Network Connection: vpng2-IP1 -> gw1-IP1
resource "azurerm_virtual_network_gateway_connection" "vpngwconn21" {
  name                               = var.vpn_conn21_name
  location                           = azurerm_virtual_network.vnet2.location
  resource_group_name                = azurerm_resource_group.rg.name
  type                               = "IPsec"
  virtual_network_gateway_id         = azurerm_virtual_network_gateway.vpngw2.id
  local_network_gateway_id           = azurerm_local_network_gateway.localnetgw11.id
  connection_protocol                = "IKEv2"
  shared_key                         = random_password.psk.result
  enable_bgp                         = var.enable_bgp
  use_policy_based_traffic_selectors = false
  depends_on = [ azurerm_virtual_network_gateway.vpngw2, azurerm_local_network_gateway.localnetgw11]
}

# create the Virtual Network Connection: vpng2-IP2 -> gw1-IP2
resource "azurerm_virtual_network_gateway_connection" "vpngwconn22" {
  name                               = var.vpn_conn22_name
  location                           = azurerm_virtual_network.vnet2.location
  resource_group_name                = azurerm_resource_group.rg.name
  type                               = "IPsec"
  virtual_network_gateway_id         = azurerm_virtual_network_gateway.vpngw2.id
  local_network_gateway_id           = azurerm_local_network_gateway.localnetgw12.id
  connection_protocol                = "IKEv2"
  shared_key                         = random_password.psk.result
  enable_bgp                         = var.enable_bgp
  use_policy_based_traffic_selectors = false
  depends_on = [ azurerm_virtual_network_gateway_connection.vpngwconn21, azurerm_local_network_gateway.localnetgw12 ]
}



