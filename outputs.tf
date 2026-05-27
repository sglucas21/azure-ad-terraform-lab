output "domain_controller_public_ip" {
  value = azurerm_public_ip.dc_pip.ip_address
}

output "client_public_ip" {
  value = azurerm_public_ip.client_pip.ip_address
}

output "domain_name" {
  value = var.domain_name
}