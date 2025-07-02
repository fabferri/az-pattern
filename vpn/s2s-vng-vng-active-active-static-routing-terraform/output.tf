output "psk" {
  value     = random_password.psk.result
  sensitive = true
}

output "vm_admin_username" {
  value = local.admin_username
  sensitive = false
}

output "vm_admin_password" {
  value     = local.admin_pwd
  sensitive = true
}

output "gw1pubIP1" {
  value = azurerm_public_ip.gw1pubIP1.ip_address
}

output "gw1pubIP2" {
  value = azurerm_public_ip.gw1pubIP2.ip_address
}

output "gw2pubIP1" {
  value = azurerm_public_ip.gw2pubIP1.ip_address
}

output "gw2pubIP2" {
  value = azurerm_public_ip.gw2pubIP2.ip_address
}