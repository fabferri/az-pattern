########### TERRAFORM CONFIG ###########
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}


########### VARIABLES ###########
variable "rgTag" {
  type        = string
  default     = "dev"
  description = "Environment tag"
}

variable "resourceGroupName" {
  type    = string
  default = "rg-vms"
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "vnetName" {
  description = "VNet name"
  type        = string
  default     = "vnet1"
}

variable "vnetAddressSpace" {
  description = "VNET address space"
  type        = string
  default     = "10.0.0.0/24"
}

variable "fwAddressPrefix" {
  description = "application address prefix"
  type        = string
  default     = "10.0.0.0/26"
}

variable "app1AddressPrefix" {
  description = "application address prefix"
  type        = string
  default     = "10.0.0.64/26"
}
variable "app2AddressPrefix" {
  description = "application address prefix"
  type        = string
  default     = "10.0.0.128/26"
}

variable "bastionAddressPrefix" {
  description = "bastion adress prefix"
  type        = string
  default     = "10.0.0.192/26"
}

variable "admin_username" {
  description = "administrator username"
  type        = string
  sensitive   = true
}
variable "admin_password" {
  description = "administrator password"
  type        = string
  sensitive   = true
}
variable "vmPrefix" {
  type    = string
  default = "vm"
}
variable "vmCount" {
  type    = number
  default = 2
}


variable "storage_account_type" {
  description = "storage SKU"
  type        = string
  default     = "Standard_LRS"
}

variable "appSubnets" {
  type    = list(any)
  default = ["10.0.0.64/26", "10.0.0.128/26"]
}
variable "rtNameApp1Subnet" {
  description = "UDR name app1Subnet"
  type        = string
  default     = "rt-app1subnet"
}

variable "rtNameApp2Subnet" {
  description = "UDR name app2Subnet"
  type        = string
  default     = "rt-app2subnet"
}
variable "fwIP" {
  description = "internal IP of the Azure firewall"
  type        = string
  default     = "10.0.0.4"
}

variable "linux_script" {
  description = "Define the script you want to add as a custom script. The script located in the local path ./"
  default ={ 
    filename = "linux-nginx.sh"
  }
}

#  Custom Scripts
data "local_file" "sh" {
  filename = "${path.module}/${var.linux_script["filename"]}"
}

#variable "linuxUpdate" {
#  type        = string
#  default     = "sudo apt update"
#}

#variable "linuxNgixCommand" {
#  type        = string
#  default     = "sudo apt-get -y install nginx && sudo systemctl enable nginx && sudo systemctl start nginx && echo \"<style> h1 { color: blue; } </style> <h1>\" > /var/www/html/index.nginx-debian.html && cat /etc/hostname >> /var/www/html/index.nginx-debian.html && echo \"</h1>\" >> /var/www/html/index.nginx-debian.html"
#}

########### PROVIDERS ###########
provider "azurerm" {
  features {}
}


########### RESOURCES ###########
resource "azurerm_resource_group" "rg" {
  name     = var.resourceGroupName
  location = var.location
  tags = {
    Environment = var.rgTag
    Function    = "demo"
  }
}

resource "azurerm_route_table" "rtAppSubnet" {
  count                         = 2
  name                          = "rt-app${count.index + 1}Subnet"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  disable_bgp_route_propagation = false

  route = [
    {
      name                   = "rt-to-next-appSubnet"
      address_prefix         = element(var.appSubnets, length(var.appSubnets) - 1 - count.index)
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = var.fwIP
    },
    {
      name                   = "rt-default"
      address_prefix         = "0.0.0.0/0"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = var.fwIP
    }
  ]
}
resource "azurerm_subnet_route_table_association" "appSubnets-associate" {
  count          = 2
  subnet_id      = element(azurerm_subnet.appSubnets.*.id, count.index)
  route_table_id = azurerm_route_table.rtAppSubnet[count.index].id
}

resource "azurerm_virtual_network" "vnet1" {
  name                = var.vnetName
  address_space       = [var.vnetAddressSpace]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "fwsubnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_virtual_network.vnet1.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = [var.fwAddressPrefix]
}

resource "azurerm_subnet" "appSubnets" {
  count                = 2
  name                 = "app${count.index + 1}Subnet"
  address_prefixes     = [element(var.appSubnets, count.index)]
  resource_group_name  = azurerm_virtual_network.vnet1.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet1.name
}

resource "azurerm_network_security_group" "nsgapp" {
  count               = var.vmCount
  name                = "nsg${count.index + 1}"
  location            = azurerm_virtual_network.vnet1.location
  resource_group_name = azurerm_virtual_network.vnet1.resource_group_name
}

resource "azurerm_network_security_rule" "nsgrules" {
  count                       = var.vmCount
  name                        = "http-vm${count.index + 1}"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_virtual_network.vnet1.resource_group_name
  network_security_group_name = element(azurerm_network_security_group.nsgapp.*.name, count.index)
}

resource "azurerm_network_interface_security_group_association" "nsgToVMs" {
  count                     = var.vmCount
  network_interface_id      = element(azurerm_network_interface.nic.*.id, count.index)
  network_security_group_id = element(azurerm_network_security_group.nsgapp.*.id, count.index)
}

resource "azurerm_subnet" "bastionsubnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = [var.bastionAddressPrefix]
}

resource "azurerm_public_ip" "fw1PubIP" {
  name                = "fw1Pubip"
  location            = azurerm_virtual_network.vnet1.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
resource "azurerm_public_ip" "bastionPubIP" {
  name                = "bastionPubip"
  location            = azurerm_virtual_network.vnet1.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall_policy" "fw1Policy" {
  name                = "fw1Policy"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_virtual_network.vnet1.location
}
resource "azurerm_firewall_policy_rule_collection_group" "fw1RuleCollection" {
  name               = "fw1RuleCollection"
  firewall_policy_id = azurerm_firewall_policy.fw1Policy.id
  priority           = 100
  network_rule_collection {
    name     = "network_rules1"
    priority = 200
    action   = "Allow"
    rule {
      name                  = "network_rule_collection1_rule1"
      protocols             = ["Any"]
      source_addresses      = [element(var.appSubnets, 0)]
      destination_addresses = [element(var.appSubnets, 1)]
      destination_ports     = ["*"]
    }
    rule {
      name                  = "network_rule_collection1_rule2"
      protocols             = ["Any"]
      source_addresses      = [element(var.appSubnets, 1)]
      destination_addresses = [element(var.appSubnets, 2)]
      destination_ports     = ["*"]
    }
  }
  network_rule_collection {
    name     = "network_rules2"
    priority = 250
    action   = "Allow"
    rule {
      name                  = "network_rule_collection1_rule3"
      protocols             = ["Any"]
      source_addresses      = ["10.0.0.0/24"]
      destination_addresses = ["*"]
      destination_ports     = ["*"]
    }
  }
}

resource "azurerm_firewall" "fw1" {
  name                = "fw1"
  location            = azurerm_virtual_network.vnet1.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Premium"
  firewall_policy_id  = azurerm_firewall_policy.fw1Policy.id

  ip_configuration {
    name                 = "configfw"
    subnet_id            = azurerm_subnet.fwsubnet.id
    public_ip_address_id = azurerm_public_ip.fw1PubIP.id
  }
}

resource "azurerm_bastion_host" "bastion" {
  name                = "bastion1"
  location            = azurerm_virtual_network.vnet1.location
  resource_group_name = azurerm_resource_group.rg.name
  copy_paste_enabled  = true

  ip_configuration {
    name                 = "configbastion"
    subnet_id            = azurerm_subnet.bastionsubnet.id
    public_ip_address_id = azurerm_public_ip.bastionPubIP.id
  }
}

resource "azurerm_public_ip" "vm_pubIP" {
  name                = "${var.vmPrefix}${format("%02d", 1 + count.index)}-PubIP"
  count               = var.vmCount
  location            = azurerm_virtual_network.vnet1.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# Create network interfaces
resource "azurerm_network_interface" "nic" {
  name                = "${var.vmPrefix}${format("%02d", 1 + count.index)}-nic"
  count               = var.vmCount
  location            = azurerm_virtual_network.vnet1.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "nicConfig"
    subnet_id                     = element(azurerm_subnet.appSubnets.*.id, count.index)
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(azurerm_public_ip.vm_pubIP.*.id, count.index)
  }
}

# Create virtual machines
resource "azurerm_linux_virtual_machine" "vms" {
  name                  = "${var.vmPrefix}${format("%02d", 1 + count.index)}"
  count                 = var.vmCount
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [element(azurerm_network_interface.nic.*.id, count.index)]
  size                  = "Standard_B1s"


  os_disk {
    name                 = "${var.vmPrefix}${format("%02d", 1 + count.index)}-OSdisk"
    caching              = "ReadWrite"
    storage_account_type = var.storage_account_type
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name                   = "${var.vmPrefix}${format("%02d", 1 + count.index)}"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

}

resource "azurerm_virtual_machine_extension" "vmextension" {
  name                 = "${var.vmPrefix}${format("%02d", 1 + count.index)}"
  count                 = var.vmCount
  virtual_machine_id   = azurerm_linux_virtual_machine.vms[count.index].id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = jsonencode({
    "script" = base64encode(data.local_file.sh.content)
  })

}

