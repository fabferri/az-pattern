# fetch resource group
data "azurerm_resource_group" "rg" {
  name = var.rg_name
}

# fetch the vnet1
data "azurerm_virtual_network" "vnet1" {
  name                = var.vnet1_name
  resource_group_name = var.rg_name
}

# fetch the vnet2
data "azurerm_virtual_network" "vnet2" {
  name                = var.vnet2_name
  resource_group_name = var.rg_name
}

# fetch the  subnet1 in vnet1
data "azurerm_subnet" "vnet1_subnet1" {
  name                 = var.vnet1_subnet1_name
  resource_group_name  = var.rg_name
  virtual_network_name = var.vnet1_name
}

# fetch the  subnet1 in vnet2
data "azurerm_subnet" "vnet2_subnet1" {
  name                 = var.vnet2_subnet1_name
  resource_group_name  = var.rg_name
  virtual_network_name = var.vnet2_name
}

# fetch the  subnet1 in vnet90
data "azurerm_subnet" "vnet90_subnet1" {
  name                 = var.vnet90_subnet1_name
  resource_group_name  = var.rg_name
  virtual_network_name = var.vnet90_name
}

module "linux_vms" {
  source   = "./vm_module"
  rg_name  = data.azurerm_resource_group.rg.name
  location = var.rg_location
  vm_names = ["vm1-1", "vm2-1", "vm90-1"]
  subnet_ids = [
    data.azurerm_subnet.vnet1_subnet1.id,
    data.azurerm_subnet.vnet2_subnet1.id,
    data.azurerm_subnet.vnet90_subnet1.id
  ]
  admin_username = var.admin_username
  admin_password = var.admin_password
  image_reference = {
    publisher = "canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
