resource "tls_private_key" "linux_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save the private key to our local machine
# Use this key to connect to our Linux VM
resource "local_file" "linuxkey" {
  filename = "linuxkey.pem"
  content  = tls_private_key.linux_key.private_key_pem
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg" {
  count               = length(var.vm_names)
  name                = "${var.vm_names[count.index]}-nsg"
  location            = var.location
  resource_group_name = var.rg_name

  security_rule {
    name                       = "SSH"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# create the first public IP
resource "azurerm_public_ip" "public_ip" {
  count               = length(var.vm_names)
  name                = "${var.vm_names[count.index]}-pip"
  location            = var.location
  resource_group_name = var.rg_name
  allocation_method   = "Static"
  sku                 = "Standard"
  sku_tier            = "Regional"
  zones               = ["1", "2", "3"]
}

resource "azurerm_network_interface" "nic" {
  count               = length(var.vm_names)
  name                = "${var.vm_names[count.index]}-nic"
  location            = var.location
  resource_group_name = var.rg_name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = var.subnet_ids[count.index]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip[count.index].id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_ass" {
  count                     = length(var.vm_names)
  network_interface_id      = azurerm_network_interface.nic[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg[count.index].id
}

resource "azurerm_linux_virtual_machine" "vm" {
  count               = length(var.vm_names)
  name                = var.vm_names[count.index]
  resource_group_name = var.rg_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.linux_key.public_key_openssh
  }
  disable_password_authentication = true
  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id
  ]
  os_disk {
    name                 = "${var.vm_names[count.index]}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    publisher = var.image_reference.publisher
    offer     = var.image_reference.offer
    sku       = var.image_reference.sku
    version   = var.image_reference.version
  }
}
