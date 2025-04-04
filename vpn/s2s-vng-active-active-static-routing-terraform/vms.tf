variable "vm1Name" {
  type    = string
  default = "vm1"
}

variable "vm2Name" {
  type    = string
  default = "vm2"
}

variable "storage_account_type" {
  description = "storage SKU"
  type        = string
  default     = "Standard_LRS"
}

resource "random_integer" "admin_numvalue" {
  min = 1
  max = 999
}

resource "random_password" "vm_admin_password" {
  length      = 12
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  min_special = 3
  special     = true
}

locals  {
  admin_username = format("admin-%04s", random_integer.admin_numvalue.result)
  admin_pwd      = random_password.vm_admin_password.result
  admin_cred = <<EOF
username: ${format("admin-%04s", random_integer.admin_numvalue.result)}
password: ${random_password.vm_admin_password.result}
EOF
}

# create a local file to store the shared key
resource "local_file" "admin_pwd" {
  filename = "vm-admin-credential.txt"
  content  = local.admin_cred
}

variable "image_ref" {
  type = map(string)
  default = {
    "publisher" : "canonical",
    "offer" : "ubuntu-24_04-lts",
    "sku" : "server",
    "version" : "latest"
  }
}

resource "azurerm_network_security_group" "vm1_nsg" {
  name                = join("-", [var.vm1Name, "nsg"])
  location            = azurerm_virtual_network.vnet1.location
  resource_group_name = azurerm_virtual_network.vnet1.resource_group_name
}

resource "azurerm_network_security_rule" "nsgrules" {
  name                        = "ssh-inbound"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.vm1_nsg.name
}

resource "azurerm_network_interface_security_group_association" "nsg_apply_to_vm1" {

  network_interface_id      = azurerm_network_interface.vm1_nic.id
  network_security_group_id = azurerm_network_security_group.vm1_nsg.id
}


# create a public IP address for vm1
resource "azurerm_public_ip" "vm1_pubIP" {
  name                = join("-", [var.vm1Name, "pubIP"])
  location            = azurerm_virtual_network.vnet1.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  sku_tier            = "Regional"
  zones               = ["1", "2", "3"]
}

# Create network interface for vm1
resource "azurerm_network_interface" "vm1_nic" {
  name                = join("-", [var.vm1Name, "nic"])
  location            = azurerm_virtual_network.vnet1.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "nicConfig"
    subnet_id                     = azurerm_subnet.vnet1_AppSubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm1_pubIP.id
  }
  depends_on = [azurerm_public_ip.vm1_pubIP]
}

# Create virtual machine 1
resource "azurerm_linux_virtual_machine" "vm1" {
  name                  = var.vm1Name
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.vm1_nic.id]
  size                  = "Standard_B1s"

  os_disk {
    name                 = join("-", [var.vm1Name, "OsDisk"])
    caching              = "ReadWrite"
    storage_account_type = var.storage_account_type
  }

  source_image_reference {
    publisher = lookup(var.image_ref, "publisher", "Canonical")
    offer     = lookup(var.image_ref, "offer", "0001-com-ubuntu-server-jammy")
    sku       = lookup(var.image_ref, "sku", "22_04-lts-gen2")
    version   = lookup(var.image_ref, "version", "latest")
  }

  computer_name                   = var.vm1Name
  admin_username                  = local.admin_username
  admin_password                  = random_password.vm_admin_password.result
  disable_password_authentication = false
}

# Create public IP address for vm2
resource "azurerm_public_ip" "vm2_pubIP" {
  name                = join("-", [var.vm2Name, "pubIP"])
  location            = azurerm_virtual_network.vnet2.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  sku_tier            = "Regional"
  zones               = ["1", "2", "3"]
}

resource "azurerm_network_security_group" "vm2_nsg" {
  name                = join("-", [var.vm2Name, "nsg"])
  location            = azurerm_virtual_network.vnet2.location
  resource_group_name = azurerm_virtual_network.vnet2.resource_group_name
}

resource "azurerm_network_security_rule" "nsg2rules" {
  name                        = "ssh-inbound"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.vm2_nsg.name
}

resource "azurerm_network_interface_security_group_association" "nsg_apply_to_vm2" {
  network_interface_id      = azurerm_network_interface.vm2_nic.id
  network_security_group_id = azurerm_network_security_group.vm2_nsg.id
}

# Create network interface
resource "azurerm_network_interface" "vm2_nic" {
  name                = join("-", [var.vm2Name, "nic"])
  location            = azurerm_virtual_network.vnet2.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "nicConfig"
    subnet_id                     = azurerm_subnet.vnet2_AppSubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm2_pubIP.id
  }
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "vm2" {
  name                  = var.vm2Name
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.vm2_nic.id]
  size                  = "Standard_B1s"

  os_disk {
    name                 = join("-", [var.vm2Name, "OsDisk"])
    caching              = "ReadWrite"
    storage_account_type = var.storage_account_type
  }

  source_image_reference {
    publisher = lookup(var.image_ref, "publisher", "Canonical")
    offer     = lookup(var.image_ref, "offer", "0001-com-ubuntu-server-jammy")
    sku       = lookup(var.image_ref, "sku", "22_04-lts-gen2")
    version   = lookup(var.image_ref, "version", "latest")
  }

  computer_name                   = var.vm2Name
  admin_username                  = local.admin_username
  admin_password                  = random_password.vm_admin_password.result
  disable_password_authentication = false
}

