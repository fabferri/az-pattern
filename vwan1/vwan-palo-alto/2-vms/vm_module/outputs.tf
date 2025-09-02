output "vm_public_ips" {
  value = [for pip in azurerm_public_ip.public_ip : pip.ip_address]
}
